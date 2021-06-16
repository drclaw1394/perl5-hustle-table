package Hustle::Table;
use version; our $VERSION=version->declare("v0.0.1");

use strict;
use warnings;
use Carp qw<carp>;

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


# Preloaded methods go here.
#
#
#Public API
#
sub new {
	my $class=shift//__PACKAGE__;
	bless [[qr/.*/,sub {NO_CACHE_INPUT},-1,0]],$class;	#Prefill with default handler
}

#Add and handler and returns an id which can be used to remove it later
sub add {
	state $id=0;
	my ($self,$regex,$sub)=@_;
	$id++;
	my $entry=[$regex,$sub,$id,0];
	splice @$self, @$self-1,0, $entry;	#add before last element (default)
	return $id;
}

#overwrites the default handler. if no
sub setDefault {
	state $id=0;
	my ($self,$regex,$sub)=@_;
	my $entry=[$regex,$sub,$id,-1];
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

sub _buildLoop {
	my ($table)=@_;
	sub {
		#my ($dut)=@_;
		\my @table=$table;
		for my $index (0..@table-1){
			given($_[0]){
				when($table[$index][regex_]){
					$table[$index][count_]++;
					&{$table[$index][sub_]};
					return;
				}
				default {
				}
			}

			#returns sub ref, but no access to captures

		}
		undef;
	}
}

sub _buildLoopCached{
	use Data::Dumper;
	my ($table,$cache)=@_;
	if(ref $cache ne "HASH"){
		carp "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}
	sub {
		#my ($dut)=@_;
		given ($cache->{$_[0]}){
				when(defined){
					$_->[count_]++;
					DEBUG and print "Hit cache in loop\n";
					$_[0]=~/$_->[regex_]/ if ref($_->[regex_]) eq "Regexp"; #only do regex if we have to
					delete $cache->{$_[0]} if &{$_->[sub_]}; #delete if return is true
					return;
				}
				default{}
		}

		\my @table=$table;
		for my $index (0..@table-1){
			given($_[0]){
				when($table[$index][regex_]){
					$table[$index][count_]++;
					$cache->{$_}=$table[$index] unless &{$table[$index][sub_]};	#call the dispatch
					return;
				}
				default {

				}
			}

			#returns sub ref, but no access to captures

		}
		undef;
	}
		
}

sub _buildDynamic {
	\my @table=shift; #self
	my $d="sub {\n";
	#$d.='my ($dut)=@_;'."\n";
	$d.=' given ($_[0]) {'."\n";
	for (0..@table-1) {
		my $pre='$table['.$_.']';

		$d.='when ('.$pre."[regex_]){\n";
		$d.=$pre."[count_]++;\n";
		$d.='&{'.$pre.'[sub_]};'."\n";
		$d.="}\n";
	}
	$d.="default {\n";
	$d.="}\n";
	$d.="}\n}\n";
	#print $d;
	eval($d);
}

sub _buildDynamicCached{
	\my @table=shift; #self
	my $cache=shift;
	if(ref $cache ne "HASH"){
		carp "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}

	
	my $d="sub {\n";
	#$d.='my ($dut)=@_;'."\n";
	$d.='given($cache->{$_[0]}){
		when(defined){
			DEBUG and print "Hit cache in dynamic\n";
			$_->[count_]++;		#update hit counter
			/$_->[regex_]/ if ref($_->[regex_]) eq "Regexp";	#only do regex if we have to
			delete $cache->{$_[0]} if &{$_->[sub_]}; #delete if return is true
			return;
		}
		default {
		}
	}';
	$d.=' given ($_[0]) {'."\n";


	for (0..@table-1) {
		my $pre='$table['.$_.']';

		$d.='when ('.$pre."[regex_]){\n";
		$d.=$pre."[count_]++;\n";
		$d.='$cache->{$_[0]}='."$pre unless &{$pre".'[sub_]};'."\n";
		$d.="}\n";
	}
	$d.="default {\n";
	$d.="}\n";
	$d.="}\n}\n";
	#print $d;
	eval($d);
}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Regex::Dispatcher - Fast dispatch on string matching

=head1 SYNOPSIS

  use Regex::Dispatcher;

  #Create a new object and add entries
  
  my $dis=Regex::Dispatcher->new;
  $dis->add(/regex/,sub{ #dispatch vector});

  my $ctx={some=>"value", passed=>"to", dispatch=>"vectors"};		

  #Direct looping over the table
  my $dispatch=$dis->loopDispatch("string to matach against", ctx);

  #or
  
  #Dynamic generated lookup table
  my $table=dis->buildDispatch;

  $table->("string to match against", ctx);

  #optional

  #Optimise the table
  $dis->optimise;



=head1 DESCRIPTION

This module provides small class to create, build and match against a dispatch table optimised for string data.
It's intended goals are:
 
=over 

=item Relatively small memory footprint

=item Fast and Optimising

=item Flexible and using perl regex power

=back

=head2 HOW IT WORKS

The table contains entries which contains a regular expression, a target sub routines to call when the regex matches, and a count used for monitoring caching.







=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Ruben Westerberg, E<lt>drclaw@sd.apple.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2021 by Ruben Westerberg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.28.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
