#!/usr/bin/env perl
# Script to extract event names from 'Percent | … for EVENT' sections of perf outputs.
# Reads from file or stdin, prints matched event names (one per line).
#
# Example:
#   ./extract-events.pl perf.diff
#   cat perf.diff | ./extract-events.pl
use strict;
use warnings;

# Check for a file argument, or read from STDIN
my $fh;
if (@ARGV) {
    my $file = shift @ARGV;
    open $fh, '<', $file or die "Cannot open '$file': $!";
} else {
    $fh = *STDIN;
}

while (<$fh>) {
    if (/Percent \|.*?for\s+(.*?)\s+\(/) {
        print "$1\n";
    }
}

