#!/usr/bin/env perl
use strict;
use warnings;

my @timestamps;

while(<>) {
    # Default Cron: min(0) hour(1) dom(2) mon(3) dow(4)
    my @timestamp = ("*", "*", "*", "*", "*"); 
    
    if(m/OnCalendar=(.*)/) {
        my $val = lc $1;
        
        if ($val =~ /^(hourly|daily|monthly|yearly)$/) {
            @timestamp = ('@' . $val);
        } elsif ($val =~ /weekly/) {
            # Systemd weekly = Mon 00:00. Cron weekly = Sun 00:00.
            # We force Mon for consistency in your rack.
            @timestamp = ("0", "0", "*", "*", "1"); 
        } elsif ($val =~ /quarterly/) {
            @timestamp = ("0", "0", "1", "1,4,7,10", "*");
        } else {
            # Advanced parsing for Day-Date-Time formats
            my @parts = split / /, $val;
            
            # 1. Handle Day of Week (e.g., Mon..Fri)
            if ($parts[0] =~ /[a-z]{3}/) {
                my $days = shift @parts;
                $days =~ s/monday/1/g; $days =~ s/mon/1/g;
                $days =~ s/tuesday/2/g; $days =~ s/tue/2/g;
                # ... (You'd want a map here)
                $timestamp[4] = $days;
            }

            # 2. Handle Date (YYYY-MM-DD)
            if (@parts && $parts[0] =~ /\d+|\*/) {
                my $date = shift @parts;
                my ($y, $m, $d) = split /-/, $date;
                $timestamp[3] = $m // "*";
                $timestamp[2] = $d // "*";
            }

            # 3. Handle Time (HH:MM:SS) - THE CRITICAL FIX
            if (@parts && $parts[0] =~ /(\d+):(\d+)/) {
                $timestamp[0] = $2; # Minute
                $timestamp[1] = $1; # Hour
            }
        }
        push @timestamps, \@timestamp;
    }
}

foreach my $ts_ref (@timestamps) {
    print join(" ", @$ts_ref), "\n";
}
