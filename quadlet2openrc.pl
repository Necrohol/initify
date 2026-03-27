#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);

# --- Smart Require Logic ---
my $found = 0;
# Check /usr/bin first (installed via ebuild), then local (hot-paste/action)
foreach my $path ("/usr/bin/initify", "$Bin/initify.pl", "./initify.pl") {
    if (-e $path) {
        require $path;
        $found = 1;
        last;
    }
}
die "CRITICAL: initify logic not found! Check your ebuild or local files." unless $found;

# Load cronify if available for timers
foreach my $path ("/usr/bin/cronify", "$Bin/cronify.pl", "./cronify.pl") {
    if (-e $path) { require $path; last; }
}

# --- Conversion Logic ---
my $input = $ARGV[0] or die "Usage: $0 <quadlet.container>\n";

# Note: Quadlets usually need to be pre-processed by 'podman-pull' or 'podman-generate' 
# to get a real Unit file. Assuming we are targeting the resulting .service:
my $output = "";
{
    local *STDOUT;
    open(STDOUT, '>', \$output);
    initify::main($input); # Call the entry point from initify.pl
}

# --- Append OpenRC Fixes ---
my @lines = split("\n", $output);
foreach my $line (@lines) {
    # 1. Add your backgrounding fix
    if ($line =~ /^command_args="/) {
        $line =~ s/"$/ --background --make-pidfile --pidfile \/run\/\${RC_SVCNAME}.pid"/;
    }
    
    # 2. Add Privileged check (if initify missed it)
    if ($input =~ /\.container$/ && $line =~ /command=/) {
        # Ensure 'podman run' includes --privileged if the quadlet asked for it
        $line =~ s/podman run/podman run --privileged/ if !($line =~ /--privileged/);
    }
    
    print "$line\n";
}
