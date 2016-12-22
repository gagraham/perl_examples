#!/usr/bin/perl
use strict;

my $limit=90;
my $server="localhost";
my $MAIL_TO="gagrahamster\@gmail.com";

my $SUBJECT="FILESPACE Report: $server "; 
my $ME=$server;
my $output=`df -h`;

my $line;
my @array=split(/[\n\r]+/,$output);
my $content;
my $info="Filespace is  over $limit in the following directories:\nNOTE: The biggest concern would be the filesystems: /var/log and /var/mqsi/rp /home/mqbrkr Thanks!\n********************\n";
foreach $line (@array) {
	if ( $line =~ /(\d+)%(.+)$/ ) {
		my $percent=$1;
		if(($percent + 0) > $limit) {
		    $content= $content .  "$2:$percent" . "%\n";
		}
	}	
}
$content="TESTING CONTENT";
if($content) {
	print "CONTENT=$content\n";
	$content="$info" . "$content";
   	&send_mail($MAIL_TO,$SUBJECT,$ME,$content);
}
else {
	print "No mail sent out because there is no content\n";
}





sub send_mail {
	my $MAIL_TO=$_[0];
	my $SUBJECT=$_[1];
	my $ME=$_[2];
	my $MailContent=$_[3];

        print "\nINFO: Sending mail \n";
        open(MAIL, "|/usr/sbin/sendmail -t");
        ## Mail Header
        print MAIL "To: $MAIL_TO\n";
        print MAIL "From: $ME\n";
        print MAIL "Subject: $SUBJECT\n\n";
        ## Mail Body
        print MAIL "$MailContent\n";

        close(MAIL)
}
