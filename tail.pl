#!/usr/bin/perl
use strict;

#Perl tail function

sub usage {

	print "USAGE $0 <fileToTail> <linesToTail> \n\n";
}
if(@ARGV != 2) {  &usage ; exit(1); }

my $fileToRead=$ARGV[0];
my $fromLine=$ARGV[1];

#Make sure it is a num otherwise exit
	if ( $fromLine !~ /\d+/ ) {
		print "$0 $fileToRead $fromLine \n\n";
		print "Second arg must be a number only\n";
		&usage;
		exit(1);
	}


open(FILE, $fileToRead ) or die "The file $fileToRead is not found:  $!";

my $total=0;
	$total++ while <FILE>;

my $pos=$total-$fromLine;

	if ($pos <= 0) {
		$pos=0;
	}
$pos=$pos+1;  # for example, to read one line you are reading the last line

close (FILE);

#Open file for reading and print from that position
open(FILE, $fileToRead ) or die "The file $fileToRead is not found:  $!";
while (<FILE>) {
	next if $. < $pos;
	print $_;
}

### this is for reference only: foo
=begin test_one
added for first commit to test revert
=end test_one
=cut
