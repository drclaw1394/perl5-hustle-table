use warnings;
use strict;
use feature "switch";
no warnings "experimental";
use FindBin;
use lib "$FindBin::Bin/../lib";
use Benchmark;
use Data::Dumper;
use feature "say";
use POSIX;


use Hustle::Table; 

my @hits;

my @list=(

        [qr|^/another/regex(\d+)|oa=> sub {return},undef,undef],
        [qr|^/regex(\d+)|oa=> sub {},undef,undef],
        ["/exact"=>sub {return}, undef,undef],

        ["/another/exact"=>sub {}, undef,undef],
        ["/one/more/exact"=>sub {}, undef,undef],
	{match=>qr/hello/, sub=>sub {},id=>"lkjasdf"},
	[undef,sub{1},"defaulter", undef],
);
my @uri=qw(
        /another/regexX
	/regexX
	/exact
	/another/exact
	/one/more/exact
	asd
	);



my $table=Hustle::Table->new();
$table->add(@list);

my $count=10000;
use Math::Random;

say "Building samples";
my @samples=map {$_=0 if $_<0; $_=$#uri if $_> $#uri; $uri[$_]=~ s/X+/floor($_)/er} random_normal($count, @uri/2, 0);
local $,=", ";
#say @samples;
my $cold=$table->prepare_dispatcher(type=>"online",cache=>undef);
timethis 500, sub {
	for my $sample (@samples){
		#say $sample;
		$cold->($sample);
	}
};
say "Cold table";
say Dumper $table;

my $hot=$table->prepare_dispatcher(type=>"online",reset=>1, cache=>{}, reorder=>1);
timethis 500, sub {
	for my $sample (@samples){
		#say $sample;
		$hot->($sample);
	}
};

say "Warm table";
say Dumper $table;
