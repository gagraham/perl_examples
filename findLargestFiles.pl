#!/usr/local/bin/perl -w

($#ARGV == 0) or die "Usage: $0 [directory]\n";    # first argument is directory name

use File::Find;
    
find(sub {$size{$File::Find::name} = -s if -f;}, @ARGV);   # -s  is the size and -f is "if this is a file" and @ARGV is the directory
								# $size{<name>} is the value
								# this find() iterates over all files found recursively from the top dir
@sorted = sort {$size{$b} <=> $size{$a}} keys %size;       #  size is a hash table where size is the key and actual size is value 
   								# keys %size is an array of keys which are the file paths 
#    for my $key ( keys %size ) {
#        my $value = $size{$key};
#        print "$key => $value\n";
#    }
####  a and b are files being compared
#
@sorted = sort {$size{$b} <=> $size{$a}} keys %size;       #  size is a hash table where size is the value and the file path is the key 
splice @sorted, 20 if @sorted > 20;
   print "\n\n\n"; 
foreach (@sorted) 
{
    printf "%10d %s\n", $size{$_}, $_;
}


