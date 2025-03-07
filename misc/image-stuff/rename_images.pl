#!/usr/bin/env perl
use strict;
use warnings;
use File::Copy qw(move);
use Image::ExifTool qw(:Public);
use Getopt::Long;                # For command-line options

# Command-line options
my $dry_run = 0;  # Default: no dry run
GetOptions("dry-run" => \$dry_run) or die "Error in command-line arguments\n";

# Get positional arguments
my $extension = $ARGV[0];
my $input_dir = $ARGV[1];
my $output_dir = $ARGV[2];

# Validate arguments
unless (@ARGV == 3) {
    die "Usage: perl rename_script.pl [--dry-run] <extension> <input_directory> <output_directory>\n";
}
unless (-d $input_dir) {
    die "Input directory '$input_dir' does not exist or is not a directory.\n";
}

# Create output directory if it doesn't exist (skip in dry-run)
unless (-d $output_dir) {
    if ($dry_run) {
        print "Dry run: Would create directory '$output_dir'\n";
    } else {
        mkdir $output_dir or die "Cannot create $output_dir: $!\n";
    }
}

# Get all files with the specified extension in the input directory
my @files = glob("$input_dir/*.$extension");
die "No files with extension '.$extension' found in '$input_dir'\n" unless @files;

# Initialize ExifTool
my $exifTool = new Image::ExifTool;
$exifTool->Options(DateFormat => "%Y:%m:%d %H:%M:%S"); # Standardize date output

# Extract DateTimeOriginal for all files
my %dates;
foreach my $file (@files) {
	my $info = $exifTool->ImageInfo($file, "DateTimeOriginal");
	my $date = $info->{DateTimeOriginal} // "0000:00:00 00:00:00"; # Fallback for missing dates
	$dates{$file} = $date;
}

# Sort files by DateTimeOriginal
my @sorted_files = sort { $dates{$a} cmp $dates{$b} } keys %dates;

# Rename and move with sequential numbers
my $i = 1;
foreach my $file (@sorted_files) {
    my $num = sprintf "%03d", $i;  # Pads to 3 digits (001, 002, etc.)
    my $new_name = "$output_dir/Screenshot_$num.$extension";
    if ($dry_run) {
        print "Dry run: Would move '$file' to '$new_name'\n";
    } elsif (move($file, $new_name)) {
        print "Moved '$file' to '$new_name'\n";
    } else {
        warn "Failed to move '$file' to '$new_name': $!\n";
    }
    $i++;
}

print "Processed ", scalar(@sorted_files), " files.\n";
