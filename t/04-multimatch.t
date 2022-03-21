use strict;
use warnings;

use Data::Dumper;
use Hustle::Table;
use Test::More;

my $table=Hustle::Table->new;


$table->add({matcher=>"entry1", sub=> sub{print "EXACT";ok $_[1] eq "entry1"}, type=>"exact"});
$table->add({matcher=>qr{entry}, sub=> sub{print "REGEX"; ok $_[1] eq "entry1"}});
$table->add({matcher=>"entry", sub=> sub{print  "BEGIN ";ok $_[1] eq "entry1"}, type=>"begin"});
$table->add({matcher=>"ds", sub=> sub{print  "BEGIN ";ok $_[1] eq "entry1"}, type=>"begin"});

my $dispatcher=$table->prepare_dispatcher(multimatch=>1);
$dispatcher->("entry1", "entry1");
