use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use Benchmark;


use Regex::Dispatcher;

my @hits;

my @list=(
	[qr|/absolute/url/to/product(\d+)|, sub {}],
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
for my $option (@options){
	my $dis=Regex::Dispatcher->new();
	
	for(@list){
		$dis->add($_->[0],$_->[1]);
	}
	push @exe, $dis->build(%$option);

}
my $count=10000;
my @samples=map {"/absolute/url/to/product".rand($count)} 1..$count;

#print @samples,"\n";;
print "NO reordering\n";
for my $exe (@exe){
	timethis 100, sub {
		for my $sample (@samples){
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
for my $option (@options){
	my $dis=Regex::Dispatcher->new();
	
	for(@list){
		$dis->add($_->[0],$_->[1]);
	}
	push @exe, $dis->build(%$option);

}
for my $exe (@exe){
	timethis 100, sub {
		for my $sample (@samples){
			$exe->($sample,[]);
		}
	};
}








