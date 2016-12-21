#! /usr/bin/perl
#--------------------------------------------------------------------------------------------------------------------
# Name:          archive_files.pl
#
# Programmer(s): perlwarrior
#
# Date:          08/31/2011
#
#
#
# Purpose: Program to archive the specified file types to the target directory. 
#
# Run format: archive_files.pl
#                  
#
# Modifications:
#       08/31/2012 - perlwarrior - Initial Creation for Liquid Event 63839.
#       09/04/2012 - perlwarrior - Modified to Tar the files without the source path.
#		09/07/2012 - perlwarrior - Modified to move the files from source directory rather than copy.
#								   - Fixed the script to handle multiple dates on same filename.		
#       10/15/2012 - gagraham - added e2Open4E1DAYSAGO,32Open4E1DIR_SRC, new basename 
#       		        add internal ARRAYS: @filedates_e2Open4E1,@e2Open4E1files,for e2Open4E1 directory, and @tarlist_e2Open4E1
#       		        'e2Open4E1'=>\@filedates_e2Open4E1, 'e2Open4E1'=>\@e2Open4E1files 
#       		        and RE 		$file =~ /^4E1(\d{1,8}).*_PROD\.xml/)    for 4E120121015153806531_PROD.xml 
#       		        Add new elsifs to support new arrays
#       06/22/2013 - perlwarrior - Modified to split DIHData to separate tars based on chunk_size 
#								 - liquid event 82823	
# STEPS-start with "basename" for example latest "eacmSeo"
# 1)config 2)usage print 3)rp/ARCHIVE/subdir=basename so create it4)add  @<basename>files 5)add @filedates_<basename> 6) add $tarlist_<basename>
# 7)add declarations
#--------------------------------------------------------------------------------------------------------------------

use strict;
use POSIX 'strftime';
use Time::Local;
use IO::File;
use File::Find;
use File::Copy;

my (%config,%basename_files,%basename_dates);
my $date;
my (@basenames,@OIMDatafiles,@DIHDatafiles,@WWBPSMRelDiscountfiles,@WWBPSMFixedPricefiles,@PTSfiles,@GXSSalfiles,@GXSInvfiles,@e2OpenSalfiles,@e2OpenInvfiles,@e2Open4E1files,@eacmSeofiles,@eacmPricefiles);
my (@filedates_OIMData,@filedates_DIHData,@filedates_WWBPSMRelDiscount,@filedates_WWBPSMFixedPrice,@filedates_PTS,@filedates_GXSSal,@filedates_GXSInv,@filedates_e2OpenSal,@filedates_e2OpenInv,@filedates_e2Open4E1,@filedates_eacmSeo,@filedates_eacmPrice);

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
&search_files;
&create_archive; 
&print_summary;

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub usage {
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# displays how to use the tool
#----------------------------------------------------------------------------
    print "\n ***************************USAGE*******************************************";
	print "\n archive_files.pl archives the specified file types to the target directory. "; 
    print "\n The tool reads the config_file to identify the source and target directories. ";
    print "\n Execution will be terminated in case any of the source directories is missing. A sample config file is displayed below \n";
	print "\n\n #archive_files.config#";
	print "\n 	basenames=OIMData,DIHData,WWBPSMRelDiscount,WWBPSMFixedPrice,PTS,GXSSal,GXSInv,e2OpenSal,e2OpenInv,eacmSeo";
	print "\n	archiveDir=/var/mqsi/rp/ARCHIVE";
	print "\n	#[OIMData]";
	print "\n	OIMDataDIR_SRC=/var/mqsi/rp/oimfiles/xml/mqsiarchive";
	print "\n	OIMDataDAYS_AGO=90";
	print "\n	#DIH";
	print "\n	DIHDataDIR_SRC=/var/mqsi/rp/log/DIH";   
	print "\n	DIHDataDAYS_AGO=90";
	print "\n	DIH_CHUNK_SIZE=1000";
	print "\n	#WWBPSMRelDiscount";
	print "\n	WWBPSMRelDiscountDIR_SRC=/var/mqsi/rp/log/";
	print "\n	WWBPSMRelDiscountDAYS_AGO=90";
	print "\n	#WWBPSMFixedPrice";
	print "\n	WWBPSMFixedPriceDIR_SRC=/var/mqsi/rp/log";
	print "\n	WWBPSMFixedPriceDAYS_AGO=180";
	print "\n	#PTS";
	print "\n	PTSDIR_SRC=/var/mqsi/rp/ptsfiles/mqsiarchive";
	print "\n	PTSDAYS_AGO=90";
	print "\n	#GXSSal";
	print "\n	GXSSalDIR_SRC=/var/mqsi/rp/GXSSal/mqsiarchive";
	print "\n	GXSSalDAYS_AGO=180";
	print "\n	#GXSInv";
	print "\n	GXSInvDIR_SRC=/var/mqsi/rp/GXSInv/mqsiarchive";
	print "\n	GXSInvDAYS_AGO=180";
	print "\n	#e2OpenSal";
	print "\n	e2OpenSalDIR_SRC=/var/mqsi/rp/e2OpenSal/mqsiarchive";
	print "\n	e2OpenSalDAYS_AGO=180";
	print "\n	#e2OpenInv";
	print "\n	e2OpenInvDIR_SRC=/var/mqsi/rp/e2OpenInv/mqsiarchive";
	print "\n	e2OpenInvDAYS_AGO=180\n\n";
	print "\n	e2Open4E1DIR_SRC=/var/mqsi/rp/e2Open4E1/mqsiarchive";
	print "\n	e2Open4E1DAYS_AGO=180\n\n";
	print "\n	eacmSeoDIR_SRC=/var/mqsi/rp/eacm/seo/mqsiarchive";
	print "\n	eacmSeoDAYS_AGO=1\n\n";
	print "\n	eacmPriceDIR_SRC=/var/mqsi/rp/eacm/price/mqsiarchive";
	print "\n	eacmPriceDAYS_AGO=1\n\n";
    print "\n ***************************************************************************\n";
	exit 1;
    
}  # end subroutine


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub initialize{
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# Initialize the variables
#----------------------------------------------------------------------------
$date = strftime '%Y%m%d', localtime;
my $config_file="/home/mqbrkr/daily_status/archive_files.config";
#my $config_file="/home/wbiadmn/EVENT82823/archive_files.config";
my $CONFIG = IO::File->new("$config_file","<") or die "\nError: Can't open $config_file. $! \n\n";

%basename_files=('OIMData'=>\@OIMDatafiles,
					'DIHData'=>\@DIHDatafiles,
					'WWBPSMRelDiscount'=>\@WWBPSMRelDiscountfiles,
					'WWBPSMFixedPrice'=>\@WWBPSMFixedPricefiles,
					'PTS'=>\@PTSfiles,
					'GXSSal'=>\@GXSSalfiles,
					'GXSInv'=>\@GXSInvfiles,
					'e2OpenSal'=>\@e2OpenSalfiles,
					'e2OpenInv'=>\@e2OpenInvfiles,
					'e2Open4E1'=>\@e2Open4E1files,
					'eacmSeo'=>\@eacmSeofiles,
					'eacmPrice'=>\@eacmPricefiles
					);	
					
%basename_dates=('OIMData'=>\@filedates_OIMData,
					'DIHData'=>\@filedates_DIHData,
					'WWBPSMRelDiscount'=>\@filedates_WWBPSMRelDiscount,
					'WWBPSMFixedPrice'=>\@filedates_WWBPSMFixedPrice,
					'PTS'=>\@filedates_PTS,
					'GXSSal'=>\@filedates_GXSSal,
					'GXSInv'=>\@filedates_GXSInv,
					'e2OpenSal'=>\@filedates_e2OpenSal,
					'e2OpenInv'=>\@filedates_e2OpenInv,
					'e2Open4E1'=>\@filedates_e2Open4E1,
					'eacmSeo'=>\@filedates_eacmSeo,
					'eacmPrice'=>\@filedates_eacmPrice)
					
					;
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
# Search for files in each source directory
#----------------------------------------------------------------------------
@basenames=split (",",$config{basenames});
foreach my $basename (@basenames) {
	my $src=$basename."DIR_SRC";
	print "\nINFO:Searching for files of type $basename in $config{$src}\n";
	if ( ! -d "$config{$src}" ) {
		print "\nError : SRC_DIR \"$config{$src}\" not found for $basename\n";
		exit 2;
	}
	find (\&prepare_list, "$config{$src}");
	
}

}


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub prepare_list{
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#----------------------------------------------------------------------------
# Prepare the list of to be bundled and get the files copied
#----------------------------------------------------------------------------
	my $file=$_;
	my ($file_date,$file_age);
	foreach my $basename (@basenames) {
		if ( ! -d "$config{archiveDir}/$basename" ) {
			print "\nInfo: $config{archiveDir}/$basename does not exist. Creating\n";
			system("mkdir -p $config{archiveDir}/$basename");
		}
	}
	if (($file =~ /^OIMData(\d{1,8}).*/) or ($file =~ /^mmlc_pnh-(\d{1,8})\.xml/)){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{OIMDataDAYS_AGO} ) {
			push (@filedates_OIMData,$file_date) if( ! grep /$file_date/,@filedates_OIMData);
			push (@OIMDatafiles,$file) if( ! grep /$file/,@OIMDatafiles);
			move ("$File::Find::name","$config{archiveDir}/OIMData/$file") == 1 or die "\nError: $file move failed: $!";
		}	
	}
	elsif ($file =~ /^DIHData(\d{1,8}).*\.xml/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{DIHDataDAYS_AGO} ) {
			push (@filedates_DIHData,$file_date) if( ! grep /$file_date/,@filedates_DIHData);
			push (@DIHDatafiles,$file) if( ! grep /$file/,@DIHDatafiles);
			move ("$File::Find::name","$config{archiveDir}/DIHData/$file") == 1 or die "\nError: $file move failed: $!";
			
		}	
	}
	elsif ($file =~ /^WWBPSMRelDiscount-.*\.csv/){
		my $mtime = (stat($file))[9];
		my $current_time = time;
		$file_age= ($current_time - $mtime) / 86400;   #Days since the file has been modified
		$file_date= strftime '%Y%m%d', localtime((stat($file))[9]);
		#check if date is expired
		if ( $file_age > $config{WWBPSMRelDiscountDAYS_AGO} ) {
			push (@filedates_WWBPSMRelDiscount,$file_date) if( ! grep /$file_date/,@filedates_WWBPSMRelDiscount);
			push (@WWBPSMRelDiscountfiles,$file) if( ! grep /$file/,@WWBPSMRelDiscountfiles);
			#move ("$File::Find::name","$config{archiveDir}/WWBPSMRelDiscount/$file") == 1 or die "\nError: $file move failed: $!";
                        system("mv -f $File::Find::name $config{archiveDir}/WWBPSMRelDiscount2/$file") == 0 or warn "\nError: $file move failed: $!";

		}	
	}
	elsif ($file =~ /^WWBPSMFixedPrice-.*\.csv/){
		my $mtime = (stat($file))[9];
		my $current_time = time;
		$file_age= ($current_time - $mtime) / 86400;   #Days since the file has been modified
		$file_date= strftime '%Y%m%d', localtime((stat($file))[9]);
		#check if date is expired
		if ( $file_age > $config{WWBPSMFixedPriceDAYS_AGO} ) {
			push (@filedates_WWBPSMFixedPrice,$file_date) if( ! grep /$file_date/,@filedates_WWBPSMFixedPrice);
			push (@WWBPSMFixedPricefiles,$file) if( ! grep /$file/,@WWBPSMFixedPricefiles);
			#move ("$File::Find::name","$config{archiveDir}/WWBPSMFixedPrice/$file") == 1 or die "\nError: $file move failed: $!";
			system("mv -f $File::Find::name $config{archiveDir}/WWBPSMFixedPrice2/$file") == 0 or warn "\nError: $file move failed: $!";

		}	
	} 
	elsif ($file =~ /^(\d{1,8}).*_.*_SLSRPT.*\.txt/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{GXSSalDAYS_AGO} ) {
			push (@filedates_GXSSal,$file_date) if( ! grep /$file_date/,@filedates_GXSSal);
			push (@GXSSalfiles,$file) if( ! grep /$file/,@GXSSalfiles) ;
			move ("$File::Find::name","$config{archiveDir}/GXSSal/$file") == 1 or die "\nError: $file move failed: $!";
		}	
	}
	elsif ($file =~ /^(\d{1,8}).*_.*_INVRPT.*\.txt/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{GXSInvDAYS_AGO} ) {
			push (@filedates_GXSInv,$file_date) if( ! grep /$file_date/,@filedates_GXSInv);
			push (@GXSInvfiles,$file)  if( ! grep /$file/,@GXSInvfiles) ;
			move ("$File::Find::name","$config{archiveDir}/GXSInv/$file") == 1 or die "\nError: $file move failed: $!";
			
		}	
	}
	elsif ($file =~ /^(\d{1,8}).*_.*_Sal.*\.txt/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{e2OpenSalDAYS_AGO} ) {
			push (@filedates_e2OpenSal,$file_date) if( ! grep /$file_date/,@filedates_e2OpenSal);
			push (@e2OpenSalfiles,$file)  if( ! grep /$file/,@e2OpenSalfiles) ;
			move ("$File::Find::name","$config{archiveDir}/e2OpenSal/$file") == 1 or die "\nError: $file move failed: $!";	
		}	
	}
	elsif ($file =~ /^(\d{1,8}).*_.*_Inv.*\.txt/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{e2OpenInvDAYS_AGO} ) {
			push (@filedates_e2OpenInv,$file_date) if( ! grep /$file_date/,@filedates_e2OpenInv);
			push (@e2OpenInvfiles,$file)  if( ! grep /$file/,@e2OpenInvfiles);
			move ("$File::Find::name","$config{archiveDir}/e2OpenInv/$file") == 1 or die "\nError: $file move failed: $!";	
		}	
	}
	elsif (($file =~ /^(\d{1,8}).*_.*_GXS.*I.*\.txt/) or ($file =~ /^(\d{1,8}).*_.*_GXS.*S.*\.txt/) or ($file =~ /^(\d{1,8}).*_.*_E2O.*I.*\.txt/) or ($file =~ /^(\d{1,8}).*_.*_E2O.*S.*\.txt/) ){
		$file_date=$1;
		#print "date=$date and $file_date = file_date\n";
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{PTSDAYS_AGO} ) {
			push (@filedates_PTS,$file_date) if( ! grep /$file_date/,@filedates_PTS);
			push (@PTSfiles,$file) if( ! grep /$file/,@PTSfiles);
			move ("$File::Find::name","$config{archiveDir}/PTS/$file") == 1 or die "\nError: $file move failed: $!";
		}	
	}	
	elsif ($file =~ /^4E1(\d{1,8}).*_PROD\.xml/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{e2Open4E1DAYS_AGO} ) {
			push (@filedates_e2Open4E1,$file_date) if( ! grep /$file_date/,@filedates_e2Open4E1);
			push (@e2Open4E1files,$file)  if( ! grep /$file/,@e2Open4E1files) ;
			move ("$File::Find::name","$config{archiveDir}/e2Open4E1/$file") == 1 or die "\nError: $file move failed: $!";	
		}	
	}
	elsif ($file =~ /^(\d{1,8}).*_SEO_UPDATE.*\.xml/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{eacmSeoDAYS_AGO} ) {
			push (@filedates_eacmSeo,$file_date) if( ! grep /$file_date/,@filedates_eacmSeo);
			push (@eacmSeofiles,$file)  if( ! grep /$file/,@eacmSeofiles) ;
			move ("$File::Find::name","$config{archiveDir}/eacmSeo/$file") == 1 or die "\nError: $file move failed: $!";	
			#print "Array filedates=" . "$filedates_eacmSeo[0]";
		}	
	}
	elsif ($file =~ /^(\d{1,8}).*_PRICE_UPDATE.*\.xml/){
		$file_date=$1;
		$file_age=&day_diff("$date","$file_date");
		#check if date is expired
		if ( $file_age > $config{eacmPriceDAYS_AGO} ) {
			push (@filedates_eacmPrice,$file_date) if( ! grep /$file_date/,@filedates_eacmPrice);
			push (@eacmPricefiles,$file)  if( ! grep /$file/,@eacmPricefiles) ;
			move ("$File::Find::name","$config{archiveDir}/eacmPrice/$file") == 1 or die "\nError: $file move failed: $!";	
			#print "Array filedates=" . "$filedates_eacmPrice[0]";
		}	
	}
}

sub day_diff {
#----------------------------------------------------------------------------
# Determine the number of days between two dates in YYYYMMDD format
#---------------------------------------------------------------------------- 
  
 
  my $year;
  my $month;
  my $day;
  my $time1;
  my $time2;
 
  $year = substr($_[0], 0, 4);
  $month = substr($_[0], 4, 2);
  $month = $month - 1;
  $day = substr($_[0], 6, 2);
  $time1 = timelocal(0, 0, 0, "$day", "$month", "$year");  # Convert date to seconds from epoch
  $year = substr($_[1], 0, 4);
  $month = substr($_[1], 4, 2);
  $month = $month - 1;
  $day = substr($_[1], 6, 2);
  $time2 = timelocal(0, 0, 0, "$day", "$month", "$year") or warn "Something wrong $!";
  return abs($time1 - $time2) / 86400;
}

sub create_archive {
#----------------------------------------------------------------------------
# Create the bundle for each file set
#---------------------------------------------------------------------------- 
if ( ! -d "$config{archiveDir}" ) {
	print "\nError: Archive directory $config{archiveDir} not found\n";
	exit 2;
}
foreach my $basename (@basenames) {
	#print "INFO:basename=$basename\n";
	foreach my $date (@{$basename_dates{$basename}}) { 
	#print "INFO:date=$date\n";
		my (@tarlist_oim,@tarlist_mmlc);
		my (@tarlist_dihdata,@tarlist_gxssal,@tarlist_gxsinv,@tarlist_e2OpenSal,@tarlist_e2OpenInv,@tarlist_e2Open4E1);
		my (@tarlist_pts_gxs_i,@tarlist_pts_gxs_s,@tarlist_pts_e2o_i,@tarlist_pts_e2o_s,@tarlist_eacmSeo,@tarlist_eacmPrice);
		my (@tarlist_WWBPSMRelDiscount,@tarlist_WWBPSMFixedPrice);
		foreach my $file (@{$basename_files{$basename}}) {
			#print "file found for tar-ing is $file\n";
			#Tarlist for OIMData
			if( $file =~ /^OIMData$date.*\.xml/){
				push (@tarlist_oim,$file) ;
			}
			elsif( $file =~ /^mmlc_pnh-$date\.xml/){
				push (@tarlist_mmlc,$file) ;
			} 
			#Tarlist for DIHData
			elsif( $file =~ /^DIHData$date.*\.xml/){
				push (@tarlist_dihdata,$file) ;
			}			
			#Tarlist for GXSSal
			elsif( $file =~ /^$date.*_.*_SLSRPT.*\.txt/){
				push (@tarlist_gxssal,$file) ;
			}	
			#Tarlist for GXSInv
			elsif( $file =~ /^$date.*_.*_INVRPT.*\.txt/){   
				push (@tarlist_gxsinv,$file) ;
			}	
			#Tarlist for e2OpenSal
			elsif( $file =~ /^$date.*_.*_Sal.*\.txt/){ 
				push (@tarlist_e2OpenSal,$file) ;
			}	
			#Tarlist for e2OpenInv
			elsif( $file =~ /^$date.*_.*_Inv.*\.txt/){  
				push (@tarlist_e2OpenInv,$file) ;
			}	
			#Tarlist fo e2Open4E1  2012-10-15
			elsif( $file =~ /^4E1$date.*_PROD\.xml/){  
				push (@tarlist_e2Open4E1,$file) ;
			}	

			#Tarlist for PTS
			elsif( $file =~ /^$date.*_.*_GXS.*I.*\.txt/){  
				push (@tarlist_pts_gxs_i,$file) ;
			}	
			elsif( $file =~ /^$date.*_.*_GXS.*S.*\.txt/){  
				push (@tarlist_pts_gxs_s,$file) ;
			}	
			elsif( $file =~ /^$date.*_.*_E2O.*I.*\.txt/){  
				push (@tarlist_pts_e2o_i,$file) ;
			}	
			elsif( $file =~ /^$date.*_.*_E2O.*S.*\.txt/){  
				push (@tarlist_pts_e2o_s,$file) ;
			}
			#Tarlist for WWBPSMRelDiscountfiles 
			elsif( $file =~ /^WWBPSMRelDiscount-.*\.csv/){  
				my $file_date= strftime '%Y%m%d', localtime((stat("$config{archiveDir}/WWBPSMRelDiscount2/$file"))[9]);
				
				if ( $file_date == $date){
					push (@tarlist_WWBPSMRelDiscount,$file) ;
				}
			}
			#Tarlist for WWBPSMFixedPricefiles			
			elsif( $file =~ /^WWBPSMFixedPrice-.*\.csv/){  
				my $file_date= strftime '%Y%m%d', localtime((stat("$config{archiveDir}/WWBPSMFixedPrice2/$file"))[9]);
				if ( $file_date == $date){
					push (@tarlist_WWBPSMFixedPrice,$file) ;
				}
			}				
			#Tarlist fo eacmSeo  2013-10-28   20131027_081308_497022_SEO_UPDATE_20131027081305304.xml
                        elsif( $file =~ /^$date.*_SEO_UPDATE.*\.xml/){
                                push (@tarlist_eacmSeo,$file) ;
                        }
			#Tarlist fo eacmPrice  2013-10-28   20131027_081308_497022_PRICE_UPDATE_20131027081305304.xml
                        elsif( $file =~ /^$date.*_PRICE_UPDATE.*\.xml/){
                                push (@tarlist_eacmPrice,$file) ;
                        }

		}
		if(@tarlist_oim) {
			my $tarname=$config{archiveDir}."/OIMData/OIMData".$date.".tar.gz"; 
			chdir("$config{archiveDir}/OIMData/");
			print "\nInfo: Creating archive for OIMData for date $date\n";
			system("tar -czvf $tarname @tarlist_oim ") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_oim;
		}
		if(@tarlist_mmlc) {
			my $tarname=$config{archiveDir}."/OIMData/mmlc_pnh".$date.".tar.gz";
			chdir("$config{archiveDir}/OIMData/");
			print "\nInfo: Creating mmlc archive for OIMData for date $date\n";
			system("tar -czvf $tarname @tarlist_mmlc") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_mmlc;
		}
		if(@tarlist_dihdata) {
			my $total_files = scalar @tarlist_dihdata;
			my $chunk_set;
			if ( exists $config{DIH_CHUNK_SIZE}) {
				$chunk_set = $total_files/$config{DIH_CHUNK_SIZE}; # To decide how many sets of tars to be created
				if ($chunk_set < 1) {   # Setting chunk sets to 1 , if less than 1
					$chunk_set = 1;
				}
			} else {
				$chunk_set = 1;
				$config{DIH_CHUNK_SIZE} = $total_files;   # setting the chunk size to array size
			}
			my $tarname = $config{archiveDir}."/DIHData/DIHData".$date;
			chdir("$config{archiveDir}/DIHData/");
			print "\nInfo: Creating archives for DIH for date $date\n";
			&process_chunks($total_files,$chunk_set,$config{DIH_CHUNK_SIZE},$tarname,\@tarlist_dihdata);
			unlink @tarlist_dihdata;
		}			
		if(@tarlist_gxssal) {
			my $tarname=$config{archiveDir}."/GXSSal/GXSSal".$date.".tar.gz"; 
			chdir("$config{archiveDir}/GXSSal/");
			print "\nInfo: Creating archive for GXSSal for date $date\n";
			system("tar -czvf $tarname @tarlist_gxssal") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_gxssal;
		}
		if(@tarlist_gxsinv) {
			my $tarname=$config{archiveDir}."/GXSInv/GXSInv".$date.".tar.gz"; 
			chdir("$config{archiveDir}/GXSInv/");
			print "\nInfo: Creating archive for GXSInv for date $date\n";
			system("tar -czvf $tarname @tarlist_gxsinv") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_gxsinv;
		}
		if(@tarlist_e2OpenSal) {
			my $tarname=$config{archiveDir}."/e2OpenSal/e2OpenSal".$date.".tar.gz"; 
			chdir("$config{archiveDir}/e2OpenSal/");
			print "\nInfo: Creating archive for e2OpenSal for date $date\n";
			system("tar -czvf $tarname @tarlist_e2OpenSal") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_e2OpenSal;
		}
		if(@tarlist_e2OpenInv) {
			my $tarname=$config{archiveDir}."/e2OpenInv/e2OpenInv".$date.".tar.gz"; 
			chdir("$config{archiveDir}/e2OpenInv/");
			print "\nInfo: Creating archive for e2OpenInv for date $date\n";    
			system("tar -czvf $tarname @tarlist_e2OpenInv") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_e2OpenInv;
		}
		if(@tarlist_e2Open4E1) {
			my $tarname=$config{archiveDir}."/e2Open4E1/e2Open4E1".$date.".tar.gz"; 
			chdir("$config{archiveDir}/e2Open4E1/");
			print "\nInfo: Creating archive for e2Open4E1 for date $date\n";    
			system("tar -czvf $tarname @tarlist_e2Open4E1") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_e2Open4E1;
		}
		if(@tarlist_pts_gxs_i) {
			my $tarname=$config{archiveDir}."/PTS/PTS_GXS_I_".$date.".tar.gz"; 
			chdir("$config{archiveDir}/PTS/");
			print "\nInfo: Creating GXS_I archive for PTS for date $date\n";    
			system("tar -czvf $tarname @tarlist_pts_gxs_i") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_pts_gxs_i;
		}
		if(@tarlist_pts_gxs_s) {
			my $tarname=$config{archiveDir}."/PTS/PTS_GXS_S_".$date.".tar.gz"; 
			chdir("$config{archiveDir}/PTS/");
			print "\nInfo: Creating GXS_S archive for PTS for date $date\n";  
			system("tar -czvf $tarname @tarlist_pts_gxs_s") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_pts_gxs_s;
		}		
		if(@tarlist_pts_e2o_i) {
			my $tarname=$config{archiveDir}."/PTS/PTS_E2O_I_".$date.".tar.gz"; 
			chdir("$config{archiveDir}/PTS/");
			print "\nInfo: Creating E2O_I archive for PTS for date $date\n";  
			system("tar -czvf $tarname @tarlist_pts_e2o_i") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_pts_e2o_i;
		}
		if(@tarlist_pts_e2o_s) {
			my $tarname=$config{archiveDir}."/PTS/PTS_E2O_S_".$date.".tar.gz"; 
			chdir("$config{archiveDir}/PTS/");
			print "\nInfo: Creating E2O_S archive for PTS for date $date\n";  
			system("tar -czvf $tarname @tarlist_pts_e2o_s") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_pts_e2o_s;
		}
		
		if(@tarlist_WWBPSMRelDiscount) {
			my $tarname=$config{archiveDir}."/WWBPSMRelDiscount2/WWBPSMRelDiscount".$date.".tar.gz"; 
			chdir("$config{archiveDir}/WWBPSMRelDiscount2/");
			print "\nInfo: Creating archive for WWBPSMRelDiscount for date $date\n";  
			system("tar -czvf $tarname @tarlist_WWBPSMRelDiscount") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_WWBPSMRelDiscount;
		}
		if(@tarlist_WWBPSMFixedPrice) {
			my $tarname=$config{archiveDir}."/WWBPSMFixedPrice2/WWBPSMFixedPrice".$date.".tar.gz"; 
			chdir("$config{archiveDir}/WWBPSMFixedPrice2/");
			print "\nInfo: Creating archive for WWBPSMFixedPrice for date $date\n"; 
			system("tar -czvf $tarname @tarlist_WWBPSMFixedPrice") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_WWBPSMFixedPrice;
		}		
		if(@tarlist_eacmSeo) {
			my $tarname=$config{archiveDir}."/eacmSeo/SEO_UPDATE".$date.".tar.gz"; 
			chdir("$config{archiveDir}/eacmSeo/");
			print "\nInfo: Creating archive for eacmSeo for date $date\n"; 
			system("tar -czvf $tarname @tarlist_eacmSeo") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_eacmSeo;
		}		
		if(@tarlist_eacmPrice) {
			my $tarname=$config{archiveDir}."/eacmPrice/Price_UPDATE".$date.".tar.gz"; 
			chdir("$config{archiveDir}/eacmPrice/");
			print "\nInfo: Creating archive for eacmPrice for date $date\n"; 
			system("tar -czvf $tarname @tarlist_eacmPrice") == 0 or print "\nWarn: tar command failed: $!\n";
			unlink @tarlist_eacmPrice;
		}		

	}
}		
}

sub process_chunks {
  #----------------------------------------------------------------------------
  # Split the tar to separate chunks and create the archive
  #---------------------------------------------------------------------------- 
	my ($total_files,$chunk_set,$chunk_size,$tar,$fulltarlist) = @_;
	my $i = 1;
	my $start_index = 0;
	my $last_index;		
	if (!($chunk_size =~ /[0-9]+/)) {
		print "\nError: Chunk size has to be defined in numeric format";
		exit 1;
	}	

	while ($i <= $chunk_set) {
		$last_index = ($i * $chunk_size) - 1;
		my @tarlist = @$fulltarlist[$start_index..$last_index];   # Extract each chunk
		if ($chunk_size > $total_files) {     # Remove the blanks if any
			@tarlist = grep(!/^$/, @tarlist);
		}
		my $tarname=$tar."_".$i.".tar.gz"; 
		system("tar -czvf $tarname @tarlist") == 0 or print "\nWarn: tar command failed: $!\n";
		$start_index = $last_index + 1;   # for the next set
		$i++;
	}
	if (($total_files - ($last_index + 1)) > 0 ) {    #Extracting the extra set of files after the chunks
		
	
		my @tarlist = @$fulltarlist[$last_index + 1..$total_files];
		my $tarname=$tar."_".$i.".tar.gz"; 
		my $test = scalar @tarlist;
		system("tar -czvf $tarname @tarlist") == 0 or print "\nWarn: tar command failed: $!\n";
	}
	
}

sub print_summary {
#----------------------------------------------------------------------------
# Complete the execution by displaying the summary.
#----------------------------------------------------------------------------
print "\n\n\nNumber of files found for each basenames for the configured dates:";
print "\nOIMData: ";
print scalar(@OIMDatafiles);
print "\nDIHData: ";
print scalar(@DIHDatafiles);
print "\nWWBPSMRelDiscount: ";
print scalar(@WWBPSMRelDiscountfiles);
print "\nWWBPSMFixedPrice: ";
print scalar(@WWBPSMFixedPricefiles);
print "\nPTS: ";
print scalar(@PTSfiles);
print "\nGXSSal: ";
print scalar(@GXSSalfiles);
print "\nGXSInv: ";
print scalar(@GXSInvfiles);
print "\ne2OpenSal: ";
print scalar(@e2OpenSalfiles);
print "\ne2OpenInv: ";
print scalar(@e2OpenInvfiles);
print "\ne2Open4E1: ";
print scalar(@e2Open4E1files);
print "\neacmSeo: ";
print scalar(@eacmSeofiles);
print "\neacmPrice: ";
print scalar(@eacmPricefiles);
my $end_time = localtime(time);
print "\n\n\n *****************************************************" ;
print "\n End Time    : $end_time";
print "\n Process Info: $0 completed";
print "\n ***************************************************** \n" ;
exit();
}

