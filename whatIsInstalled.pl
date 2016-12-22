#!/user/bin/perl

use ExtUtils::Installed;
my $Inst = ExtUtils::Installed->new();
my @Modules = $Inst->modules();
print "Current List of Installed PERL Modules:\n\n";
	foreach my $mod(@Modules){
	print "$mod\n";
	}
