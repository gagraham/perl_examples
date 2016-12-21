#!/user/bin/perl
use strict;
use File::Copy;
my $latest="test1.txt";
my $targetDIR="TEST";

 copy($latest,$targetDIR) ==1 or warn " Copy failed! $!\n\n";

