#!/usr/bin/perl

use strict;
use IO::File;
use Data::Dumper;

use  DBI;
use DBD::mysql;

my $tablename = "";
my $config_file="MySQL.conf";
my $csv_file="/home/gary/log/mysql.csv";
unlink $csv_file;
##############
# Query
my $query = "SELECT * from employee LIMIT 50";
##############

my $CSV = IO::File->new("$csv_file",">>") or die "\nError: Can't open $csv_file. $! \n\n";


my %config;

&initialize($config_file);
print "$0: initialization complete\n";
my $host=$config{host};
my $database=$config{database};
my $user=$config{user};
my $pw=$config{pw};
my $port=$config{port};

#DATA SOURCE NAME
my $dsn = "dbi:mysql:$database:$host:$port";

# PERL DBI CONNECT
my $dbstore = DBI->connect($dsn, $user, $pw) or die "Unable to connect: $DBI::errstr\n";
print "$0: connection complete\n";

# PREPARE THE QUERY
my $sth = $dbstore->prepare($query);
	$sth->execute();

# 5) fetchrow_hashref
print "fetching into hash ref and printing results: \n";
while ( my $hash_ref=$sth->fetchrow_hashref() ) {
	printf("%s,%s,%s,%s,\n", $hash_ref->{id}, $hash_ref->{first_name}, $hash_ref->{last_name}, $hash_ref->{email} );
	print $CSV "$hash_ref->{id}, $hash_ref->{first_name}, $hash_ref->{last_name}, $hash_ref->{email})\n";	
}
  $sth->finish();
$CSV->close();
sub initialize() {
	my $conf=shift;
	my $CONFIG = IO::File->new("$conf","<") or die "\nError: Can't open $conf. $! \n\n";

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
}

##########################
## Other database options
##########################

#  1)
# BIND TABLE COLUMNS TO VARIABLES
####$sth->bind_columns(undef, \$id, \$product, \$quantity);
# LOOP THROUGH RESULTS
###while($query_handle->fetch()) {
  ## print "$id, $product, $quantity <br />";
#} 
#id first_name last_name email gender birth_date personal_code insert_dt insert_user_id insert_process_code update_dt update_user_id update_process_code deleted_flag

# 2) simply get all
#$sth->dump_results() ;

# 3) fetchrow_array
#while(my @row = $sth->fetchrow_array()){
#     printf("%s\t%s\n",$row[0],$row[1]);
#  }       

# 4) fetchrow)arrayref
#while(my $array_ref = $sth->fetchrow_arrayref()){
 #  printf("%s\t%s\t%s\t%s\n", $array_ref->[0],
 #                            $array_ref->[1],
