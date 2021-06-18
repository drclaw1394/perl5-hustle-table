package Hustle::Table;
use version; our $VERSION=version->declare("v0.0.1");

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
use enum (qw<regex_ sub_ id_ count_>);
use enum(qw<LOOP CACHED_LOOP DYNAMIC CACHED_DYNAMIC>);

use enum (qw<NO_CACHE_INPUT>);
our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Regex::Dispatcher ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

#TODO:
# Pass arguments from dispatch call (use &sub to save realiasing the stack)
# 	The ref to the table if the first argument
# 	The input which matched is the second
# 	remaining arguments as per the dispatch call
#
# Allow multiple entries to be added at once
# Implement an update method to alter the vector for existing entry (ie sort order remains)
#


# Preloaded methods go here.
#
#
#Public API
#
sub new {
	my $class=shift//__PACKAGE__;
	bless [[undef,sub {print "df";},"default",0]],$class;	#Prefill with default handler
}

#Add and handler and returns an id which can be used to remove it later

sub add {
	my $self=shift;

	croak "Odd number of test=>dispatch vectors" unless @_ % 4 ==0;
	for my $i (0..@_/4-1){
		my $entry=[@_[$i*4 .. $i*4+3]];
		$entry->[id_]=$entry->[id_];
		$entry->[count_]=0 unless defined $entry->[count_] and int $entry->[count_];
		unless(defined $entry->[id_] and $entry->[id_] eq "default"){
			splice @$self, @$self-1,0, $entry;	#add before last element (default)
		}
		else {
			$self->[@$self-1]=$entry;
		}
	}
	return;
}

########################################################
# sub dumpTable {                                      #
#         for(@$self){                                 #
#                 my %h;                               #
#                 @h{qw<matcher sub id count>}=$_->@*; #
#                                                      #
#         }                                            #
# }                                                    #
########################################################

#overwrites the default handler. if no
sub default {
	state $id=0;
	my ($self,$sub)=@_;
	my $entry=[undef,$sub,-1,0];
	$self->[@$self-1]=$entry;
}

sub remove {
	my ($self,$id) =@_;
	for(0..@$self-1){
		if($self->[$_][id_]==$id){
			return splice @$self, $_,1;
		}
	}
}

sub resetCounters {
	\my @t=shift; #self
	for (@t){
		$_->[count_]=0;
	}
}

sub build {
	my $self=shift;
	my %options=@_;
	$options{type}//="loop";
	if(defined $options{cache} and $options{cache}){
		$options{type}.="_cached";
	}
	if(defined $options{reorder} and $options{reorder}){
			
		$self->_reorder;
	}

	do {
		given($options{type}){
			when(/^loopauto$/i){
				$self->_buildLoopAuto();

			}
			when(/^loopauto_cached$/i){
				$self->_buildLoopAutoCached($options{cache});
			}
			when(/^loop$/i){
				$self->_buildLoop();

			}
			when(/^loop_cached$/i){
				$self->_buildLoopCached($options{cache});
			}
			when(/^dynamic$/i){

				$self->_buildDynamic();
				
			}
			when(/^dynamic_cached$/i){

				$self->_buildDynamicCached($options{cache});

			}
			default {
				#assume loop
				$self->_buildLoop();
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
sub _buildLoopAuto {
	print  "buildLoopAuto\n";
	my ($table)=@_;
	sub {
		#my ($dut)=@_;
		\my @table=$table;
		for my $index (0..@table-2){	#do not process the last element
			given($_[0]){
				when($table[$index][regex_]){
					$table[$index][count_]++;
					&{$table[$index][sub_]};
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
		#if we make it here, we process the catch all
		&{$table[$table->@*-1][sub_]};
		#return;
	}
}

sub _buildLoopAutoCached {
	use Data::Dumper;
	print  "buildLoopAutoCached\n";
	my ($table,$cache)=@_;
	if(ref $cache ne "HASH"){
		carp "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}
	sub {
		#my ($dut)=@_;
		given($_[0]){
			my $hit=$cache->{$_[0]};
			if(defined $hit){
				when(!defined $hit->[regex_]){
					#print "When did not match. Assume default\n";
					$hit->[count_]++;
					#print "Hit cache in loop\n";
					delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
					return;
				}
				when($hit->[regex_]){
					$hit->[count_]++;
					#TODO: update table order?
					DEBUG and print "Hit cache in loop\n";
					#$_[0]=~ $_->[regex_] if ref($_->[regex_]) eq "Regexp"; #only do regex if we have to
					delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
					return;
				}
			}
		}

		\my @table=$table;
		given($_[0]){
			for my $index (0..@table-2){	#do not process the last element
				when($table[$index][regex_]){
					$table[$index][count_]++;
					#&{$table[$index][sub_]};
					$cache->{$_}=$table[$index] unless &{$table[$index][sub_]};	#call the dispatch
					if($table[$index][count_]>$table[$index-1][count_]){
						my $temp=$table[$index];
						$table[$index]=$table[$index-1];
						$table[$index-1]=$temp;
					}
					return;
				}
			}

		}
		#if we make it here, we process the catch all
		#&{$table[$table->@*-1][sub_]};
		$cache->{$_[0]}=$table[$#table] unless &{$table[$table->@*-1][sub_]};
		#return;
	}
}

sub _buildLoop {
	print  "buildLoop\n";
	my ($table)=@_;
	sub {
		#my ($dut)=@_;
		\my @table=$table;
		given($_[0]){
			for my $index (0..@table-2){	#do not process the last element
				when($table[$index][regex_]){
					$table[$index][count_]++;
					&{$table[$index][sub_]};
					return;
				}
			}

		}
		#if we make it here, we process the catch all
		&{$table[$table->@*-1][sub_]};
		#return;
	}
}

sub _buildLoopCached{
	print  "buildLoopCached\n";
	use Data::Dumper;
	my ($table,$cache)=@_;
	if(ref $cache ne "HASH"){
		carp "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}
	sub {
		#my ($dut)=@_;
		given($_[0]){
			my $hit=$cache->{$_};
			#print Dumper $hit;
			if(defined $hit){
				#print "Testing cache hit for ", Dumper $hit;
				when(!defined $hit->[regex_]){
					#print "When did not match. Assume default\n";
					$hit->[count_]++;
					#print "Hit cache in loop\n";
					delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
					return;

				}
				when($hit->[regex_]){
					$hit->[count_]++;
					#print "Hit cache in loop\n";
					delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
					return;
				}
			}
		}

		\my @table=$table;
		given($_[0]){
			for my $index (0..@table-2){
				when($table[$index][regex_]){
					$table[$index][count_]++;
					$cache->{$_}=$table[$index] unless &{$table[$index][sub_]};	#call the dispatch
					return;
				}
			}


		}
		#if we make it here, we process the catch all
		$cache->{$_[0]}=$table[$#table] unless &{$table[$table->@*-1][sub_]};
		#print Dumper $cache;

	}
		
}

sub _buildDynamic {
	print  "buildDynamic\n";
	\my @table=shift; #self
	my $d="sub {\n";
	#$d.='my ($dut)=@_;'."\n";
	$d.=' given ($_[0]) {'."\n";
	for (0..@table-2) {
		my $pre='$table['.$_.']';

		$d.='when ('.$pre."[regex_]){\n";
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

sub _buildDynamicCached{
	print  "buildDynamicCached\n";
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
			when(!defined $hit->[regex_]){
			#print "Hit cache in dynamic\n";
			#	print Dumper $hit;
				$hit->[count_]++;
				delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
				return;
			}
			when($hit->[regex_]){	#forces regex to execute and do capturing
				#print "not default\n", Dumper $hit;
				$hit->[count_]++;
				delete $cache->{$_} if &{$hit->[sub_]}; #delete if return is true
				return;

			}
		}
	}';
			
	$d.="\n".' given ($_[0]) {'."\n";


	for (0..@table-2) {
		my $pre='$table['.$_.']';

		$d.='when ('.$pre."[regex_]){\n";
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

