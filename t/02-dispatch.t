use strict;
use warnings;

use Hustle::Table;
use Test::More;

plan  tests=>7;

my $table=Hustle::Table->new;

#add entries

$table->add({matcher=>"exact", type=>"exact", sub=>sub { ok $_[1] eq "exact", "Exact match ok"}});

$table->add({matcher=>"start", type=>"start", sub=>sub { ok $_[1] =~ /^start/, "Start match ok"}});

$table->add({matcher=>"end", type=>"end", sub=>sub { ok $_[1] =~ /end$/, "End match ok"}});

$table->add({matcher=>1234, type=>"numeric", sub=>sub { ok $_[1] == 1234, "Numeric match ok"}});

$table->add({matcher=>qr/re(g)ex/, sub=>sub { 
		ok $_[1] eq "regex", "regex match ok";
		ok $1 eq "g", "regex capture ok";
	}}
);

#set default
$table->set_default(sub { ok $_[1] eq "unmatched", "Defualt as expected"});


my $dispatcher=$table->prepare_dispatcher(type=>"online",cache=>undef);

#Execute dispatcher and tests
$dispatcher->("exact","exact");
$dispatcher->("start of a sentence", "start of a sentence");
$dispatcher->("match at the end", "match at the end");
$dispatcher->(1234, 1234);
$dispatcher->("regex","regex");
$dispatcher->("unmatched","unmatched");



