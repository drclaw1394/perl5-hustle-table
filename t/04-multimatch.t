use strict;
use warnings;

use Data::Dumper;
use Hustle::Table;
use Test::More;

plan tests=>3;

my $table=Hustle::Table->new;


$table->add({matcher=>"entry1", sub=> sub{ok $_[1] eq "entry1"}, type=>"exact"});
$table->add({matcher=>qr{entry}, sub=> sub{ ok $_[1] eq "entry1"}});
$table->add({matcher=>"entry", sub=> sub{ok $_[1] eq "entry1"}, type=>"begin"});
$table->add({matcher=>"ds", sub=> sub{ok $_[1] eq "entry1"}, type=>"begin"});

my $dispatcher=$table->prepare_dispatcher(multimatch=>1);

map $_->[1]($_,"entry1"), $dispatcher->("entry1");


