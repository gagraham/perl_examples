#!/usr/bin/perl
use strict;
use File::Copy;

# put cmr list in a file with underscores
# read file into array
# ARGV[0] is file name
# ARGV[1] is dir name to deposit found files
my $cmrList=$ARGV[0] or die "Usage $0 <fileWithCMRUnderscores>  <localDir>\n";
my $localDir=$ARGV[1] or die "Usage $0 <fileWithCMRUnderscores>  <localDir>\n";
my $DIR="/var/mqsi/rp/ptsfiles/mqsiarchive";

open(CMRLIST,$cmrList) or die "Cannot open file $cmrList $!\n\n";
#my @arr = 
#(
#"0018336612_____2014-02-092014-02-09",
#"0035947339_____2014-02-072014-02-07"
#);

my @arr=();
	while(<CMRLIST>) {
		&trim;
		chomp;
		next if( /^SELECT/ );
		next if( /^BP_TRANS/ );
		next if( /^---/ );
		next if( /^\s/ );
		next if( /^$/ );
		s/\s/_/g;    # sub underscore for remaining spaces
		#print "CMR=$_\n";
		push(@arr,$_);	
	}
close(CMRLIST);
print join ("\n",@arr),"\n";

my $targetDIR="/home/mqbrkr/tasks/${localDir}";

foreach my $f (@arr) {
	$f=$DIR . "/" . "*${f}*";
	my @tmp=`ls -1 ${f}`;
	print join(",",@tmp);
	my $latest=pop @tmp;
	chomp($latest);
	print "\nLATEST=$latest\n***\n and will copy to $targetDIR\n";
	copy($latest,$targetDIR) ==1 or warn " Copy failed! $!\n\n";
}
sub trim {
        my $str =   $_[0];
        if(defined($str)) {
                $str=~s/^\s+//;
                $str=~s/\s+$//;
        }
        return $str;
}

