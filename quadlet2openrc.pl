#!/usr/bin/perl
# (c) Necrohol, 2026
# Wrapper to convert podlet/  Podman Quadlets/Services to OpenRC
# Features: Smart path loading, Privileged container detection.

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

# Load cronify if available for timers
foreach my $path ("/usr/bin/cronify", "$Bin/cronify.pl", "./cronify.pl") {
    if (-e $path) { require $path; last; }
}

# --- Conversion Logic ---
my $input = $ARGV[0] or die "Usage: $0 <unit_file>\n";

# Capture the output from the core initify library
my $output = "";
{
    local *STDOUT;
    open(STDOUT, '>', \$output);
    initify::main($input); 
}

# --- Quadlet/Container Specific Refinements ---
my @lines = split("\n", $output);
foreach my $line (@lines) {
    
    # 1. Privileged Container Check
    # Quadlets often lose the --privileged flag during translation if 
    # the 'privileged=true' was in the [Container] block instead of [Service].
    if ($input =~ /\.container$/ && $line =~ /^command=/) {
        if ($line =~ /podman run/ && $line !~ /--privileged/) {
            $line =~ s/podman run/podman run --privileged/;
        }
    }
    
    # Note: Backgrounding/PID logic is now handled INSIDE initify.pl
    
    print "$line\n";
}

exit 0;

__END__

=head1 NAME

quadlet2openrc - Convert Systemd Quadlet units to OpenRC runners.

=cut
