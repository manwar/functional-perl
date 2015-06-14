#
# Copyright 2013-2015 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

FP::Struct - classes for functional perl

=head1 SYNOPSIS

 sub is_hash {ref ($_[0]) eq "HASH"}

 use FP::Struct Bar=> ["a", [\&is_array, "b"]]=> ["Foo"];
 # creates a constructor new that takes positional arguments and
 # copies them to a hash with the keys "a" and "b". Also, sets
 # @Bar::ISA to ("Foo"). [ ] around "Foo" are optional.
 # If a field is specified as an array then the first entry is a
 # predicate that receives the value in question, if it doesn't return
 # true then an exception is thrown.
 {
   package Bar;
   use Chj::TEST; # the TEST sub will be removed from the package upon
                  # _END_ (namespace cleaning)
   # instead of use FP::Struct Bar.. above, could use this:
   # use FP::Struct ["a","b"]=> ["Foo"];
   sub sum {
      my $s=shift;
      $$s{a} + $$s{b}[0]
   }
   TEST { Bar->new(1,[2])->sum } 3;
   _END_ # generate accessors for methods of given name which don't
         # exist yet *in either Bar or any super class*. (Does that
         # make sense?)
 }
 new Bar (1,2)-> sum #=> 3
 new_ Bar (a=>1,b=>2)-> sum # dito

=head1 DESCRIPTION

Create functional setters (i.e. setters that return a copy of the
object so as to leave the original unharmed), take predicate functions
(not magic strings) for dynamic type checking, simpler than
Class::Struct.

_END_ does namespace cleaning: any sub that was defined before the use
FP::Struct call is removed by the _END_ call (those that are not the
same sub ref anymore, i.e. have been redefined, are left
unchanged). This means that if the 'use FP::Struct' statement is put
after any other (procedure-importing) 'use' statement, but before the
definition of the methods, that the imported procedures can be used
from within the defined methods, but are not around afterwards,
i.e. they will not shadow super class methods. (Thanks to Matt S Trout
for pointing out the idea.) To avoid the namespace cleaning, write
_END__ instead of _END_.

See FP::Predicates for some useful predicates.

=head1 PURITY

FP::Struct uses `FP::Pure` as default base class (i.e. when no other
base class is given). This means objects from classes based on
FP::Struct are automatically treated as pure by `is_pure` from
`FP::Predicates`.

To hold this promise true, your code must not mutate any object fields
except when it's impossible for the outside world to detect
(e.g. using a hash key to hold a cached result is fine as long as you
also override all the functional setters for fields that are used for
the calculation of the cached value to clean the cache (TODO: provide
option to turn of generation of setters, and/or provide hook).)

=cut


package FP::Struct;

use strict; use warnings; use warnings FATAL => 'uninitialized';
use Carp;
use Chj::NamespaceClean;

sub require_package {
    my ($package)=@_;
    no strict 'refs';
    if (not keys %{$package."::"}) {
	$package=~ s|::|/|g;
	$package.=".pm";
	require $package
    }
}

sub all_fields {
    my ($isa)=@_;
    (
     map {
	 my ($package)=$_;
	 no strict 'refs';
	 if (my $fields= \@{"${package}::__Struct__fields"}) {
	     (
	      all_fields (\@{"${package}::ISA"}),
	      @$fields
	     )
	 } else {
	     () # don't even look at parent classes in that case, is
                # that reasonable?
	 }
     } @$isa
    )
}

sub field_maybe_predicate ($) {
    my ($s)=@_;
    (ref $s) ? $$s[0] : undef
}

sub field_name ($) {
    my ($s)=@_;
    (ref $s) ? $$s[1] : $s
}

sub field_maybe_predicate_and_name ($) {
    my ($s)=@_;
    (ref $s) ? @$s : (undef, $s)
}

sub field_has_predicate ($) {
    my ($s)=@_;
    ref $s
}


sub Show ($) {
    my ($v)=@_;
    defined $v ? (ref $v ? $v : ($v=~ s/'/\\'/sg, "'$v'")) : "undef"
}


sub import {
    my $_importpackage= shift;
    return unless @_;
    my ($package, $fields, @perhaps_isa);
    if (ref $_[0]) {
	($fields, @perhaps_isa)= @_;
	$package= caller;
    } else {
	($package, $fields, @perhaps_isa)= @_;
    }
    my @isa= (@perhaps_isa==1 and ref($perhaps_isa[0])) ?
      $perhaps_isa[0]
	: @perhaps_isa;

    no strict 'refs';
    if (@isa) {
	require_package $_ for @isa;
    }
    @isa= "FP::Pure" unless @isa;
    *{"${package}::ISA"}= \@isa;

    my $allfields=[ all_fields (\@isa), @$fields ];
    # (^ ah, could store them in the package as well; but well, no
    # worries)
    my $allfields_name= [map {field_name $_} @$allfields];

    # get list of package entries *before* setting
    # accessors/constructors
    my $nonmethods= package_keys $package;

    # constructor with positional parameters:
    my $allfields_i_with_predicate= do {
	my $i=-1;
	[ map {
	    $i++;
	    if (my $pred= field_maybe_predicate $_) {
		[$pred, field_name ($_), $i]
	    } else {
		()
	    }
	} @$allfields ]
    };
    *{"${package}::new"}= sub {
	my $class=shift;
	@_ <= @$allfields
	  or croak "too many arguments to ${package}::new";
	for (@$allfields_i_with_predicate) {
	    my ($pred,$name,$i)=@$_;
	    &$pred ($_[$i])
	      or die "unacceptable value for field '$name': ".Show($_[$i]);
	}
	my %s;
	for (my $i=0; $i< @_; $i++) {
	    $s{ $$allfields_name[$i] }= $_[$i];
	}
	bless \%s, $class
    };

    # constructor with keyword/value parameters:
    my $allfields_h= +{ map { field_name($_)=> undef } @$allfields };
    my $allfields_with_predicate= [grep { field_maybe_predicate $_ } @$allfields];
    *{"${package}::new_"}= sub {
	my $class=shift;
	@_ <= (@$allfields * 2)
	  or croak "too many arguments to ${package}::new_";
	my %s=@_;
	for (keys %s) {
	    exists $$allfields_h{$_} or die "unknown field '$_'";
	}
	for (@$allfields_with_predicate) {
	    my ($pred,$name)=@$_;
	    &$pred ($s{$name})
	      or die "unacceptable value for field '$name': ".Show($s{$name});
	}
	bless \%s, $class
    };

    my $end= sub {
	#warn "_END_ called for package '$package'";
	for my $_field (@$fields) {
	    my ($maybe_predicate,$name)= field_maybe_predicate_and_name $_field;
	    # accessors
	    if (not $package->can($name)) {
		*{"${package}::$name"}= sub {
		    my $s=shift;
		    $$s{$name}
		};
	    }
	    # functional setters
	    my $name_set= $name."_set";
	    if (not $package->can($name_set)) {
		*{"${package}::$name_set"}=
		  ($maybe_predicate ?
		   sub {
		       my $s=shift;
		       @_==1 or die "$name_set: need 1 argument";
		       my $v=shift;
		       &$maybe_predicate($v)
			 or die "unacceptable value for field '$name': ".Show($v);
		       my $new= +{%$s};
		       ($$new{$name})=@_;
		       bless $new, ref $s
		   }
		   :
		   sub {
		       my $s=shift;
		       @_==1 or die "$name_set: need 1 argument";
		       my $new= +{%$s};
		       ($$new{$name})=@_;
		       bless $new, ref $s
		   });
	    }
	}
	1 # make module load succeed at the same time.
    };
    *{"${package}::_END__"}= $end;
    *{"${package}::_END_"}= sub {
	#warn "_END_ called for package '$package'";
	package_delete $package, $nonmethods;
	&$end;
    };

    *{"${package}::__Struct__fields"}= $fields;
}


1
