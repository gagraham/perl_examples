#! /usr/bin/perl
#--------------------------------------------------------------------------------------------------------------------
# Name:          check_logs.pl
#
# Programmer(s): perlwarrior
#
# Date:          02/10/2012
#
#
#
# Purpose: Program to search a given list of logs for given search strings containing “Exception” and 
#          if they exist, output to an email. 
#
# Run format: check_logs.pl
#                  
#
# Modifications:
#       02/10/2012 - perlwarrior - Initial Creation for Liquid Event 67321.
#       05/10/2012 - perlwarrior - Modified to consider <filename>.1..<filename>.4 for each <filename>
#								 - Modified to continue without failing even if a file from the search list is missing 	
#---------------------------------------------------------------------------------------------------------------------

use strict;
use POSIX 'strftime';
use Time::Local;
use IO::File;

my (%config);
my $MailContent;
my $start_time = localtime(time);

# Write out start info
print "\n *****************************************************" ;
print "\n Program     : $0";
print "\n Start Time  : $start_time ";
print "\n ***************************************************** \n\n" ;

#----------------------------------------------------------------------------
#  main routine
#----------------------------------------------------------------------------
if ( $ARGV[0] =~ /-?h[elp]?/i){
	&usage;
} 
&initialize;
&search_files ("LOGLIST_1","LOGPATH_1","SEARCHSTR_1");
&search_files ("LOGLIST_2","LOGPATH_2","SEARCHSTR_2");
## &search_files ("LOGLIST_3","LOGPATH_3","SEARCHSTR_3");
&send_mail;
&print_summary;

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub usage {
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# displays how to use the tool
#----------------------------------------------------------------------------
    print "\n ***************************USAGE*******************************************";
	print "\n check_logs.pl searches a given list of logs for given search strings and output to an email. "; 
    print "\n The tool reads the config_file to identify the properties. ";
    print "\n Execution will be terminated in case any of the search files is missing. A sample config file is displayed below \n";
	print "\n\n 	#check_logs.config#";
	print "\n 	LOGPATH_1=/var/mqsi/rp/log";
	print "\n	LOGLIST_1=GSManageDownstreamFeeds_UPSB.log,GSManageDownstreamFeeds_PRS.log";
	print "\n	SEARCHSTR_1=\d+.*\d+:\d+:\d+.+Exception.*";
	print "\n	LOGPATH_2=/var/mqsi/rp/log";
	print "\n	LOGLIST_2=GSManageDownstreamFeeds_UPSB.log,GSManageDownstreamFeeds_QSOI.log,GSManageDownstreamFeeds_QSNQ.log";
	print "\n	SEARCHSTR_2=.+SQLCODE.*";
	print "\n	LOGPATH_3=/var/log/";   
	print "\n	LOGLIST_3=messages";
	print "\n	SEARCHSTR_3=\d+.*\d+:\d+:\d.+\(RP_BROKER.RP_LA\).+Exception.*";
	print "\n	SEND_FROM=rpdev01.lexington.ibm.com";
	print "\n	MAIL_LIST=gagraham\@us.ibm.com,abc\@us.ibm.com";
	print "\n	SUBJECT=\"Exceptions found in WWBPSM Logs\"";
	print "\n	EXTRA_LINES=2";
    print "\n ***************************************************************************\n";
	exit 1;
    
}  # end subroutine


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub initialize{
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# Initialize the variables
#----------------------------------------------------------------------------
my $config_file="check_logs.config";
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



#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub search_files{
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# Search for the searchstring and generate the mailcontent
#----------------------------------------------------------------------------
my $loglist=shift;
my $logpath=shift;
my $searchstring=shift;
my $pathflag=1;
my $fileflag;

my @logfiles=split (",",$config{$loglist});
# The following code is to check for files such as filename.1,filename.2...filename.4
#foreach my $file (@logfiles) {
  #  foreach my $i (1..4) {
  #      if ( -f "$config{$logpath}/$file.$i") {
  #          push (@logfiles,"$file.$i") if( ! grep /$file.$i/,@logfiles);;
  #      }
  #  }
#}
foreach my $file (@logfiles) {

	$fileflag=1;
	print "\nINFO: Searching for \"$searchstring\" in $file in $config{$logpath}\n";
	if ( ! -d "$config{$logpath}" ) {
		print "\nError : SRC_DIR \"$config{$logpath}\" not found\n";
		exit 2;
	}
	chdir "$config{$logpath}" or die "Can't cd to $config{$logpath}: $!\n";
    if (! -f $file ){

		print "\nWarn : $file is not found. Skipping \n";
		sleep 1;
		next;
	}	
	my $SEARCH_FILE = IO::File->new("$file","<") or die "\nError: Can't open $file. $! \n\n";
	
	while(defined(my $line = $SEARCH_FILE->getline())){
		if ($line =~ /$config{$searchstring}/) {
			if ($pathflag) {
				$MailContent .="PATH OF LOG: $config{$logpath} \n";
			}
			if ($fileflag) {
				$MailContent .= "NAME OF LOG: $file \n";
			}
			$MailContent .= "Exception string:\n";
			$MailContent .= "$line";
			$MailContent .= scalar <$SEARCH_FILE> for 1 .. $config{EXTRA_LINES};
			$MailContent .= "\n";
			$fileflag=0;    # Setting the file flag so that the filename is not printed more than once.
			$pathflag=0; 	# Setting the path flag so that the pathname is not printed more than once.

		}
	}
	$SEARCH_FILE->close();
	
}

}

sub send_mail {
#----------------------------------------------------------------------------
# Send the mail if there is any content
#---------------------------------------------------------------------------- 
  
if (defined $MailContent) {
	print "\nINFO: Sending mail with the exceptions captured\n";
	open(MAIL, "|/usr/sbin/sendmail -t");
	## Mail Header
	print MAIL "To: $config{MAIL_LIST}\n";
	print MAIL "From: $config{SEND_FROM}\n";
	print MAIL "Subject: $config{SUBJECT}\n\n";
	## Mail Body
	print MAIL "$MailContent\n";
	 
	close(MAIL);

} else {
	print "\nINFO: There is no content to be mailed. Exiting the program.\n";
}

}

sub print_summary {
#----------------------------------------------------------------------------
# Complete the execution by displaying the summary.
#----------------------------------------------------------------------------

my $end_time = localtime(time);
print "\n\n\n *****************************************************" ;
print "\n End Time    : $end_time";
print "\n Process Info: $0 completed";
print "\n ***************************************************** \n" ;
exit();
}

