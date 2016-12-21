#!/usr/bin/perl
use strict;
use DBI;
use DBD::DB2::Constants;
use Time::localtime;
use IO::File;

########################################
##   getDB2ResultsSubmitted2.pl 
##   has possible arg
## PURPOSE :  Do  query for Submitted reports and do UPDATES 
########################################
my $tm = localtime;
my $TS = sprintf("%04d-%02d-%02d_%02d%02d", substr(($tm->year)+1900,0,4),($tm->mon)+1,$tm->mday,$tm->hour,$tm->min);
my $yyyymmdd = sprintf("%04d-%02d-%02d", substr(($tm->year)+1900,0,4),($tm->mon)+1,$tm->mday);

if ( @ARGV == 0 ){
  	print " No date was passed into the script so I will use the current date of $yyyymmdd\n";
}
elsif (@ARGV == 1) {
	$yyyymmdd = $ARGV[0];
	if ($ARGV[0] !~ /\d\d\d\d\-\d\d\-\d\d/ ){
  		print " Bad Date Format:$ARGV[0]: enter one argument for specified date in yyyy-mm-dd format OR leave it blank for current date\n";
	}
}
else {
  	print " Wrong number of arguments - enter one argument for specified date in yyyy-mm-dd format OR leave it blank for current date";
}

print "======================\n";
print "STARTING $0 at $TS\nWill search report table using date of $yyyymmdd\n";
print "======================\n";

my $MAILTO="gagraham\@us.ibm.com,varian\@us.ibm.com,jblacks\@us.ibm.com";
#my $MAILTO="gagraham\@us.ibm.com";
my $ENV="PROD";
my $ME="g03zcimq001.ahe.boulder.ibm.com";
my $NEWSUBJECT="CRON: Submitted Reports  STATUS - $ME ";
my %CONFIG;
#my $PROGRAM_DIR="/var/mqsi/rp/TOOLS";
my $PROGRAM_DIR="/home/mqbrkr/tasks";
###my $outputCSV="submittedOutput_$TS.csv";
###open(CSV,">>",$outputCSV) or die "Cannot open $outputCSV for appeneding $! \n"; 
&fetch_db_params;
# AWK COMMAND
#my $passwd=`awk -F";" 'NR==1{print $1}' $PROGRAM_DIR/file.env`;
#my $id=`awk -F";" 'NR==2{print $1}' $PROGRAM_DIR/file.env`;
#my $dbname=`awk -F";" 'NR==3{print $1}' $PROGRAM_DIR/file.env`;
#chomp($passwd);
#chomp($id);
#chomp($dbname);
my $passwd=$CONFIG{password};
my $id=$CONFIG{dbuser};
my $dbname=$CONFIG{dbname};


 
#------------------------------------------------------------------
# Connect to database
#------------------------------------------------------------------
	my $dbh=getDbConnection($passwd,$id,$dbname);
#------------------------------------------------------------------
# DO QUERY 
#------------------------------------------------------------------
my @arrayBPTRANS=();
my $sql=
	"SELECT report_row_id as RPT_ID, substr(bp_transmission_id,1,35) as bpTransID, status as STAT, DELETE_FLAG as D, parent_report_row_id as Prpt, report_type,updated from wwbpsm.reports where date(updated) = '$yyyymmdd' and status = 'SUBMITTED' AND report_row_id NOT in(SELECT max(report_row_id) from wwbpsm.reports) ORDER BY report_row_id, report_type FOR READ ONLY";
print "SQL:\n$sql\n\n";


	my @array2D=(); # will have final results
	###my $tmp = "report_row_id,bp_trans,status,delete_flag,parent_report_row_id,report_type,updated";
print " * * * * * *\n\n";
	###print CSV "$tmp\n";
	selectSub($dbh,$sql,\@array2D);
	my $recCnt=@array2D + 0;
	my %rpt_bptrans_hash;
	my %rpt_replace_hash;
	my $stmt="";
	if($recCnt > 0) {
		$stmt="SUBMITTED REPORTS FOUND and I will UPDATE the delete_flag to Y to prevent improper replacements:\nRESULTS of UPDATE:\n";
		for(my $i=0;$i < @array2D;$i++) {
                	my $tmpArrRef=$array2D[$i];
                	if($tmpArrRef) {
                       		# REPORT_ROW_ID=0,BP_TRANSMISSION_ID=1 
                                if($tmpArrRef->[0]){
					if($tmpArrRef->[4]) {
						$rpt_bptrans_hash{$tmpArrRef->[0]} = "$tmpArrRef->[1]" ; # report row id ->bp_transmission_id
						$rpt_replace_hash{$tmpArrRef->[0]} = "$tmpArrRef->[4]" ; # report row_id -> parent_report_row_id
					}
					else {
						$rpt_bptrans_hash{$tmpArrRef->[0]} = $tmpArrRef->[1];
					}
					$arrayBPTRANS[$i]=trim($tmpArrRef->[1]);   # save just thel listing
				}
			}
		}
	}
	else {
		print "======================\n";
		print "No reports records in SUBMITTED Status.\n";
		print "======================\n";
	}
	#print "Call print2Darr\n";
	#print2DArr(\@array2D);

# SET up final report for mailing
	if($stmt) {
		my @array2Da=();
		foreach my $rpt (sort keys %rpt_bptrans_hash) {
			my $sqlY="Update wwbpsm.reports set DELETE_FLAG = 'Y' where DELETE_FLAG = 'N' and report_row_id = ";
			#  $stmt=$stmt . "$rpt : $rpt_bptrans_hash{$rpt}\n";

			$sqlY=$sqlY . $rpt;

			# $stmt=$stmt . "UPDATE SQL=$sqlY\n";
			 # print "(1)DO UPDATE of report table: $sqlY\n";
			 &updateReports($dbh,$sqlY);
		}
		selectSub($dbh,$sql,\@array2Da);
		print2DArrToVar(\@array2Da,\$stmt);
		$stmt=$stmt . "NOTE:If any SUBMITTED reports attempted to replace a report... I will update the original report to delete_flag=N \n";
		#################################################################################
		# Fix report that had been improperly replaced - change delete_flag from Y to N
		# HOWEVER, if this was already corrected, we don't want to "correct" this again
		# THerefore, before updating, make sure that there is ONLY ONE parent_report_row_id (the SUBMITTED replacement)
		# There could be another if this was fixed OR another report came in
		#################################################################################
		my $sqlP = "SELECT count(*) from wwbpsm.reports WHERE parent_report_row_id =  ";
		foreach my $rpt (sort keys %rpt_replace_hash) {
			$stmt=$stmt . "REPLACED REPORT ROW : $rpt_replace_hash{$rpt}\n";
			# There must only be one instance of the parent_report_row_id
			$sqlP=$sqlP . $rpt_replace_hash{$rpt};
			my $cntP=&selectSimple($dbh,$sqlP);
			print "RETURNED cntP=$cntP where 1 is expected and 2 or more indicates more replacements came in...please check \n";
			if($cntP eq 1) {
				my $sqlN="Update wwbpsm.reports set DELETE_FLAG = 'N' where DELETE_FLAG = 'Y' and report_row_id = ";
				$sqlN=$sqlN . $rpt_replace_hash{$rpt};
				$stmt=$stmt . "UPDATE SQL=$sqlN\n";
			  	#print "(2)DO UPDATE of report table: $sqlN\n";
			   	&updateReports($dbh,$sqlN);
				print2DArr(\@array2Da);  # this is only for the console

				my $sqlS= "SELECT report_row_id, substr(bp_transmission_id,1,35),status,delete_flag,parent_report_row_id from wwbpsm.reports where report_row_id = $rpt_replace_hash{$rpt} ";	
				@array2Da=();
				selectSub($dbh,$sqlS,\@array2Da);
				print2DArrToVar(\@array2Da,\$stmt);
			}
			else {
				$stmt=$stmt . "REPLACED report will not be updated because a 2nd replacement came in - may have been a previous fix today\n";
			}
		}
		# MAIL STMT was here but moved to end
				$stmt=$stmt . "* * * * *\n";
	}
	else {
		$stmt="No reports records in SUBMITTED Status - $ME\n";
		`/bin/echo "$stmt"  | /usr/bin/mailx -s "$NEWSUBJECT" -r "$ME"   "$MAILTO"`;
		$dbh->disconnect;
		exit(0);
	}


	#print "BP_TRANSMISSION_IDS\n";
	my $qstr= join ("," ,map {"'$_'"} @arrayBPTRANS) ;
	
	#print "$qstr\n";
	my $sqlS="SELECT report_row_id,substr(bp_transmission_id,1,35),status,delete_flag,parent_report_row_id,created FROM wwbpsm.reports WHERE bp_transmission_id IN($qstr)";
	# do Select into 2Darray
	my @array2Db=();
	selectSub($dbh,$sqlS,\@array2Db);
	# print results
	$stmt=$stmt . "\nState of Report Table for current Submitted on $yyyymmdd using this SQL:\n$sqlS \n\n"; 

	print2DArrToVar(\@array2Db,\$stmt);
	$stmt=$stmt . "Note: If \"Validated\" follows a \"Submitted\" then we are ok. Ensure that a replacement replaced the correct report\n";
	######### FINAL STMT ##############
	`/bin/echo "$stmt"  | /usr/bin/mailx -s "$NEWSUBJECT" -r "$ME"   "$MAILTO"`;
	print "\n$stmt\n";

	$dbh->disconnect;
###close(CSV);

sub getDbConnection {
		my $pwd = $_[0];
		my $userId = $_[1];
		my $dbname = $_[2];
                        #my $dbname = "reppaydb";
                        #my $userId = "wbiadmn";
                        my $dbd    = "DB2";
                        my $dsn = "DBI:DB2:$dbname";
        ##print "TRANSFORM: SETUP for  database $dsn, userID=$userId\n";
        my %conattr =
        (
                AutoCommit             => 1,
                   # Turn Autocommit On
                db2_info_applname  => 'compareFiles',
                           # Identify this appl
                LongReadLen           => 2000

        );

        my $dbh = DBI->connect($dsn,$userId,$pwd,\%conattr) or die  $DBI::errstr;
	print "======================\n";
        print "Connected to $dbname\n";
	print "======================\n";
return $dbh;
}
sub selectSub  {
	my $DBH  =  $_[0];
	my $sql  =  $_[1];
	my $arrRef = $_[2];
	my $ref;
	my $i=0;

      my $sth = $dbh->prepare($sql);
      $sth->execute;
	#print "In selectSub, waiting for return of sql...";
      while (my $ref = $sth->fetchrow_arrayref) {
            if(defined($ref) )  {
 		$arrRef->[$i]= [@$ref];
		$i=$i+1;
           }
		$ref=0;
	
      }
}
sub selectSimple {
	my $DBH  =  $_[0];
	my $sql  =  $_[1];
	my $ret=0;
	my @row=();
      my $sth = $dbh->prepare($sql);
      $sth->execute;
	@row=$sth->fetchrow_array;
return $row[0];
}	

sub print2DArr  {
        my $arrRef = $_[0];
        for(my $i=0;$i < @$arrRef;$i++) {
		my $tmpArrRef=$arrRef->[$i];
		#print "DEBUG print2DArr: Ref=$tmpArrRef   ";
		if($tmpArrRef) {
			for(my $j=0;$j < @$tmpArrRef;$j++) {
				if($tmpArrRef->[$j]){
					my $val=trim(replaceInternalSpaces($tmpArrRef->[$j]));
                			###print CSV "$val ,";
				}
				else {
					###print CSV "EMPTY ,";
				}
			}
			###print  CSV "\n";
		}
        }
        print "********\n";
}
# Append to stmt string the result set contained in the arrRef
sub print2DArrToVar  {
        my $arrRef = $_[0];
        my $s 	   = $_[1];
        for(my $i=0;$i < @$arrRef;$i++) {
		my $tmpArrRef=$arrRef->[$i];
		if($tmpArrRef) {
			for(my $j=0;$j < @$tmpArrRef;$j++) {
				if($tmpArrRef->[$j]){
					my $val=replaceInternalSpaces(trim($tmpArrRef->[$j]));
					$$s=$$s . "|$val";
				}
			}
		$$s=$$s . "\n";
		}
        }
	$$s=$$s . "\n";
}
sub updateReports  {
        my $DBH  =  $_[0];
        my $sql  =  $_[1];
        my $ref;
      my $sth = $dbh->prepare($sql) or die "Cannot prepare sql $sql $!";;
      $sth->execute or return 0;

return 1;
}

sub replaceCommas {

        my $str = $_[0];
        $str =~ s/,/ /g;
        $str =~ s/\'/ /g;
        return $str;
}
sub replaceInternalSpaces {
        my $str = $_[0];
        $str =~ s/\s/_/g;
        return $str;
}

sub trim {
        my $str =   $_[0];
        if(defined($str)) {
                $str=~s/^\s+//;
                $str=~s/\s+$//; 
        }

        return $str;
        
}



#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub fetch_db_params{
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# Initialize the db variables
#----------------------------------------------------------------------------
my $config_file="db2access.conf";
my $CONFIG = IO::File->new("$config_file","<") or die "\nError: Can't open $config_file. $! \n\n";

my $line;
while(defined($line = $CONFIG->getline())){
        next if $line =~ /^#/;   # skipping comments
        if ($line =~ /(.*?)\=(.+)/) {
          my $key=$1;
                my $value=$2;
                $value=~s#\"(.*)\"#$1#g;   # removing quotes if any
                $value=~ s#^\s+|\s+$##g;   # removing leading/trailing spaces if any
                $key=~s#^\s+|\s+$##g;
                $CONFIG{$key} = $value;
        }
}
$CONFIG->close();

} # end subroutine


