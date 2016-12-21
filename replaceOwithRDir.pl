#!usr/bin/perl
use strict;
use File::Copy;

##########
#  replaceOwithRDir.pl 
#  will replace  O with R in action 1 char field;  it distinguishes sales from inventory
#  It operates in the directory specified in only argument
#
#

use Time::localtime;
my $tm;
my $usage_list = " USAGE:perl replaceOwithR.pl  \n***This will change O to R in header and file name for all _S_0_*.txt files in the directory\n";
my $dirName  = $ARGV[0] or die "\nEnter Directory Name ( only argument) where files are located!\n" ;
chdir $dirName;

my @arr=glob("*_S_O_*.txt");
if((@arr + 0) == 0) { print "$0 has nothing to change. Exiting"; exit 1;} 

foreach my $f (@arr) {
	my $index = 1;
	my $output = "$f" . "toR.txt";
	open(PTS,"$f") or die "Cannot open file $f $!\n";
	open(OUT,">>$output") or die "Cannot open file $output   $!\n";

	while (<PTS>)  {
		if ($index == 1) {
			$_ =~ s/^(.{35})SO(.+$)/$1SR$2/  ;
			print OUT $_;
		}
		else {
			print OUT $_;
		}
		$index++;
	}
	close(PTS);
	close(OUT);
	# CHANGE FILE NAME
	my $oldoutput=$output;
	$output =~ s/_S_O_/_S_R_/ ;
	print "INPUT file name=$f\n";
        print "OUTPUT file name=$output\n";
        move($oldoutput,$output);
	#my $newInput=$f . ".previous";
	#move($f,$newInput);
	unlink $f;
	print "* * * * \n";
}
