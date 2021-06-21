use strict;
use warnings;

use ExtUtils::MakeMaker;
#use File::ShareDir::Install;

#install_share dist=>"benchmark";

WriteMakefile(
	NAME => 'Hustle::Table',
	ABSTRACT_FROM => 'lib/Hustle/Table.pod', 
	VERSION_FROM => 'lib/Hustle/Table.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
	MIN_PERL_VERSION => '5.22.0',		#for switch and ref aliasing
	PREREQ_PM => {}, # e.g., Module::Name => 1.1
	AUTHOR => 'Ruben Westerberg <drclaw@mac.com>',
	LICENSE => 'mit'




	#Value must be from legacy list of licenses here
	#http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);


#package
#MY;
#use File::ShareDir::Install qw<postamble>;
