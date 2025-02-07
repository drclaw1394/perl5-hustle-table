package Hustle::Table;
our $VERSION="v0.7.0";

use strict;
use warnings;

use Template::Plex;

#use feature "refaliasing";
no warnings "experimental";




use constant::more DEBUG=>0;

#constants for entry fields
use constant::more {matcher_=>0,
  value_=>1,
  type_=>2,
  default_=>3
};

#Public API
#
sub new {
	my $class=shift//__PACKAGE__;
	my $default=shift//undef;
	bless [[undef,$default, "exact",1]],$class;	#Prefill with default handler
}

sub add {
	my ($self,@list)=@_;
	my $entry;
	my $rem;
	for my $item (@list){
		for(ref $item){
			if(/ARRAY/){
				#warn $item->$*;
				$entry=$item;
				die "Incorrect number of items in dispatch vector. Should be 3" unless $entry->@* == 3;
			}

			elsif(/HASH/){
				$entry=[$item->@{qw<matcher value type>}];
			}

			else{
				if(@list>=4){		#Flat hash/list key pairs passed in sub call
					my %item=@list;
					$entry=[@item{qw<matcher value type>}];
					$rem =1;
				}
				elsif(@list==2){	#Flat list of matcher and sub. Assume regex
					# matcher=>sub
					$entry=[$list[0],$list[1],undef];
					$rem=1;
				}
				else{
					
				}
			}

		}

		if(defined $entry->[matcher_]){
			#Append to the end of the normal matching list 
			splice @$self, @$self-1,0, $entry;
		}
		else {
			#No matcher, thus this used as the default
			$self->set_default($entry->[value_]);
			#$self->[$self->@*-1]=$entry;
		}
		last if $rem;
	}
}


#overwrites the default handler.
sub set_default {
	my ($self,$sub)=@_;
	my $entry=[undef,$sub,"exact",1];
	$self->[@$self-1]=$entry;
}



sub prepare_dispatcher{
	my $self=shift;
	my %options=@_;
	my $cache=$options{cache}//{};

  # Force delete cached entries when rebuilding dispather
  for(keys %$cache){
    delete $cache->{$_};
  }
	$self->_prepare_online_cached($cache);
}

#
#Private API
#

sub _prepare_online_cached {
	my $table=shift; #self
	my $cache=shift;
	if(ref $cache ne "HASH"){
		warn "Cache provided isn't a hash. Using internal cache with no size limits";
		$cache={};
	}

	my $sub_template=
	'	 
	@{[do {
		my $d="";

    my $pack=ref $item->[Hustle::Table::matcher_];
    my $is_regex;

    if($pack){
      $is_regex= ($pack eq "Regexp" or grep /^Regexp$/, @{$pack."::ISA"});
    }


		for($item->[Hustle::Table::type_]){
      if($is_regex){
        $d.=\'($input=~$table->[\'. $index .\'][Hustle::Table::matcher_] )\';
      }
			elsif(ref($item->[Hustle::Table::matcher_]) eq "CODE"){

				$d.=\'($table->[\'.$index.\'][Hustle::Table::matcher_]->($input, ($table->[\'.$index.\'][1])))\';
			}
      elsif(/exact/){
				$d.=\'($input eq "\'. $item->[Hustle::Table::matcher_]. \'")\';
      }
      elsif(/begin/){
              $d.=\'(index($input, "\' . $item->[Hustle::Table::matcher_]. \'")==0)\';
      }
      elsif(/end/){
              $d.=\'(index(reverse($input), reverse("\'. $item->[Hustle::Table::matcher_].\'"))==0)\';
      }
      elsif(/numeric/){
              $d.=\'(\' . $item->[Hustle::Table::matcher_] . \'== $input)\';
      }
      else{
        #assume a regex - even if a basic string
				$item->[Hustle::Table::matcher_]=qr{$item->[Hustle::Table::matcher_]};
				$item->[Hustle::Table::type_]=undef;
        $is_regex=1;
        redo;
      }
		}


		if($is_regex){
			$d.=\' and (push $cache->{$input}->@*, $table->[\'.$index.\'], [@{^CAPTURE}]);\';
		}	
		else {
			$d.=\' and (push $cache->{$input}->@*, $table->[\'.$index.\'],  undef);\';

		}
		$d;
	}]}
	';

	my $template=
	'
	my \$entry;
  no warnings "numeric";
	sub {
    my \@output;
    for my \$input (\@_){
      \$entry=\$cache->{\$input};
      \$entry and return \$entry->\@*;



      #Build the logic for matcher entry in order of listing
      @{[do {
        my $index=0;
        my $base={index=>0, item=>undef};
        my $sub=$self->load([$sub], $base);
        map {
          $base->{index}=$_;
          $base->{item}=$table->[$_];
          my $s=$sub->render;
          $s;
        } 0..$table->@*-2;
      }]}


      for(\$cache->{\$input}//=[]){
        # If we get here and nothing matched, we force default match
        push \$_->\@*, \$table->[\@\$table-1], undef unless \$_->\@*;
        
        # Copy to output
        push \@output, \$_->@*;
      } 
    }
    return \@output;
	} ';

	my $top_level=Template::Plex->load([$template],{table=>$table, cache=>$cache, sub=>$sub_template});
	my $s=$top_level->render;
	my $ss=eval $s;
	$ss;
}



1;
__END__

