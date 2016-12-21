#!/usr/bin/perl
use strict;
use DBI;
use DBD::DB2::Constants;

########################################
##   fixPTSTable.pl
## PURPOSE 
##  Run on Sunday early morning after database maintenance
## if complete_ts is null for reports could indicate a problem IFF it remains that way for 15 minutes at least.  Detect this condition by
## sleeping for 15 minutes; then update the complete_ts to current date ; send documentation by mailx
##   Showing
#PROCESS_NAME:START_TS:COMPLETE_TS; UPSB:2011-12-21 16:04:57.515000:2011-12-21 16:07:31.108000;  RPTS:2011-12-21 16:13:33.695000:NULL; <-before start 
##PROCESS_NAME:START_TS:COMPLETE_TS; UPSB:2011-12-21 16:04:57.515000:2011-12-21 16:07:31.108000;  RPTS:2011-12-21 16:13:33.695000:NULL; <-after 15 minutes still same, do update! 
##PROCESS_NAME:START_TS:COMPLETE_TS; UPSB:2011-12-21 16:04:57.515000:2011-12-21 16:07:31.108000;  RPTS:2011-12-21 16:13:33.695000:NULL;  <-shows NOT updated which is unsuccessful
##																	Otherwise, last NULL is a TS showing update
##
########################################
print " STARTING $0\n";
my $MAILTO="gagraham\@us.ibm.com,varian\@us.ibm.com";
my $ENV="PROD";
my $NEWSUBJECT="Process Serialization for $ENV after Recycle";
my $ME="g03zcimq001.ahe.boulder.ibm.com";
my $PROGRAM_DIR="/home/mqbrkr/tasks";



# AWK COMMAND
my $passwd=`awk -F";" 'NR==1{print $1}' $PROGRAM_DIR/file.env`;
my $id=`awk -F";" 'NR==2{print $1}' $PROGRAM_DIR/file.env`;
my $dbname=`awk -F";" 'NR==3{print $1}' $PROGRAM_DIR/file.env`;

chomp($passwd);
chomp($id);
chomp($dbname);

 
#------------------------------------------------------------------
# Connect to database
#------------------------------------------------------------------
##my $SLEEP = 10;
	my $SLEEP = 1;
	my $dbh=getDbConnection($passwd,$id,$dbname);
	my $ref;
	my $startTime;
	my $res;
	my $save;
	my $PROCESS_NAME;
	my $stmt = "No changes to process_serialization necessary\n";;
	my $process_name_flag_RPTS;
	my $process_name_flag_UPSB;
for $PROCESS_NAME ('RPTS','UPSB'){ 
	$save=selectPS($dbh);
	print "RESULTS for selectPS for $PROCESS_NAME  \n$save\n";
	my $sql = "SELECT start_ts from wwbpsm.process_serialization where process_name = '$PROCESS_NAME' and complete_ts is NULL for read only";
	# get StartTime if NULL complete_ts exists
	$res=getStartTime($dbh,$sql);
	$startTime=$res;
	print "INITIAL START_TS if null column for $PROCESS_NAME for complete_ts is $startTime    \n ";

	if( $startTime ) {
		print "No null complete_ts found for $PROCESS_NAME \n";
			
	}
	sleep($SLEEP);
	$save .= selectPS($dbh);
	$res=getStartTime($dbh,$sql);
	print "After some time,  START_TS is [$res] (if empty, that means no  NULL complete_ts which is stable.    \n ";



	if($startTime and $startTime eq $res)  {
		print "INFO: $startTime == $res\n";
		$sql = "UPDATE wwbpsm.process_serialization SET complete_ts = current timestamp where process_name = '$PROCESS_NAME'";
		$res=updatePS($dbh,$sql);	
		if($res eq 1 ) {  #successful update send mail successful change
			$stmt="Process Serialization successfully updated after $SLEEP seconds of RPTS having null TS\n";
		}
		else  {
			#unsuccessful update special mail needs attention
			$stmt="Process Serialization  NOT successfully updated after $SLEEP seconds of RPTS having null TS\n";
		}
	}
}

# SET up final report for mailing
	$save .= selectPS($dbh);
	$stmt = $stmt . "\n" . $save;
	print "\nFINAL STATEMENT:\n$stmt\n";
	`/bin/echo "$stmt"  | /usr/bin/mailx -s "$NEWSUBJECT" -r "$ME"   "$MAILTO"`;



	$dbh->disconnect;

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
        print "Connected to $dbname\n";
return $dbh;
}
sub getStartTime  {
	my $DBH  =  $_[0];
	my $sql  =  $_[1];
	my $ref;
	my $tmp="";
      my $sth = $dbh->prepare($sql);
      $sth->execute;
      while ($ref = $sth->fetchrow_arrayref) {
            if($ref )  {
                           $tmp = $ref->[0];
           }
      }
return $tmp;
}
sub updatePS  {
	my $DBH  =  $_[0];
	my $sql  =  $_[1];
	my $ref;
      my $sth = $dbh->prepare($sql) or die "Cannot prepare sql $sql $!";;
      $sth->execute or return 0;

return 1;
}
sub selectPS  {
	my $DBH  =  $_[0];
	my $sql  = "SELECT process_name, start_ts,complete_ts from wwbpsm.process_serialization where process_name in ('RPTS','UPSB') for read only"; 
	my $tmp = "PROCESS_NAME:START_TS:COMPLETE_TS;\n ";
      my $sth = $dbh->prepare($sql);
      $sth->execute;
      while ($ref = $sth->fetchrow_arrayref) {
            if(defined($ref) )  {
 		if( ( !defined($ref->[2]) ) || ($ref->[2] eq "") ) { $ref->[2] = "NULL"; }
                $tmp .= substr($ref->[0],0,4) . ":" .  "$ref->[1]"  . ":" . "$ref->[2];" . "\n" ;
           }
      }
return $tmp;
}



