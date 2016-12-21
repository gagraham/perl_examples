#!/usr/local/bin/perl
use strict;
use warnings;
use Time::localtime;

#### STATUS FOR STOP:
####my $RegExp="FileManagementServicesFlow - stopped";
#### STATUS FOR START:
###             FileManagementServicesFlow - running AFTER BRACKETS are removed by function

### COMMANDS for mqsistatus will change per environment
	# mqsistatusRP (if dev) 
	# getstatus.ksh ( prod) 
	# ./mqsistatusRP (UAT)

my $tm = localtime;
my $COMMAND="/home/mqbrkr/getstatus.ksh";
my $PERL_EXE="/usr/bin/perl";
my $ME="g03zcimq001.ahe.boulder.ibm.com";   # DEV, UAT or PROD server
my $TS = sprintf("%04d-%02d-%02d_%02d%02d", substr(($tm->year)+1900,0,4),($tm->mon)+1,$tm->mday,$tm->hour,$tm->min);
print "TIMESTAMP  $TS  \n";
my $StopStart=$ARGV[0] or die " Need one argument:USAGE: $0 <start|stop> \n";
my $SUBJECT="$StopStart  BROKER at $TS: STATUS "; 
my $SCRIPT_LOC="/home/mqbrkr/tasks";  # DEV, UAT or PROD
my $MAILTO="gagraham\@us.ibm.com,varian\@us.ibm.com,harristm\@us.ibm.com,jblacks\@us.ibm.com";
#my $MAILTO="gagraham\@us.ibm.com";

my @results=();   #ARRAY for output of commands
my @messages=();  # ARRAY for collection of messages for the mail body
my $RegExpStop ="FileManagementServicesFlow - stopped";
my $RegExpStart="FileManagementServicesFlow - running";

	$StopStart=uc($StopStart);
        print "COMMAND to be issued at $TS is $StopStart\n";

push(@messages,"STATUS OF BROKER command: \n[VALUE of zero is successful]\n");


if($StopStart eq "STOP") {
	&stopBroker(\@results,\@messages);
	&checkBrokerStatus(\@results,\@messages,$RegExpStop,$COMMAND);
}
elsif($StopStart eq "START") {
	&startBroker(\@results,\@messages);
	&checkBrokerStatus(\@results,\@messages,$RegExpStart,$COMMAND);
}
else {
	print "Argument must be STOP or START\n";
	exit 1;
}

&doMail(\@messages,$SUBJECT,$ME,$MAILTO);
system("$PERL_EXE ${SCRIPT_LOC}/fixPSTable2.pl");
#print "FINAL STATEMENT=@messages\n";

sub startBroker {
      my $resultsRefArry=$_[0];
        my $messageRefArry=$_[1];

        my $tmp;

        $tmp="Attempting to start BROKER    ";
	print "$tmp";
        push(@$messageRefArry,$tmp);
        @$resultsRefArry=`/opt/ibm/mqsi/7.0/bin/mqsistart  RP_BROKER`;
	&removeBlankElements($resultsRefArry);
        sleep(20);
    if ($? == -1) {
        $tmp="Failed to execute: $!";
        print "$tmp";
        push(@$messageRefArry,$tmp);
    }
    elsif ($? & 127) {
        $tmp=sprintf "[This is unsuccessful]START_BROKER_COMMAND:child died with signal %d, %s coredump\n", ($? & 127), ($? & 128) ? 'with' : 'without';
        push(@$messageRefArry,$tmp);
    }
    else {
        $tmp=sprintf "[This is SUCCESSFUL]START_BROKER_COMMAND:child exited with value %d", $? >> 8;
        push(@$messageRefArry,$tmp);
    }
        my $RegExp="Successful";
        my $ok=0;
        $ok=checkBrokerStatusArray($resultsRefArry,$RegExp,$messageRefArry);  #PARSE THE RESULTS  - the Array itself
        if($ok)  {
                        $tmp="STATUS(mqsistart RP_BROKER) of the BROKER stop action is OK ($ok)";
                        print "$tmp";
                        push(@$messageRefArry,$tmp);
        }
        else  {
               $tmp= "CheckBrokerStatus(mqsistart RP_BROKER) had a problem.  ";
                print "tmp";
                push(@$messageRefArry,$tmp);
        }
        return $ok;
        @results=();
}

sub stopBroker   {
        my $resultsRefArry=$_[0];
        my $messageRefArry=$_[1];

	my $tmp; 

        $tmp="Attempting to stop BROKER    ";
	print "$tmp";
        push(@$messageRefArry,$tmp);
	@$resultsRefArry=`/opt/ibm/mqsi/7.0/bin/mqsistop -i RP_BROKER`;
	#removeBlankElements($resultsRefArry);
        sleep(10);
    if ($? == -1) {
	$tmp="Failed to execute: $!";
        print "$tmp";
	push(@$messageRefArry,$tmp);
    }
    elsif ($? & 127) {
        $tmp=sprintf "[This is unsuccessful]STOP_BROKER_COMMAND:child died with signal %d, %s coredump   ****", ($? & 127), ($? & 128) ? 'with' : 'without';
	push(@$messageRefArry,$tmp);
    }
    else {
        $tmp=sprintf "STOP_BROKER_COMMAND:child exited with value %d  [VALUE of zero is successful]", $? >> 8;
	push(@$messageRefArry,$tmp);
    }
        my $RegExp="Successful";
        my $ok=0;
        $ok=checkBrokerStatusArray($resultsRefArry,$RegExp,$messageRefArry);  #PARSE THE RESULTS  - the Array itself
        if($ok)  {
			$tmp="STATUS(mqsistop -i RP_BROKER) of the BROKER stop action is OK ($ok)";
                        print "$tmp";
			push(@$messageRefArry,$tmp);
        }
        else  {
               $tmp= "CheckBrokerStatus(mqsistop -i RP_BROKER) had a problem.  ";
		print "tmp";
		push(@$messageRefArry,$tmp);
        }
        return $ok;
	#print "RESULTS=@$resultsRefArry \n";
	@results=();	
}
sub checkBrokerStatus {  # checks results of mqsistatusRP (if dev) or getstatus.ksh ( prod) or ./mqsistatusRP (UAT)
        my $resultsRefArry=$_[0];
        my $msgRefArry=$_[1];
	my $re=$_[2];
	my $CMD=$_[3];
	my $tmp;
         @$resultsRefArry=`$CMD`;
	###push(@$msgRefArry, @$resultsRefArry);
	#NOTE : need to strip brackets from the array lines
	&stripBrackets($resultsRefArry);
        sleep(20);
	#print "INSIDE checkBrokerStatus: RESULTS=  @$resultsRefArry \n";
	print "Inside checkBrokerStatus() will search for RegularExp [$re]\n Is this correct?\n";
    if ($? == -1) {
        $tmp= "failed to execute in checkBrokerStatus(): $!\n";
	print "$tmp";
		push(@$msgRefArry,$tmp);
    }
    elsif ($? & 127) {
        $tmp=sprintf "Child process died with signal %d, %s coredump\n", ($? & 127), ($? & 128) ? 'with' : 'without';
	print "$tmp";
		push(@$msgRefArry,$tmp);
    }
    else {
        $tmp=sprintf "Child process exited with value %d  [If this value is 0, then successful] \n", $? >> 8;
	print "$tmp";
		push(@$msgRefArry,$tmp);
    }
        my $ok=checkBrokerStatusArray($resultsRefArry,$re,$msgRefArry);
        if($ok)  { 
		$tmp= "\n(mqsistatusRP)STATUS OF BROKER ok\n"; 
		print "$tmp";
		push(@$msgRefArry,$tmp);
	}
        else  { 
		$tmp= "(mqsistatusRP)STATUS of broker is not ok \n"; 
		print "$tmp";
		push(@$msgRefArry,$tmp);
	}
        return $ok;
}

sub checkBrokerStatusArray   {
                my $arrayRef=$_[0];
                my $RE=$_[1];
		my $msgArrayRef=$_[2];
                my $ok=0;
		my $tmp;
		#print "INSIDE checkBrokerStatusArray   @$arrayRef \n";
		my $line;
        for $line (@$arrayRef) {
		chomp($line);
		#print "$line \n";
                if( $line =~ /$RE/ ) {
			$tmp= "checkBrokerStatusArray: [$line]  The $RE search string was found.";
			print "$tmp";
			push(@$msgArrayRef,$tmp);	
                        $ok=1;
		}
        }
return $ok;
}
sub stripBrackets {
	my $arrayRef=$_[0];
	my $size= @$arrayRef + 0;
	my $i;
	for ($i=0; $i<$size; $i=$i+1 ) {
		$arrayRef->[$i] =~ s/[\[,\]]//g  ; 
	}
}
sub doMail  {
        my $arrayRef=$_[0];
        my $SUBJECT=$_[1];
        my $ME=$_[2];
        my $MAILTO=$_[3];
	my $stmt="STATUS ";
	&flattenArray($arrayRef,\$stmt);

               # local( *STATUS ) ;
               # open( STATUS, $statusOut ) or die "$statusOut file problem - cannot open $!n";
               # my $text = do { local( $/ ) ; <STATUS> } ;
               # close(STATUS);

                
        `/bin/echo "$stmt"  | /usr/bin/mailx -s "$SUBJECT" -r "$ME"   "$MAILTO"`;
}
sub flattenArray {
		my $arrRef=$_[0];
		my $sRef=$_[1];
		my $element;
	foreach $element (@$arrRef) {
		$$sRef = $$sRef . "$element\n ";
	}
print "flattenArray() dereferenced sRef [$$sRef]\n";
}
sub removeBlankElements {
		my $arrRef=$_[0];
 		my $size= @$arrRef + 0;
        	my $i;
        	for ($i=0; $i<$size; $i=$i+1 ) {
			#  chomp($arrRef->[$i]);
                	  $arrRef->[$i] =~ s/\n$/:/g  ;
        	}
}
