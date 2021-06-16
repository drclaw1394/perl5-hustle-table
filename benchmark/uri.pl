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
        qr|^/absolute/url/to/service(\d+)|noa=> sub {},
        qr{^/static/resource/(image\.(?:jpg|png|))(\d+)}noa=>sub {},
        qr|^/absolute/url/to/product(\d+)|noa=> sub {},
        qr|^/absolute/url/to/other(\d+)|noa=> sub {},
        "/ws5"=> sub {},
);

my @options=(
	{type=>"loop",cache=>undef,reorder=>undef},
	{type=>"loop",cache=>{},reorder=>undef},
	{type=>"dynamic",cache=>undef,reorder=>undef},
	{type=>"dynamic",cache=>{},reorder=>undef},
);


my @dispatch;
my @tables;

for my $option (@options){
	my $table=Hustle::Table->new();
	push @tables, $table;	
	$table->add(@list);
	$table->default( sub {});
	push @dispatch, $table->build(%$option);
	#say Dumper $table;

}
my $count=10000;
use Math::Random;
my @uri=qw(
	/absolute/url/to/product
	/absolute/url/to/service
	/static/resource/image.jpg
	/absolute/url/to/product
	/absolute/url/to/other
	/ws
	/asdf
	);

say "Building samples";
my @samples=map {$_=0 if $_<0; $_=$#uri if $_> $#uri; $uri[$_].int($_)} random_normal($count, int(scalar(@uri)/2), 2);

#print @samples,"\n";;
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
	#say Dumper $table;

}
for my $dispatch (@dispatch){
	timethis 200, sub {
		for my $sample (@samples){
			$dispatch->($sample);
		}
	};
}







