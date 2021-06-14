# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Regex-Dispatcher.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use feature "refaliasing";
no warnings "experimental";

use Data::Dumper;
use feature "say";

use Test::More tests => 2;
BEGIN { use_ok('Regex::Dispatcher') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.
#


use feature ":all";


my %count;
my @table=(
	[qr/(this)/=> sub { 
			$count{this}++;
			say "matched this  ($1) and context is:", Dumper $_[0];1
		}],
	[qr/that/=> sub {
			$count{that}++;
			say "matched that ";1
		}],
	[qr/another/=> sub {
			$count{another}++;
			#say "matched that ($1)";1
		}],
	[qr/word/=> sub {
			$count{word}++;
			#say "matched that ($1)";1
		}],
);

my $dispatcher=Regex::Dispatcher->new();
ok($dispatcher);

for(@table){
	say $dispatcher->add($_->@*);
}


my $loop=$dispatcher->build(type=>"loop");

$loop->("this");
$loop->("that");
say Dumper $dispatcher;

$dispatcher->resetCounters;
say Dumper $dispatcher;
