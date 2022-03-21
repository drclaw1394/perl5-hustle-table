package Hustle::Table;
use version; our $VERSION=version->declare("v0.5.1");

use strict;
use warnings;

use Template::Plex;

use feature "refaliasing";
no warnings "experimental";
use feature "state";

use Carp qw<carp croak>;

use Exporter 'import';

our @EXPORT_OK=qw< hustle_add hustle_remove hustle_set_default hustle_reset_counter hustle_prepare_dispatcher >;
our @EXPORT=@EXPORT_OK;

use constant DEBUG=>0;

#constants for entry fields
use enum (qw<matcher_ sub_ label_ count_ ctx_ type_>);

#Public API
#
sub new {
	my $class=shift//__PACKAGE__;
	my $default=shift//sub {1};
	my $ctx=shift;
	bless [[undef,$default,"default",0, $ctx, undef]],$class;	#Prefill with default handler
}

#Add and sort according to count/priority
sub add {
	my ($self,@list)=@_;
	my $entry;
	state $id=0;
	my @ids;
	my $rem;
	for my $item (@list){
		for(ref $item){
			if(/ARRAY/){
				#warn $item->$*;
				$entry=$item;
				croak "Incorrect number of items in dispatch vector. Should be 6" unless $entry->@* == 6;
			}

			elsif(/HASH/){
				$entry=[$item->@{qw<matcher sub label count cxt type>}];
			}

			else{
				if(@list>=4){		#Flat hash/list key pairs passed in sub call
					my %item=@list;
					$entry=[@item{qw<matcher sub label count ctx type>}];
					$rem =1;
				}
				elsif(@list==2){	#Flat list of matcher and sub
					# matcher=>sub
					$entry=[$list[0],$list[1],undef,undef,undef,undef];
					$rem=1;
				}
				else{
					
				}
			}

		}

		$entry->[label_]=$id++ unless defined $entry->[label_];
		$entry->[count_]= 0 unless defined $entry->[count_];
		croak "target is not a sub reference" unless ref $entry->[sub_] eq "CODE";
		croak "matcher not specified" unless defined $entry->[matcher_];

		if(defined $entry->[matcher_]){
			#Append to the end of the normal matching list 
			splice @$self, @$self-1,0, $entry;
			push @ids,$entry->[label_];
		}
		else {
			#No matcher, thus this used as the default
			$self->[$self->@*-1]=$entry;
		}
		last if $rem;

	}

	#Reorder according to count/priority
	$self->_reorder;
	if(wantarray){
		return @ids;
	}
	return scalar @ids;
}


#overwrites the default handler.
sub set_default {
	my ($self,$sub,$ctx)=@_;
	my $entry=[undef,$sub,"default",0,$ctx,undef];
	$self->[@$self-1]=$entry;
}

#TODO:
# handle removal of default better
sub remove {
	my ($self,@labels) =@_;

	my @removed;
	OUTER:
	for my $label (@labels){
		for(0..@$self-2){
			if($self->[$_][label_] eq $label){
				push @removed, splice @$self, $_,1;
				next OUTER;
			}
		}
	}
	return @removed;
}


sub reset_counters {
	\my @t=shift; #self
	for (@t){
		$_->[count_]=0;
	}
}


sub prepare_dispatcher{
	my $self=shift;
	my %options=@_;

	$options{reorder}//=1;
	$options{reset}//=undef;

	if(defined $options{reorder} and $options{reorder}){
		$self->_reorder;
	}

	if(defined $options{reset} and $options{reset}){
		$self->reset_counters;
	}

	carp("Cache not used. Cache must be undef or a hash ref") and return undef if defined $options{cache} and ref($options{cache}) ne "HASH";

	do {
		my $d;
		if(!$options{multimatch} and ref($options{cache}) eq "HASH"){
			#can no cache multi match
			$d=$self->_prepare_online_cached($options{cache});
		}
		else{
			$d=$self->_prepare_online($options{multimatch});
		}
		$d;
	}
}

#
#Private API
#
sub _reorder{
	\my @self=shift;	#let sort work in place
	my $default=pop @self;	#prevent default from being sorted
	@self=sort {$b->[count_] <=> $a->[count_]} @self;
	push @self, $default;	#restore default
	1;
}


sub _prepare_online {
	my $sub_template=
	'	 
	\$entry=\$table->[$index];
	\$matcher=\$entry->[Hustle::Table::matcher_];
	@{[do {
		my $d="";
		for($item->[Hustle::Table::type_]){
                        if(ref($item->[Hustle::Table::matcher_]) eq "Regexp"){
                        	$d=\'(/$matcher/o)\';
                        }
                        elsif(/exact/){
                                $d=\'($_ eq $matcher)\';
                        }
                        elsif(/start/){
                                $d=\'(index($_, $matcher)==0)\';
                        }
                        elsif(/end/){
                                $d=\'(index(reverse($_), reverse($matcher))==0)\';
                        }
                        elsif(/numeric/){
                                $d=\'($matcher == $_)\';
                        }
                        else{
                                #assume a regex
                                $d=\'(/$matcher/o)\';
                        }
		}
		$d.=\' and (++$entry->[Hustle::Table::count_])\';
		if($multimatch){
				$d.= \' and $entry->[Hustle::Table::sub_]->($entry, @_);\'
		}
		else{
				$d.= \' and unshift(@_, $entry)\';
				$d.=\' and return &{$entry->[Hustle::Table::sub_]};\'
		}

		$d;
	}]}
	';

                ##################################################################
                # and (++\$entry->[Hustle::Table::count_])                       #
                # and unshift(\@_, \$entry)                                      #
                # and @{[ $multimatch                                            #
                #                 ? \'&{$entry->[Hustle::Table::sub_]};\'        #
                #                 : \'return &{$entry->[Hustle::Table::sub_]};\' #
                # ]}                                                             #
                ##################################################################
	#return \&{\$entry->[Hustle::Table::sub_]};

	my $template=
	'sub {
		no warnings "numeric"; #TODO: Note in docs about 0 match
		my \$entry;
		#my \$input=shift;
		my \$matcher;
		for(shift){
		@{[do {
		my $index=0;
		my $base={index=>0, item=>undef, multimatch=>$multimatch};

		my $sub=plex [$sub], $base;
		
		map {
			$base->{index}=$_;
			$base->{item}=$table->[$_];
			my $s=$sub->render;
			print $s;
			$s;
			} 0..$table->@*-2;

		}]}
		#default
		\$table->[\@\$table-1][Hustle::Table::count_]++;
		unshift \@_, \$table->[\@\$table-1];
		\&{\$table->[\@\$table-1][Hustle::Table::sub_]};
		}
	}
	';

	my $table=shift;
	my $multimatch=shift;
	my $top_level=plex [$template],{table=>$table, sub=>$sub_template, multimatch=>$multimatch};
	my $s=$top_level->render;
	#print $s, "\n";
	eval $s;
}




sub _prepare_online_cached {
	my $table=shift; #self
	my $cache=shift;
	if(ref $cache ne "HASH"){
		carp "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}

	my $sub_template=
	'	 
	\$entry=\$table->[$index];
	\$matcher=\$entry->[Hustle::Table::matcher_];
	if(\$input=~/\$matcher/o){
		++\$entry->[Hustle::Table::count_];
		unshift(\@_, \$entry);
		\$cache->{\$input}=\$entry unless \&{\$entry->[Hustle::Table::sub_]};
		return;
	}
	';

	my $template=
	' sub {
		my \$input=shift;
		my \$rhit=\$cache->{\$input};
		my \$matcher;
		my \$entry;
		if(\$rhit){
			\\\my \@hit=\$rhit;
			#normal case, acutally executes potental regex
			\$matcher=\$hit[Hustle::Table::matcher_];
			if(\$input=~/\$matcher/o){
				++\$hit[Hustle::Table::count_];
				unshift \@_, \$rhit;
				delete \$cache->{\$input} if \&{\$hit[Hustle::Table::sub_]}; #delete if return is true
				return;

			}
			#if the first case does ot match, its because the cached entry is the default (undef matcher)
			else{
				++\$hit[Hustle::Table::count_];
				unshift \@_, \$rhit;
				delete \$cache->{\$input} if \&{\$hit[Hustle::Table::sub_]}; #delete if return is true
				return;
			}
		}
		@{[do {
			my $index=0;
			my $base={index=>0};

			my $sub=plex [$sub], $base;
			map {$base->{index}=$_; $sub->render } 0..$table->@*-2;
		}]}

		\$entry=\$table->[\@\$table-1];
		unshift \@_, \$entry;
		\$cache->{\$input}=\$entry unless \&{\$entry->[Hustle::Table::sub_]};
        	++\$entry->[Hustle::Table::count_];
	} ';

	my $top_level=plex [$template],{table=>$table, cache=>$cache, sub=>$sub_template};
	my $s=$top_level->render;

	#my $line=1;
	#print map $line++.$_."\n", split "\n", $s;
	my $ss=eval $s;
	#print $@;
	$ss;
}



*hustle_add=*add;
*hustle_remove=*remove;
*hustle_set_default=*set_default;
*hustle_reset_counter=*reset_counter;
*hustle_prepare_dispatcher=*prepare_dispatcher;


1;
__END__

