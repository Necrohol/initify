#!/usr/bin/perl
# (c) Necrohol & goose121, 2026
# Transpiler: Podman Quadlet (.container) -> Gentoo OpenRC Runner
# Handles: CGroups v2, Resource Limits, Rootless vs Privileged, and Systemd Placeholders.

use strict;
use warnings;
use FindBin qw($Bin);

# --- Smart Require Logic ---
my $found = 0;
foreach my $path ("/usr/bin/initify", "$Bin/initify.pl", "./initify.pl") {
    if (-e $path) {
        require $path;
        $found = 1;
        last;
    }
}
die "CRITICAL: initify logic not found! Check your ebuild or local files." unless $found;

# Load cronify if available (optional)
foreach my $path ("/usr/bin/cronify", "$Bin/cronify.pl", "./cronify.pl") {
    if (-e $path) { require $path; last; }
}

# --- Initialization ---
my $input = $ARGV[0] or die "Usage: $0 <quadlet.container>\n";
my @cgroup_rules;
my $is_rootless = 0;

# --- Parse Input File for Resource Limits and Context ---
open(my $fh, '<', $input) or die "Could not open $input: $!";
while (<$fh>) {
    chomp;
    s/\s*#.*$//; # Strip trailing comments
    next unless /\S/;

    # 1. Detect User Context (Rootless Check)
    if (/^(?:User|Group)\s*=\s*([^#\s]+)/i) {
        my $val = lc($1);
        $is_rootless = 1 if ($val ne 'root');
    }

    # 2. Map CPUQuota=150% -> cpu.max 150000 100000
    if (/^CPUQuota\s*=\s*(\d+)%/i) {
        my $quota = $1 * 1000;
        push @cgroup_rules, "cpu.max $quota 100000";
    }

    # 3. Map Memory Limits (Hard vs Soft)
    if (/^MemoryHigh\s*=\s*(.+)/i) {
        push @cgroup_rules, "memory.high $1";
    }
    if (/^(?:MemoryMax|MemoryLimit)\s*=\s*(.+)/i) {
        push @cgroup_rules, "memory.max $1";
    }
}
close($fh);

# --- Capture Core Initify Output ---
my $output = "";
{
    local *STDOUT;
    open(STDOUT, '>', \$output);
    initify::main($input); 
}

# --- Refine and Print Final OpenRC Script ---
my @lines = split("\n", $output);
foreach my $line (@lines) {
    
    # A. Inject CGroup v2 Settings before depend()
    if ($line =~ /^depend\(\)/ && @cgroup_rules) {
        print "# Resource Limits (Gentoo CGroup v2)\n";
        print "rc_cgroup_settings=\"\n";
        print "    $_\n" for @cgroup_rules;
        print "\"\n";
        print "rc_cgroup_cleanup=\"yes\"\n\n";
        undef @cgroup_rules; # Prevent double-injection
    }

    # B. Smart Podman Injection (Privileged vs Rootless Namespace)
    if ($input =~ /\.container$/ && $line =~ /^command=/) {
        if ($line =~ /podman run/) {
            if ($is_rootless) {
                # Ensure user namespace persistence
                $line =~ s/podman run/podman run --userns=keep-id/ if $line !~ /--userns/;
            } else {
                # Force privileged for hardware access (RPi5 GPIO, etc)
                $line =~ s/podman run/podman run --privileged/ if $line !~ /--privileged/;
            }
        }
    }
    
    print "$line\n";
}
