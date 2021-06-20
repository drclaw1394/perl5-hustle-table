package Hustle::Table;
use version; our $VERSION=version->declare("v0.1");

use strict;
use warnings;
use Carp qw<carp croak>;
use Data::Dumper;
use feature "refaliasing";
no warnings "experimental";
use feature "switch";
use feature "state";

use constant DEBUG=>0;
require Exporter;
#use AutoLoader qw(AUTOLOAD);

#constants for entry feilds
use enum (qw<match_ sub_ label_ count_>);
use enum(qw<LOOP CACHED_LOOP DYNAMIC CACHED_DYNAMIC>);

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

#TODO:
# It's assumed that all matchers take the same amount of time to match. Clearly
# a regex will take more time than a short exact string. A more optimal ording might
# be achieved if this was measured and incorperated into the ordering.
#


#Public API
#
sub new {
	my $class=shift//__PACKAGE__;
	bless [[undef,sub {1;},"default",0]],$class;	#Prefill with default handler
}

#Add and sort accorind to count/priority
sub add {
	my ($self,@list)=@_;
	my $entry;
	state $id=0;
	for my $item (@list){
		given(ref $item){
			when("ARRAY"){
			
				$entry=$item;
				croak "Odd number of test=>dispatch vectors" unless $entry->@* == 4;
			}
			when("HASH"){
				$entry=[$item->@{qw<match sub id count>}];

				#print Dumper $entry;
			}
			default {
				croak "Unkown data format";
			}

		}
		$entry->[label_]=$id++ unless defined $entry->[label_];
		$entry->[count_]= 0 unless defined $entry->[count_];
		croak "target is not a sub refernce" unless ref $entry->[sub_] eq "CODE";
		#Append the item to the of the list (minus defaut)
		if(defined $entry->[match_]){
			splice @$self, @$self-1,0, $entry;
		}
		else {
			$self->[$self->@*-1]=$entry;
		}

	}

	#Reorder according to count/priority
	$self->_reorder;
	return;
}


#overwrites the default handler. if no
sub default {
	state $id=0;
	my ($self,$sub)=@_;
	my $entry=[undef,$sub,"default",0];
	$self->[@$self-1]=$entry;
}

sub remove {
	my ($self,$id) =@_;
	for(0..@$self-1){
		if($self->[$_][label_]==$id){
			return splice @$self, $_,1;
		}
	}
}

sub reset_counters {
	\my @t=shift; #self
	for (@t){
		$_->[count_]=0;
	}
}

sub _prepare_offline {
	print  "prepare_trainer\n";
	my ($table)=@_;	#self
	$table->reset_counters;
	sub {
		#my ($dut)=@_;
		\my @table=$table;
		for my $index (0..@table-2){	#do not process the last element
			given($_[0]){
				when($table[$index][match_]){
					$table[$index][count_]++;
					#&{$table[$index][sub_]}; #training ... no dispatching
					if($table[$index][count_]>$table[$index-1][count_]){
						my $temp=$table[$index];
						$table[$index]=$table[$index-1];
						$table[$index-1]=$temp;
					}
					return;
				}
				default {
				}
			}

		}
		#&{$table[$table->@*-1][sub_]}; #Traning no dispatching
		
	}
}

sub prepare_dispatcher{
	my $self=shift;
	my %options=@_;
	$options{type}//="loop";

	if(defined $options{reorder} and $options{reorder}){
			
		$self->_reorder;
	}

	if(defined $options{reset} and $options{reset}){
		$self->reset_counters;
	}

	do {
		given($options{type}){
			$self->_prepare_offline when /^offline$/i;	
			$self->_prepare_online_cached($options{cache}) when /^online/i and ref $options{cache} eq "HASH";
			$self->_prepare_online when /^online/i;

			default {
				$self->_prepare_online($options{cache});
			}
		}
	}
}

#
#Private API
#
sub _reorder{
	\my @self=shift;	#let sort work inplace
	my $default=pop @self;
	@self=sort {$b->[count_] <=> $a->[count_]} @self;
	push @self, $default;
	1;
}


sub _prepare_online {
        print  "online\n";
        \my @table=shift; #self
        my $d="sub {\n";
        #$d.='my ($dut)=@_;'."\n";
        $d.=' given ($_[0]) {'."\n";
        for (0..@table-2) {
                my $pre='$table['.$_.']';

                $d.='when ('.$pre."[match_]){\n";
                $d.=$pre."[count_]++;\n";
                $d.='&{'.$pre.'[sub_]};'."\n";
                $d.="}\n";
        }
        $d.="default {\n";
        $d.='&{$table[$#table][sub_]};';
        $d.="}\n";
        $d.="}\n}\n";
        #print $d;
        eval($d);
}
sub _prepare_online_cached {
	#sub _buildDynamicCached{
	print  "online_cached\n";
	\my @table=shift; #self
	my $cache=shift;
	if(ref $cache ne "HASH"){
		carp "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}

	
	my $d="sub {\n";
	#$d.='my ($dut)=@_;'."\n";
	$d.='
	given( $_[0]){
		my $hit=$cache->{$_};
		if(defined $hit){
			when(!defined $hit->[match_]){	#default case, test for defined
				$hit->[count_]++;
				delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
				return;
			}
			when($hit->[match_]){		#normal case, acutally executes potental regex
				$hit->[count_]++;
				delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
				return;

			}
		}
	}';
			
	$d.="\n".' given ($_[0]) {'."\n";


	for (0..@table-2) {
		my $pre='$table['.$_.']';

		$d.='when ('.$pre."[match_]){\n";
		$d.=$pre."[count_]++;\n";
		$d.='$cache->{$_[0]}='."$pre unless &{$pre".'[sub_]};'."\n";
		$d.="return;\n}\n";
	}
	$d.="}\n";
	$d.='$cache->{$_[0]}=$table[$#table] unless &{$table[$#table][sub_]};'."\n";
	#$d.='print Dumper $cache;'."\n";
	$d.="}\n";
	#print $d."\n";
	eval($d);
}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

