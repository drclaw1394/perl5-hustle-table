use common::sense;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Benchmark;
use Data::Dumper;
use POSIX;


use Hustle::Table; 

my ($matchers,$samples)= do "$FindBin::Bin/data.pl";

my @list=map {[$_,sub {},undef,undef]} @$matchers;


my $table=Hustle::Table->new();
$table->add(@list);



my $cold=$table->prepare_dispatcher(type=>"online",cache=>undef);
timethis 200, sub {
	for my $sample (@$samples){
		#say $sample;
		$cold->($sample);
	}
};
say "Cold table";
say Dumper $table;

my $hot=$table->prepare_dispatcher(type=>"online",reset=>1, cache=>{}, reorder=>undef);
timethis 200, sub {
	for my $sample (@$samples){
		#say $sample;
		$hot->($sample);
	}
};

say "Warm table";
say Dumper $table;
