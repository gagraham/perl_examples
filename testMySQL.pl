#!/usr/bin/perl

use strict;
use  DBI;
use DBD::mysql;

# DBI CONFIG VARIABLES
my $host = "localhost";
my $database = "sample_staff";
my $tablename = "";
my $user = "root";
my $pw = "zebra";

#DATA SOURCE NAME
my $dsn = "dbi:mysql:$database:localhost:3306";

# PERL DBI CONNECT
my $dbstore = DBI->connect($dsn, $user, $pw) or die "Unable to connect: $DBI::errstr\n";
# PREPARE THE QUERY
my $query = "SELECT * from employee LIMIT 5";
my $sth = $dbstore->prepare($query);
	$sth->execute();

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
 #                            $array_ref->[2],
 #                            $array_ref->[3]);
 # }

# 5) fetchrow_hashref
while ( my $hash_ref=$sth->fetchrow_hashref() ) {
	printf("%s\t%s\t%s\t%s\n", $hash_ref->{id}, $hash_ref->{first_name}, $hash_ref->{last_name}, $hash_ref->{email} );
}
  $sth->finish();

