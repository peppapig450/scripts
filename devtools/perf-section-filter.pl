#!/usr/bin/env perl
# Script to extract "Percent | … for EVENT" sections from perf diff or report outputs.
# Filters by optional event name patterns and value threshold.
# Example usage:
#   cat perf.diff | ./perf-section-filter.pl --threshold 1.0 cache-misses L1-dcache-load-misses
#  ./perf-section-filter.pl --threshold 1.0 cache-misses L1-dcache-load-misses < perf.diff > filtered-perf.diff
use strict;
use warnings;
use Getopt::Long;

# 1) parse args (optional --threshold plus 1+ patterns)
my $threshold = 0;
GetOptions('threshold|t=f' => \$threshold)
  or die "Usage: $0 [--threshold N] <pattern1> [pattern2 ...]\n";

# 2) build event‑name regex
my $pattern = @ARGV ? join '|', @ARGV : '.*';

# 3) slurp all input
local $/;
my $input = <STDIN>;

# 4) extract each "Percent | … for EVENT" section
while ($input =~ /
    (                              # $1 = entire section
      ^\s*Percent\ \|.*?for\s+(\S+)\s+  # header, event in $2
      \(.*?\n                          #   through the “(…)\n”
      (?:.*?\n)*?                      #   rest of section (lazy)
    )
    (?=^\s*Percent\ \||\z)           # up to next header or EOF
  /msgx)
{
    my ($section, $event) = ($1, $2);

    # 5) filter by event name
    next unless $event =~ /$pattern/;

    # 6) print a nice separator
    print "==== $event ====\n";

    # 7) print only lines ≥ threshold
    for my $line (split /\n/, $section) {
        if ($line =~ /^\s*([\d.]+)\s*:/) {
            print "$line\n" if $1 >= $threshold;
        }
        else {
            print "$line\n";
        }
    }
}
