use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Benchmark;
use Data::Dumper;
use feature "say";


use Hustle::Table; 

my @hits;

my @list=(

        qr|^/another/regex(\d+)|oa=> sub {return},undef,undef,
        qr|^/regex(\d+)|oa=> sub {return},undef,undef,
	"/exact"=>sub {return}, undef,undef,

	"/another/exact"=>sub {return}, undef,undef,
	"/one/more/exact"=>sub {return}, undef,undef,

	""=>sub{return},"default", undef,
);

my @options=(
	{type=>"loop",cache=>undef,reorder=>undef},
	{type=>"loop",cache=>{},reorder=>undef},
	{type=>"loopauto",cache=>undef,reorder=>undef},
	{type=>"loopauto",cache=>{},reorder=>undef},
	{type=>"dynamic",cache=>undef,reorder=>undef},
	{type=>"dynamic",cache=>{},reorder=>undef},
);


my @dispatch;
my @tables;

for my $option (@options){
	my $table=Hustle::Table->new();
	push @tables, $table;	
	$table->add(@list);
	#$table->default( sub {});
	push @dispatch, $table->build(%$option);

}
my $count=10000;
use Math::Random;
my @uri=qw(
        /another/regexX
	/regexX
	/exact
	/another/exact
	/one/more/exact
	asd
	);

say "Building samples";
my @samples=map {$_=0 if $_<0; $_=$#uri if $_> $#uri; $uri[$_]=~ s/X+/int($_)/er} random_normal($count, @uri/2, 1);
sleep 1;
local $,=", ";
#say @samples;
#exit;
print "NO reordering\n";
for my $dispatch (@dispatch){
	timethis 200, sub {
		for my $sample (@samples){
			#say $sample;
			$dispatch->($sample);
		}
	};
}

@options=(
	{type=>"loop",cache=>undef,reorder=>1},
	{type=>"loop",cache=>{},reorder=>1},
	{type=>"loopauto",cache=>undef,reorder=>1},
	{type=>"loopauto",cache=>{},reorder=>1},
	{type=>"dynamic",cache=>undef,reorder=>1},
	{type=>"dynamic",cache=>{},reorder=>1},
);
print "YES reordering\n";
@dispatch=();
my $i=0;
for my $option (@options){
	my $table=$tables[$i];#Hustle::Table->new();
	
	push @dispatch, $table->build(%$option);
	$i++;

}
for my $dispatch (@dispatch){
	timethis 200, sub {
		for my $sample (@samples){
			$dispatch->($sample);
		}
	};
}







