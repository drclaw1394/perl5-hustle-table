use strict;
use warnings;

use Hustle::Table;
use Test::More;
plan tests=>5;

my $table=Hustle::Table->new;


my %cache;

my %hit;
my $capture;

$table->add(
	{matcher=>"B", type=>"begin",	value=>"Entry2"},
	{matcher=>qr/^A/, 		value=>"Entry1"},
);

my $dispatcher=$table->prepare_dispatcher(cache=>\%cache);

my ($value)=$dispatcher->("A");

ok keys %cache==1 , "Cache Entry added";
ok $value->[1] eq "Entry1", "Correct value";

%cache=();

ok ((keys(%cache)==0), "Cache Entry removed");

$dispatcher->("A");

my ($value)=$dispatcher->("A");

ok keys %cache==1 , "Cache Entry added";
ok $value->[1] eq "Entry1", "Correct value";
