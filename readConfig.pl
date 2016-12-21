
use strict;

use IO::File;
use Data::Dumper;

my (%config);
&initialize;
print "************";
print $config{user},"\n";
print "************";
print Data::Dumper->Dump([\%config], ["config"]), $/;
print "************";
print Data::Dumper->new([\%config],[qw(config)])->Indent(3)->Quotekeys(0)->Dump;
print "************";
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub initialize{
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# Initialize the variables
#----------------------------------------------------------------------------
my $config_file="readConfig.conf";
my $CONFIG = IO::File->new("$config_file","<") or die "\nError: Can't open $config_file. $! \n\n";
				
my $line;
while(defined($line = $CONFIG->getline())){
	next if $line =~ /^#/;   # skipping comments
	if ($line =~ /(.*?)\=(.*)/) {
		my $key=$1;
		my $value=$2;
		$value=~s#\"(.*)\"#$1#g;   # removing quotes if any
		$value=~ s#^\s+|\s+$##g;   # removing leading/trailing spaces if any
		$key=~s#^\s+|\s+$##g;
		$config{$key} = $value;
	}
}
$CONFIG->close();
} # end subroutine



#use strict;
#use Data::Dumper;
#my %hash = ( 'some' => 'stuff' );
#print Data::Dumper->Dump([\%hash], ["hashname"]), $/;
#
#
#or  
#
#print Data::Dumper->new([\%hash],[qw(hash)])->Indent(3)->Quotekeys(0)->Dump;

