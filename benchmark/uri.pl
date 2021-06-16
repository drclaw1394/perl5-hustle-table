use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Benchmark;
use Data::Dumper;
use feature "say";


use Regex::Dispatcher;

my @hits;

my @list=(
	[qr|^/absolute/url/to/service(\d+)|, sub {}],
	[qr{^/static/resource/(image\.(?:jpg|png|))(\d+)}, sub {}],
	[qr|^/absolute/url/to/product(\d+)|, sub {}],
	[qr|^/absolute/url/to/other(\d+)|, sub {}],
	[qr|^/ws(\d+)|, sub {}],
);

my @dispatchers=(Regex::Dispatcher->new(),
	Regex::Dispatcher->new(),
	Regex::Dispatcher->new(),
	Regex::Dispatcher->new(),
);

my @options=(
	{type=>"loop",cache=>undef,reorder=>undef},
	{type=>"loop",cache=>{},reorder=>undef},
	{type=>"dynamic",cache=>undef,reorder=>undef},
	{type=>"dynamic",cache=>{},reorder=>undef},
);


my @exe;
my @dis;
for my $option (@options){
	my $dis=Regex::Dispatcher->new();
	push @dis, $dis;	
	for(@list){
		$dis->add($_->[0],$_->[1]);
	}
	push @exe, $dis->build(%$option);
	#say Dumper $dis;

}
my $count=10000;
use Math::Random;
my @uri=qw(
	/absolute/url/to/product
	/absolute/url/to/service
	/static/resource/image.jpg
	/absolute/url/to/product
	/absolute/url/to/other
	/ws|
	);

say "Building samples";
my @samples=map {$_=0 if $_<0; $_=$#uri if $_> $#uri; $uri[$_].int($_)} random_normal($count, scalar(@uri)/2, 2);

#print @samples,"\n";;
print "NO reordering\n";
for my $exe (@exe){
	timethis 200, sub {
		for my $sample (@samples){
			#say $sample;
			$exe->($sample,[]);
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
@exe=();
my $i=0;
for my $option (@options){
	my $dis=$dis[$i];#Regex::Dispatcher->new();
	
	push @exe, $dis->build(%$option);
	$i++;
	#say Dumper $dis;

}
for my $exe (@exe){
	timethis 200, sub {
		for my $sample (@samples){
			$exe->($sample,[]);
		}
	};
}







