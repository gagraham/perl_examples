#!/usr/bin/perl
use strict;
use IO::File;
use Time::localtime;
use File::Copy;
use DBI;
use DBD::DB2::Constants;


###################################
# if there are no serials, then the DDET08QTY does not reflect the number of rows
#	DDET08QTY        56 00000000002.000PCE   where 56 is one of possible list of indicator, and 2 is the QTY
#  	DDET08NAD        MF   for manufacturer ( we do not count those)
#       DDET08RFF        SE   for Serials - we don't count these because the QTY DDETO8QTY reflects the true number of rows
# For Header info - parse GXS Sales
#	DHDR00DTM        90 20131202                           102  <- 1st date
#	DHDR00DTM        91 20131202                           102  < 2nd date
#	DHDR01NAD        MS 0026893061                               <-  CMR
#
# 	VERSION 2 - includes formatting for branches and weekly reports
##
## GLOSSARY - this has changed from the original.  To allow for backwards compatibility for the output reports, will use deprecated columns
## InputLINSegments = LIN segments are counted
## ZEROQuantitySegments= No longer counted - will be ---
## Quantity Segments= No longer counted - will be ---
## MF_LINES will be counted  - represents LIN segments that are MF ( Manufacturer and we don't care if there are SE or QTY)
## SE_LINES will be counted - represents total non-manufacturer SE lines
## NET_LINES will be counted - represents total rows expected in the PTS - GXS SE lines if QTY value >1 otherwise QTY
## PTS_LINES will be counted - represents total rows actually in the PTS
## Ceid,BP_Name,Country,FLAG,Frequency comes from BPInfo extracted from the Business_Partner and BP_REPORT_PARAMETERS tables
##
## LOCATIONS
###################################
#my $PROGRAM_PATH="/home/mqbrkr/daily_status";
my $PROGRAM_PATH="/home/gagraham/COMPARE";
############################################################################################
my $QTY=0; #TOTAL QTY from qty segments - this actually is the number of rows expected
	   # If a LIN block has serials, serials=rows;  If no serials, then row increment by 1
## This script will start to look at today's date list of files and append to the report 
############################################################################################


my ($IN,$OUT);
my $JAVA_OUTPUT="weekly_output.txt";  # This file is hard coded unfortunately, in the java that is called
my $BASEDIR="/var/mqsi/rp/GXSSal/mqsiarchive";
my $PTS_MQSIARCHIVE="/var/mqsi/rp/ptsfiles/mqsiarchive";
my $EXPECTED_PTS_FILE_NAME;
my $filetype="S"; 
my $PTS_LINES;
#########################DATE AND TIME
my $tm = localtime;
my $TS = sprintf("%04d%02d%02d%02d%02d%02d",
          substr(($tm->year)+1900,0,4),($tm->mon)+1,$tm->mday,$tm->hour,$tm->min,$tm->sec);
print "TIMESTAMP is $TS\n";
my $HHMM = sprintf("%02d%02d", $tm->hour,$tm->min,$tm->sec);
my $yyyymmdd=sprintf("%04d%02d%02d",substr(($tm->year)+1900,0,4),($tm->mon)+1,$tm->mday);
############### Print to CSV report - will become relevent when looping through multiple files #################
## Commented out for now except to test it. 

my $searchDate=$yyyymmdd;
#my $searchDate  = $ARGV[0] or die "\n    --> enter date in yyyymmdd format\n $usage_list" ;

my $csv_file = $PROGRAM_PATH . "/" . "CompareGXSSalCountsWithPTS_${searchDate}_${HHMM}.csv";
$OUT = IO::File->new($csv_file, ">>") or die "\n Error - Unable to open $csv_file, $!";
	#open(CSV,">>",$csv_file) or warn "cannot open CSV $csv_file    $!" ;

        print $OUT "INPUT FileName,OUTPUT FileName,InputLINSegments,ZEROQuantitySegments,Quantity Segments,MF_LINES,SE_LINES,NET_LINES,PTS LINES, Ceid, BP_name,Country,FLAG,Frequency,comments \n";


########################################
##   dbInterface - basic DB2
########################################
my $passwd=`awk -F";" 'NR==1{print $1}' $PROGRAM_PATH/file.env`;
my $id=`awk -F";" 'NR==2{print $1}' $PROGRAM_PATH/file.env`;
my $dbname=`awk -F";" 'NR==3{print $1}' $PROGRAM_PATH/file.env`;

chomp($passwd);
chomp($id);
chomp($dbname);

print  "id=[$id] dbname=[$dbname]";
#------------------------------------------------------------------
# Connect to database
#------------------------------------------------------------------
my $dbh=getDbConnection($passwd,$id,$dbname);  #DATABASE HANDLER to be passed as needed to subs
########################################


&validate_args;
#GLOBAL VARIABLES

# NON_GLOBAL VARIABLES
	my $QTY_MF=0; #TOTAL QTY from qty segments in Manufacturing tagged segments
	my $QTY_SE=0; #TOTAL QTY from SE segments in non- Manufacturing tagged segments
	my @arrTemp=();
	my ($STARTDATE,$ENDDATE,$CMR,$branch,$REPORTDATE,$ACTION);
	my $currSODATE=0;
	my $prevSODATE=0;
	my $previous=0;  #first line  IMPORTANT - will be the previous LIN block
	my $n=0; # count within the LIN segements
	my $lineNum=1;
 	my $input_file  = $ARGV[0] or &usage  ;
	my $last_line=0;
	print "\nReading input file $input_file\n";

	# open the GXS input and count lines and close - needed in case no EOF marking so we identify last line

	$IN = IO::File->new($input_file, "r") or die "\n Error - Unable to open $input_file, $!";
	$last_line++ while(<$IN>);
	$IN->close;
	print " LAST LINE=$last_line\n";

	# reopen the GXS input
	$IN = IO::File->new($input_file, "r") or die "\n Error - Unable to open $input_file, $!";
	my $LINE=1;  # overall count of every line

while (my $line = <$IN>){
	# create the bp_transmission_id from the given dates and CMR ( but this is not totally accurate for weekly BPs)
	if($. <= 10) {
		 if( $line =~ /^DHDR00BGM.{8}.{94}(\d).*$/ )  {			#ACTION
                                $ACTION=$1;
                                if($ACTION) { $ACTION=getAction($ACTION); }
                                else { $ACTION = " "; }
                }
		if( $line =~ /^DHDR00DTM\s{8}90\s(\d{8}) / ) {                      #DATE1
			$STARTDATE=&formatDate($1);
			#print "STARTDATE=$STARTDATE\n";
		}
		if( $line =~ /^DHDR00DTM\s{8}91\s(\d{8}) / ) {                      #$DATE2
			$ENDDATE=&formatDate($1);
			#print "ENDDATE=$ENDDATE\n";
		}
 		if ( $line  =~ /^DHDR03DTM.{8}402(\d{8}).*$/ ){			     #REPORTDATE
                         $REPORTDATE=$1;
			if( ! $REPORTDATE) { $REPORTDATE = "       " };
		}
		if ( $line =~ /^DHDR01NAD\s{8}MS\s(\d+) / ) {			#CMR	
  			$CMR=leftPadCMRZeros($1);
                        print "CMR after left zero padding is $CMR\n";
		}
		if ($line =~ /^DHDR01NAD\s{8}DB\s(.+) / ) {			# optional BRANCH
			$branch=trim(substr($1,0,5));
		}
		if ($line =~ /^DHDR01NAD.{8}BD\s(.+}) / ) {
			$branch=trim(substr($1,0,5));
		}
                

	}
	if ($. 	>  10) {
		#start point is a LIN segment; when next LIN segment starts, refresh hash
		if ( $line =~ /^DDET07LIN\s{8}(\d+)\s/ ) {
			#DEBUGprint"START NEW DDET07LIN ***********************\n";
			if ($1 > $previous) {
				if($1>1) {
					#DEBUGprint "For LIN segment $previous: num of lines=$n within that DDET07LIN\n";
					&getArrCnts(\@arrTemp,\$QTY,\$QTY_MF,$previous,\$QTY_SE,\$currSODATE,\$prevSODATE);
					$previous=$1;  # increment previous to current 
					# clear the array to start again	
					@arrTemp=();
				}
				elsif($1==1) {
					$previous=$1;  # increment previous to current 
					# clear the array to start again	
					@arrTemp=();
				}
			$n=0;
			}
		}
		else {
			push(@arrTemp,$line);
			$n=$n+1;
		}
	}

if ( ($line =~ /^EOF/ )  or ($.== $last_line)) {
	 #DEBUGprint "For LIN segment $previous: num of lines=$n within that DDET07LIN\n";
	&getArrCnts(\@arrTemp,\$QTY,\$QTY_MF,$previous,\$QTY_SE,\$currSODATE,\$prevSODATE);
	next;
}
$LINE=$LINE+1;
}
# done with table close PTS 
$IN->close();
print "STATS\n";
print "\tTOTAL Lines=$LINE\n";
print "\tTOTAL DDET07LIN segments=$previous\n";
print "\tTOTAL QTY=$QTY=TOTAL EXPECTED ROWS IN PTS FILE |   TOTAL MANUFACTURER QTY=$QTY_MF\n";
print "\tTOTAL QTY_SE=$QTY_SE (non-manufacturer and just FYI) \n";
	my $BRANCH_flag;   
	$CMR=&formatCMR_BRANCH($branch,\$BRANCH_flag,$CMR); 


	my $dbCMR;
	$dbCMR=&format_dbCMR(\$BRANCH_flag,$CMR);
	my $bpInfo=findBP($dbh,$dbCMR,$BRANCH_flag);  
        my @tmpArr=split(/,/,$bpInfo);                	##get last element
        my $freq=trim(pop @tmpArr);             	
	#print "   frequencey=[$freq]   ";
        #print "findBP results:\n $bpInfo\n";
	if($freq eq "WEEKLY") {
		createWeeklyName($dbCMR,\$STARTDATE,\$ENDDATE);
		#print "WEEKLY FILE : CMR=$CMR,STARTDATE=$STARTDATE,ENDDATE=$ENDDATE \n";
	}

	###print "MAX SODATE =$currSODATE\n";
	##print "BRANCH_flag=$BRANCH_flag; CMR with or without branch is $CMR; dbCMR=$dbCMR\n";
	#print "bp_transmission_id=${CMR}${STARTDATE}${ENDDATE}\n";
#############################################################
# NEED TO CONSTRUCT THE EXPECTED PTS FILE TO MATCH THIS GXS!
#############################################################
# IF the GXS file was empty ( had no LIN segements ) special case no compare needed

my $ZEROQTYSEG = "---";
my $QTYSEG = "---";
my $MF_LINES=$QTY_MF;
my $NET_LINES=$QTY;
my $GXS_LINES=$previous;  # last value of DDET07LIN segment from loop
my $SE_LINES=$QTY_SE;
my $f=$input_file;
my $PTS_FILE_NAME;
my $BODY;
  if(${previous} + 0  == 0) {
                $GXS_LINES = "0";
                $PTS_LINES = "NA";
                $MF_LINES = "0";
                $SE_LINES = "0";
                $NET_LINES = "NA";
   }
   else {
 	$EXPECTED_PTS_FILE_NAME = "GXS_${CMR}${STARTDATE}${ENDDATE}_${filetype}_${ACTION}_${REPORTDATE}_PROD.txt";
	print "\nEXPECTED PTS=$EXPECTED_PTS_FILE_NAME\n";
 	chdir($PTS_MQSIARCHIVE);
	$PTS_FILE_NAME=&findPTSFile($EXPECTED_PTS_FILE_NAME,\$PTS_LINES);        
  	print "PTS_FILE_NAME is $PTS_FILE_NAME with count $PTS_LINES\n";
   }

 	print $OUT  "${f}, ${PTS_FILE_NAME}, ${GXS_LINES},${ZEROQTYSEG},${QTYSEG},${MF_LINES},${SE_LINES},${NET_LINES},${PTS_LINES},${bpInfo} \n";

# SET UP BODY of EMAIL
  if (isDigit($NET_LINES) and isDigit($PTS_LINES) ){
                        if( ($NET_LINES + 0) > ( $PTS_LINES + 0) ) {
                                #my $row=$idx+1;   USE THIS WHEN YOU DO BIG LOOP
				my $row=1;
                                my $tmp= "row $row $f and $PTS_FILE_NAME counts( GXS $NET_LINES and PTS $PTS_LINES) do not match\n" ;
                                print $tmp;
                                $BODY = $BODY . $tmp;
                        }
                }


if(($QTY) eq ($PTS_LINES)) {
	print "============\n";
	print "\tMATCH on GXS($QTY) and PTS($PTS_LINES) counts\n";
	print "============\n";
}
else {
	print "============\n";
	print "\tNO MATCH on GXS($QTY) and PTS($PTS_LINES) counts\n";
	print "============\n";

}
$OUT->close;

print "\t\t\tPLEASE CHECK OUTPUT FILE $csv_file\n";
#system("${PROGRAM_PATH}/doEmailParseGXScounts.ksh","$csv_file", "$BODY");


sub validate_args{

#----------------------------------------------------------------------------
# validates the arguments passed to the script
#----------------------------------------------------------------------------
if ( ($ARGV[0] =~ /^-?h$/i) or ($ARGV[0] =~ /^-?help$/i)){
        &usage;
}
if ( @ARGV != 1 ){
  print "Error: Incorrect number of arguments passed to the script - mandatory 2 args\n\n";
  &usage;
}

if (! -f $ARGV[0] ) {
  print "Error: The input file - $ARGV[0] does not exist.\n";
  exit 2;
}
if ( -z $ARGV[0] ) {
  print "Error: The input file - $ARGV[0] is empty.\n";
  exit 2;
}

} # end subroutine

sub usage{

#----------------------------------------------------------------------------
# Displays the usage of the script
#----------------------------------------------------------------------------
  print "\n ***************************USAGE*******************************************";
  print "\n\n Execution: $0 <CSV_to_read> <Ticket number>  \n";
  print "\n $0 will do this: ";
  print "\n ***************************************************************************\n";
 exit 1;
} # end subroutine

sub getArrCnts {
	my	$arrRef=$_[0];
	my	$r_qty=$_[1];
	my	$r_mqty=$_[2];
	my	$seg=$_[3];
	my	$r_qty_se=$_[4];
	my $r_currSODATE=$_[5];
	my $r_prevSODATE=$_[6];


	my $qty=0;
	my $mFlag=0;
	my $sqty=0;
	my $qtyMatch=0;
	
	#iterate thru array and do counts
	foreach my $x (@$arrRef) {
			##here is where we capture the QTY, SE and MF lines in an array and do counts
			if( $x =~ /^DDET08QTY\s{8}(\d+).*0+(\d+)\.000PCE/ ) {
				print "\tFound QTY with count $2 within segment $seg \n";
				$qty=$qty + $2;  # but we don't really care - just FYI
				$qtyMatch++;
			}
			if ( $x =~ /^DDET08NAD\s{8}MF / ) {
				#DEBUGprint "\tManufacturer Quantity for segment $seg  \n";
				$mFlag=1;
			}
			if ( $x =~ /DDET08RFF\s{8}SE / ) {
				#print "\tFOUND SERIALS for segment $seg \n";
				$sqty=$sqty + 1;
			}
			#DDET08DTM        3  20131216 
			#DDET08DTM        31020131216
   			if (($x  =~ /^DDET08DTM\s{8}3\s\s(\d+) / ) || ($x  =~ /^DDET08DTM\s{8}7\s\s(\d+) / ) || ($x  =~ /^DDET08DTM\s{8}310(\d+) / )){
				#print "SODATE=$1 in seg $seg\n";
                               $$r_currSODATE=$1;
					#print "currSODATE($$r_currSODATE) or prevSODATE($$r_prevSODATE and LINE $.) \n";
                                	if( ($$r_currSODATE + 0) > ($$r_prevSODATE + 0))  { $$r_prevSODATE = $$r_currSODATE; }
				
			
        		}
	}
	if($mFlag) {
		$$r_mqty += $qty;
		#print "Final SubCounts Segment $seg:  Manufacturer qty=$qty\n";
	}
	else {  # IF there are serials, take that quantity to find rows otherwise increment by 1 because there will be one transaction of x quantity
		# Point is, we are counting transactions; a serial is one transaction; two serials=2transactions
		# If there is ONLY QTY lines and NO serials, number of transactions=number of QTY lines
		###$$r_qty += $qty;
		#print "Final SubCounts Segment $seg:  qty=$qty\n";
		if($sqty) {   # SERIALS
			$$r_qty += $sqty;	# adding serial count to ROW count
			#DEBUG
			print "Final SERIAL Subcounts Segment $seg:  sqty=$sqty\n"; 
			$$r_qty_se += $sqty;
			
		}
		else {
			if($qtyMatch) { $$r_qty += $qtyMatch;}
		}
	}
	# DEBUG
	print " $seg:QTY total is now $$r_qty\n";
}
# findMaxSODATE
# line,(prevSODATE,currSODATE as refs)
# DDET08DTM        3  20131202
sub findMaxSODATE {
	my $line=$_[0];
	my $r_currSODATE=$_[1];
	my $r_prevSODATE=$_[2];
	print "LINE in findMaxSODATE=$line";	
	if( $line =~ /^DDET08DTM\s/ ) {
		print "$line";
	}
   	if (($line  =~ /^DDET08DTM\s{8}3\s\s(\d+) / ) || ($line  =~ /^DDET08DTM\s{8}7\s\s(\d+) / ) || ($line  =~ /^DDET08DTM\s{8}310(\d+) / )) {
                                $$r_currSODATE=$1;
				print "MATCH $$r_currSODATE \n";
                                if( ($$r_currSODATE + 0) > ($$r_prevSODATE + 0))  {
                                        $$r_prevSODATE = $$r_currSODATE;
                                }
        }
	print "MAX SODATE=$$r_currSODATE\n";
}
sub formatDate {
	my $num=$_[0];
	my $y=substr($num,0,4);
	my $m=substr($num,4,2);
	my $d=substr($num,6,2);
return ($y . "-" . $m . "-" . $d);
}

##############################################

sub replaceCommas {

        my $str = $_[0];

        $str =~ s/,/ /g;
        $str =~ s/\'/ /g;

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
sub formatCMR  {
	my $str =   $_[0];
	my $padded = "";
	# This adds zeros up front to make ten chaars BEFORE any branch is involved
	if(defined($str)) {
		my $pad_char = "0";
		my $pad_len = 10;
		$str=trim($str);
		$padded = ($pad_char x ( $pad_len - length( $str )) )   . $str;
	}

	return $padded;

}
sub formatSCMR  {
	my $str =   $_[0];
	my $padded="";
	if(defined($str)) {
		my $pad_char = "_";
		my $pad_len = 15;
		$str=trim($str);
		$padded = $str . $pad_char x ( $pad_len - length( $str ) );
	}
	#print "\nIn formatSCMR padded=|$padded|\n";

	return $padded;
}
sub formatICMR {
	my $str =   $_[0];
	my $padded="";
	if(defined($str)) {
	my $pad_char = "_";
	my $pad_len = 10;
	$str=trim($str);
	$padded = $str . $pad_char x ( $pad_len - length( $str ) );
	}
	return $padded;
}
sub getAction  {
	my $str =   $_[0];
	my $a = " ";
	if($str eq "9") { $a="O";	}
	elsif($str eq "5") { $a="R"; }
	return $a;
}

#sub formatDate  {
#	my $str =   $_[0];
#	my $y = substr($str,0,4);
#	my $m = substr($str,4,2);
#	my $d = substr($str,6,2);
#	my $date = "$y-$m-$d";
#	return $date;
#}

 sub atoi {
          my $t=0;
          foreach my $d (split(//, shift())) {
            $t = $t * 10 + $d;
                #print "sub:each t=$t   ";
          }
          return $t;
        }

sub isDigit {
	foreach my $d (split(//, shift())) {
		if ( $d !~ /\d/ ) {
			return 0;
		}
	}
	return 1;
}

sub getDbConnection {
###$passwd,$id,$dbname)
                my $pwd    = $_[0];
                my $userId = $_[1];
                my $dbname = $_[2];
                my $dbd    = "DB2";
                my $dsn = "DBI:DB2:$dbname";
        #print "TRANSFORM: SETUP for  database $dsn, userID=$userId\n";
        my %conattr =
        (
                AutoCommit             => 1,
                   # Turn Autocommit On
                db2_info_applname  => 'parseGXS',
                           # Identify this appl
                LongReadLen           => 2000

        );
        my $dbh = DBI->connect($dsn,$userId,$pwd,\%conattr) or die  $DBI::errstr;
        print "Connected to $dbname\n";
return $dbh;
}

sub findBP  {
#($dbh, $CMR,BRANCH_flag)
	my $dbh=$_[0];
	my $cmr= $_[1];
	my $flag=$_[2];

	if(!$cmr) { return;}

	my $sql="SELECT bp.ceid,substr(bp.legal_name,1,30),c.country_name,brp.test_flag,brp.frequency from wwbpsm.other_system_identifiers osi JOIN wwbpsm.business_partner bp ON osi.bp_row_id = bp.bp_row_id JOIN wwbpsm.country c ON bp.country_id = c.country_row_id JOIN wwbpsm.bp_report_parameters brp ON bp.bp_row_id = brp.bp_row_id where osi.other_system_id = '$cmr' and osi.other_system_name='$flag' for read only";

	my $ref;
	my $tmp=",,,,,UNKNOWN BP:$cmr|$flag";
      my $sth = $dbh->prepare($sql);
      $sth->execute;
      while ($ref = $sth->fetchrow_arrayref) {
            if(defined($ref) )  {
                if( ( !defined($ref->[0]) ) || ($ref->[0] eq "") ) { $ref->[0] = "-"; } #ceid
                if( ( !defined($ref->[1]) ) || ($ref->[1] eq "") ) { $ref->[1] = "-"; } # legal name
                if( ( !defined($ref->[2]) ) || ($ref->[2] eq "") ) { $ref->[2] = "-"; } # country
                if( ( !defined($ref->[3]) ) || ($ref->[3] eq "") ) { $ref->[3] = "-"; } # test flag
                if( ( !defined($ref->[4]) ) || ($ref->[4] eq "") ) { $ref->[4] = "-"; } # frequency
                $tmp = "$ref->[0]" . "," .  trim(replaceCommas($ref->[1]))  . "," . "$ref->[2]" . "," . "$ref->[3]" . "," . "$ref->[4]";
		last;
           }
      }
	
return $tmp;
}

sub replaceCommas {
        my $str = $_[0];
        $str =~ s/,/ /g;
        $str =~ s/\'/ /g;
        return $str;
}
sub rightPadCMR {
        my $str = $_[0];
 	my $pad_char = " ";
        my $pad_len = 15;  # CMR=10 or more up to 15 with or without spaces
        $str=trim($str);
        my $padded = $str . $pad_char x ( $pad_len - length( $str ) );
return $padded;

}
sub leftPadCMRZeros {
        my $str = $_[0];
        my $pad_char = "0";
        my $pad_len = 10;  # CMR=10
        $str=trim($str);
        my $padded = ($pad_char x ( $pad_len - length( $str ) )) . $str;
return $padded;

}

sub readOutputFile {
	my $PATH  = $_[0];
	my $str  = $_[1];
print "readOutputFile() PATH=$PATH and str=$str\n";
	my $bpTransId;
	#open file based on $str
	$str = $PATH . "/" . "$str"; 
	#print "readOutputFile()open [$str]  ";
	open(RES,$str) or die "   cannot open  [$str]    $!" ;
	$bpTransId=<RES>;
                      #while(<RES>) {
                      #         $bpTransId=$_;
		#	last;
       		#	}         
	#print "readOutputFile() read $str got  [$bpTransId]  ";
       close(RES) or warn "cannot close  $str  $!";
	return "$bpTransId";	
}
## IF THERE IS A BRANCH ( 5 chars or less ) append it to the CMR
 # FORMAT the CMR which will include the underscore and/or branch
sub formatCMR_BRANCH {
	my $branch=$_[0];
	my $r_BRANCH_flag=$_[1];
	my $cmr=$_[2];
         if($branch) {   
                 $$r_BRANCH_flag="BRANCH";
                 $cmr=trim($cmr);
                 $branch=trim($branch);
                 $cmr=$cmr . $branch;
                # print " After concat with branch  |$branch| CMR is |$CMR|    ";
                 $cmr=formatSCMR($cmr);
         }
         else {
                 $cmr=formatSCMR($cmr);
                 $$r_BRANCH_flag="CMR";
         }
return $cmr;
}
sub format_dbCMR {
	my $r_BRANCH_flag=$_[0];
	my $cmr=$_[1];
	my $dbCMR;
	if($$r_BRANCH_flag eq "CMR") {
                $dbCMR=substr($cmr,0,10);
        }
        else {  # BRANCH may have underscores - get the substr()
                my $ind=index($cmr,"_");
                if($ind != -1) { $dbCMR=substr($cmr,0,$ind ); }
                else { $dbCMR=$cmr; }
        }
return $dbCMR;
}
sub createWeeklyName {
	my $dbCMR=$_[0];
	my $r_startdate=$_[1];
	my $r_enddate=$_[2];
	my $CMR;

		my $cmr=rightPadCMR($dbCMR); # pad to 15
                my $arg1= "${cmr}${STARTDATE}${ENDDATE}";
                my $arg2= $prevSODATE;
		####################
                my $PATH_JAVA_OUTPUT= "/var/mqsi/rp/TOOLS" . "/" . "$JAVA_OUTPUT";
		####################

                system(">$PATH_JAVA_OUTPUT");
                	#unlink $PATH_JAVA_OUTPUT if -e $PATH_JAVA_OUTPUT;

                #print "WEEKLY info:EXECUTE bp_transmission_corrector_run.sh $arg1 $arg2";
                system("$PROGRAM_PATH/bp_transmission_corrector_run.sh \"$arg1\"  $arg2");

#OOPS on this one due to hard coding in java:have to put in path:
		# read from file to get modified bp transmission id and use this for PTS compare ie, CMR, STARTDATE, ENDDATEarg1, $arg2;
                #my $result =  readOutputFile("/home/mqbrkr/daily_status",$JAVA_OUTPUT); 
		####################
                my $result =  readOutputFile("/var/mqsi/rp/TOOLS",$JAVA_OUTPUT); 
		####################
                $CMR=substr($result,0,15);
                $$r_startdate=substr($result,15,10);
                $$r_enddate=substr($result,25,10);
                $CMR=formatSCMR($CMR);  # add underscores back
                #print "DEBUG:WEEKLY file got result=[$result]   ";
return $CMR;
}

# Will find the ptsfile file name - latest
sub findPTSFile {
	my $expected=$_[0];
	my $r_file_lines=$_[1];
	my @fileListArrPTS = glob("*$expected");
	my $PTS_FILE_NAME;

                #expecting 90% of the time having an array of one
			
                if( @fileListArrPTS ) {
                        my $pts_file =  pop(@fileListArrPTS) ;
                                if( defined($pts_file)) {
                                        open(PTS,$pts_file) or warn "cannot open PTS $pts_file    $!" and next;
                                        while(<PTS>) {
                                                if ($_  =~ /^\*(\d+)/ )  {
                                                        $$r_file_lines=$1;
                                                }
                                        }
                                        close(PTS) or warn "cannot close PTS $pts_file  $!";
                                        $PTS_FILE_NAME = $pts_file;
                                }
                                else {
                                        $PTS_FILE_NAME = "undefined";
                                        $$r_file_lines = "NA";
                                }
                        
                } # #END IF THERE IS AN ARRAY (There is at least one PTS )WITH ELEMENTS
                else {
                        $PTS_FILE_NAME = "NO PTS FILE:expected $expected";
                        $$r_file_lines = 'NA';

                }
return $PTS_FILE_NAME
}

