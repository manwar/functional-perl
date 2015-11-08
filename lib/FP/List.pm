#
# Copyright (c) 2013-2015 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

FP::List - singly linked (purely functional) lists

=head1 SYNOPSIS

 use FP::List ':all';
 list_to_string(cons("H",cons("e",cons("l",cons("l",cons("o",null))))))
 # "Hello"

 list (1,2,3)->map(sub{ $_[0]*$_[0]})->array
 # [1,4,9]

 list (qw(a b c))->first # "a"
 list (qw(a b c))->rest->array # ["b","c"]

 # etc.

 # currently work like lisp pairs, no enforcement of sequences:
 cons ("a","b")->rest # "b"
 cons ("a","b")->cdr  # "b"
 list (5,6,7)->caddr # 7

=head1 DESCRIPTION

Create and dissect sequences using pure functions or methods.

=head1 NAMING

Most functional programming languages are using either the `:` or `::`
operator to prepend an item to a list. The name `cons` comes from
lisps, where it's the basic (lisp = list processing!) "construction"
function.

Cons cells (pairs) in lisps can also be used to build other data
structures than lists: they don't enforce the rest slot to be a pair
or null. Lisps traditionally use `car` and `cdr` as accessors for the
two fields, to respect this feature, and also because 'a' and 'd'
combine easily into composed names like `caddr`. This library offers
`car` and `cdr` as aliases to `first` and `rest`.

Some languages call the accessory `head` and `tail`, but `tail` would
conflict with `Sub::Call::Tail`, hence those are not used here.

=cut


package FP::List;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(cons is_pair null is_null is_pair_of is_pair_or_null
	   list_of  is_null_or_pair_of null_or_pair_of
	   car cdr first rest
	   car_and_cdr first_and_rest perhaps_first_and_rest
	   list);
@EXPORT_OK=qw(improper_list
	      is_pair_noforce is_null_noforce
	      unsafe_cons unsafe_car unsafe_cdr
	      string_to_list list_length list_reverse list_reverse_with_tail
	      list_to_string list_to_array rlist_to_array
	      list_to_values rlist_to_values
	      write_sexpr
	      array_to_list array_to_list_reverse mixed_flatten
	      list_strings_join list_strings_join_reverse
	      list_filter list_map list_mapn list_map_with_islast
	      list_fold list_fold_right list_to_perlstring
	      unfold unfold_right
	      list_pair_fold_right
	      list_drop_last list_drop_while list_rtake_while list_take_while
	      list_append
	      list_zip2
	      list_alist
	      list_every list_all list_any list_none
	      list_perhaps_find_tail list_perhaps_find
	      list_find_tail list_find
	      is_charlist ldie
	      cddr
	      cdddr
	      cddddr
	      cadr
	      caddr
	      cadddr
	      caddddr
	      c_r
	      list_ref
	      list_perhaps_one
	      list_sort
	      list_drop
	      list_take
	      list_slice
	      circularlist
	      weaklycircularlist
	    );
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';

use FP::Lazy; use FP::Lazy qw(force_noeval);
use Chj::xperlfunc qw(xprint xprintln);
use FP::Combinators qw(flip flip2of3 rot3right rot3left);
use FP::Optional qw(perhaps_to_maybe);
use Chj::TEST;
use FP::Predicates qw(is_natural0 either is_natural complement is_even is_zero);
use FP::Div qw(inc dec);
use FP::Show;

#use FP::Array 'array_fold_right'; can't, recursive dependency XX (see copy below)
#(Chj::xIOUtil triggers it)

{
    package FP::List::List;
    use base "FP::Sequence";
    *null= \&FP::List::null;
}

{
    package FP::List::Null;
    our @ISA= qw(FP::List::List);

    sub pair_namespace { "FP::List::Pair" }

    sub is_null { 1 }

    sub cons {
	my $s=shift;
	@_==1 or die "expecting 1 method argument";
	bless [@_,$s], $s->pair_namespace
    }

    sub length {
	0
    }

    sub maybe_first { undef }
    sub perhaps_first { () }
    sub perhaps_first_and_rest { () }

    sub equals {
	my ($a,$b)=@_;
	FP::List::is_null($b)
	    # XX well, this is, *currently*, guaranteed by FP::Equals,
	    # thus always 1
    }

    # for FP::Show:
    sub FP_Show_show {
	my ($s,$show)=@_;
	"null"
    }
}

{
    package FP::List::Pair;
    our @ISA= qw(FP::List::List);

    sub is_null { '' }

    sub cons {
	my $s=shift;
	@_==1 or die "expecting 1 method argument";
	bless [@_,$s], ref($s)
    }

    sub car {
	$_[0][0]
    }
    *first=*car;

    *maybe_first= *first;
    *perhaps_first= *first;

    sub cdr {
	$_[0][1]
    }
    *rest= *cdr;

    sub car_and_cdr {
	@{$_[0]}
    }
    *first_and_rest= *car_and_cdr;
    *perhaps_first_and_rest= *car_and_cdr;

    sub cddr { $_[0]->cdr->cdr }
    sub cdddr { $_[0]->cdr->cdr->cdr }
    sub cddddr { $_[0]->cdr->cdr->cdr->cdr }

    sub cadr { $_[0]->cdr->car }
    *second= *cadr;
    sub caddr { $_[0]->cdr->cdr->car }
    sub cadddr { $_[0]->cdr->cdr->cdr->car }
    sub caddddr { $_[0]->cdr->cdr->cdr->cdr->car }

    # Re `c_r`:
    # Use AUTOLOAD to autogenerate instead? But be careful about the
    # overhead of the then necessary DESTROY method.

    sub equals {
	my ($a,$b)=@_;
	(FP::List::is_pair($b)
	 and
	 FP::Equals::equals($a->car, $b->car)
	 and do {
	     @_=($a->cdr, $b->cdr); goto \&FP::Equals::equals
	 })
    }

    sub FP_Show_show {
	my ($s,$show)=@_;

	# If there were no improper or lazy lists, this would do:
	#  "list(".$s->map($show)->strings_join(", ").")"
	
	my @v;
	my $v;
      LP: {
	    ($v,$s)= $s->first_and_rest;
	    push @v, &$show($v);
	    $s= FP::List::force_noeval ($s);
	    if (FP::List::is_pair_noforce ($s)) {
		redo LP;
	    } elsif (FP::List::is_null_noforce ($s)) {
		"list(".join(", ",@v).")"
	    } else {
		push @v, &$show($s);
		"improper_list(".join(", ",@v).")"
	    }
	}
    }
}

use FP::Equals;
TEST {
    equals(list(2,3,4), list(2,3))
} undef;
TEST {
    equals(list(2,3,4), list(2,3,4))
} 1;


sub cons ($$) {
    @_==2 or die "wrong number of arguments";
    if (my $f= UNIVERSAL::can ($_[1], "cons")) {
	@_=(reverse @_); goto &$f;
    } else {
	bless [@_], "FP::List::Pair";
    }
}


# no type checking, but perhaps faster (especially if inlining ever
# becomes possible). Note that unsafe_car and unsafe_cdr are safe if
# subclasses are keeping the first fields the same and the argument
# was confirmed to be a pair with `is_pair`. unsafe_cons is safe if
# the rest argument should never dictate the type of the result.

sub unsafe_cons ($ $) {
    bless [@_], "FP::List::Pair";
}

sub unsafe_car ($) {
    $_[0][0]
}

sub unsafe_cdr ($) {
    $_[0][1]
}


sub is_pair ($);
sub is_pair ($) {
    my ($v)=@_;
    my $r= ref $v;
    length $r ?
      (UNIVERSAL::isa($v, "FP::List::Pair")
       or
       # XX evil: inlined `is_promise`
       UNIVERSAL::isa($v, "FP::Lazy::Promise")
       && is_pair (force $v))
	: '';
}

sub is_pair_noforce ($) {
    my ($v)=@_;
    my $r= ref $v;
    length $r ?
      UNIVERSAL::isa($v, "FP::List::Pair")
	  : '';
}

sub is_pair_of ($$) {
    my ($p0,$p1)=@_;
    sub {
	@_==1 or die "expecting 1 argument";
	my ($v)=@_;
	(is_pair($v)
	 and &$p0($$v[0])
	 and &$p1($$v[1]))
    }
}

# nil
my $null= bless [], "FP::List::Null";

sub null () {
    $null
}

TEST { null ->cons(1)->cons(2)->array }
  [2,1];


sub is_null ($);
sub is_null ($) {
    my ($v)=@_;
    my $r= ref $v;
    length $r ?
      (UNIVERSAL::isa($v, "FP::List::Null")
       or
       # XX evil: inlined `is_promise`
       UNIVERSAL::isa($v, "FP::Lazy::Promise") && is_null (force $v))
	: '';
}

sub is_null_noforce ($) {
    my ($v)=@_;
    my $r= ref $v;
    length $r ?
      UNIVERSAL::isa($v, "FP::List::Null")
	  : '';
}


# If in the future FP::List::Pair restricts cdr's to
# `is_pair_or_null`, then the latter could be renamed to `is_list` --
# but see FP::StrictList which does this instead now

sub is_pair_or_null ($);
sub is_pair_or_null ($) {
    my ($v)=@_;
    my $r= ref $v;
    length $r ?
      (UNIVERSAL::isa($v, "FP::List::Pair")
       or
       UNIVERSAL::isa($v, "FP::List::Null")
       or
       # XX evil: inlined `is_promise`
       UNIVERSAL::isa($v, "FP::Lazy::Promise") && is_pair_or_null (force $v))
	: '';
}

TEST { is_pair_or_null cons 1,2 } 1;
TEST { is_pair_or_null null } 1;
TEST { is_pair_or_null 1 } '';
TEST { is_pair_or_null bless [], "NirvAna" } '';
# test subclassing? whatever

sub is_null_or_pair_of ($$$);
sub is_null_or_pair_of ($$$) {
    my ($v,$p0,$p1)=@_;
    FORCE $v;
    (is_null $v
     or
     (is_pair $v
      and
      &$p0 (unsafe_car $v)
      and
      &$p1 (unsafe_cdr $v)))
}

sub null_or_pair_of ($$) {
    my ($p0,$p1)= @_;
    sub ($) {
	my ($v)=@_;
	is_null_or_pair_of ($v,$p0,$p1)
    }
}

TEST { require FP::Array;
       FP::Array::array_map
	   (null_or_pair_of (*is_null, *is_pair),
	    [null, cons (1,2), cons (null,1), cons (null,null),
	     cons (null,cons(1,1)), cons (cons (1,1),cons(1,1))]) }
  [1, '', '', '',
   1, ''];


use Chj::TerseDumper;
use Carp;
sub not_a_pair ($) {
    my ($v)= @_;
    croak "not a pair: ".TerseDumper($v);
}

sub car ($) {
    my ($v)=@_;
    my $r= ref $v;
    if (length $r and UNIVERSAL::isa($v, "FP::List::Pair")) {
	$$v[0]
    } elsif (is_promise $v) {
	@_=force $v; goto \&car;
    } else {
	not_a_pair $v;
    }
}

sub first ($); *first=*car;

# XX add maybe_first and perhaps_first wrappers here? Shouldn't this
# be more structured/automatic, finally.


sub cdr ($) {
    my ($v)=@_;
    my $r= ref $v;
    if (length $r and UNIVERSAL::isa($v, "FP::List::Pair")) {
	$$v[1]
    } elsif (is_promise $v) {
	@_=force $v; goto \&cdr;
    } else {
	not_a_pair $v;
    }
}

TEST { is_pair cons(2,3) } 1;
TEST { is_pair "FP::List::Pair" } '';
TEST { car cons(2,3) } 2;
TEST_EXCEPTION { car "FP::List::Pair" } "not a pair: 'FP::List::Pair'\n";  #why the \n?
TEST_EXCEPTION { cdr "FP::List::Pair" } "not a pair: 'FP::List::Pair'\n";  #why the \n?


sub rest ($); *rest= *cdr;

sub cddr ($) { cdr cdr $_[0] }
sub cdddr ($) { cdr cdr cdr $_[0] }
sub cddddr ($) { cdr cdr cdr cdr $_[0] }

sub cadr ($) { car cdr $_[0] }
sub caddr ($) { car cdr cdr $_[0] }
sub cadddr ($) { car cdr cdr cdr $_[0] }
sub caddddr ($) { car cdr cdr cdr cdr $_[0] }


sub c_r {
    @_==2 or die "wrong number of arguments";
    my ($s,$chain)=@_;
    my $c;
    while (length ($c= chop $chain)) {
	$s= $c eq "a" ? car ($s)
	  : $c eq "d" ? cdr ($s)
	    : die "only 'a' and 'd' acceptable in chain, have: '$chain'";
    }
    $s
}

*FP::List::List::c_r= *c_r;

TEST { list(1,list(4,7,9),5)->c_r("addad") }
  9;


sub car_and_cdr ($) {
    my ($v)=@_;
    if (length ref $v and UNIVERSAL::isa($v, "FP::List::Pair")) {
	@{$_[0]}
    } elsif (is_promise $v) {
	@_=force $v; goto \&car_and_cdr;
    } else {
	not_a_pair $v;
    }
}

sub first_and_rest($); *first_and_rest= *car_and_cdr;

sub perhaps_first_and_rest ($) {
    my ($v)=@_;
    if (length ref $v) {
	if (UNIVERSAL::isa($v, "FP::List::Pair")) {
	    @{$_[0]}
	} elsif (is_promise $v) {
	    @_=force $v; goto \&perhaps_first_and_rest;
	} elsif (UNIVERSAL::isa($v, "FP::List::Null")) {
	    ()
	} else {
	    not_a_pair $v
	}
    } else {
	not_a_pair $v;
    }
}

TEST { [ cons(1,2)->perhaps_first_and_rest ] } [1,2];
TEST { [ null->perhaps_first_and_rest ] } [];
TEST { [ perhaps_first_and_rest cons(1,2) ] } [1,2];
TEST { [ perhaps_first_and_rest null ] } [];
TEST_EXCEPTION { [ perhaps_first_and_rest "FP::List::Null" ] }
  "not a pair: 'FP::List::Null'\n"; # and XX actually not a null either.


sub list_perhaps_one ($) {
    my ($s)=@_;
    FORCE $s; # make work for stre
    if (is_pair ($s)) {
	my ($a,$r)= first_and_rest $s;
	if (is_null $r) {
	    ($a)
	} else {
	    ()
	}
    } else {
	()
    }
}

*FP::List::List::perhaps_one= *list_perhaps_one;

TEST{ [ list (8)->perhaps_one ] } [8];
TEST{ [ list (8,9)->perhaps_one ] } [];
TEST{ [ list ()->perhaps_one ] } [];

sub list_xone ($) {
    my ($s)=@_;
    FORCE $s; # make work for stre
    if (is_pair ($s)) {
	my ($a,$r)= first_and_rest $s;
	if (is_null $r) {
	    $a
	} else {
	    die "expected 1 value, got more"
	}
    } else {
	die "expected 1 value, got none"
    }
}

*FP::List::List::xone= *list_xone;

TEST{ [ list (8)->xone ] } [8];
TEST_EXCEPTION{ [ list (8,9)->xone ] } "expected 1 value, got more";
TEST_EXCEPTION{ [ list ()->xone ] } "expected 1 value, got none";



# XX adapted copy from Stream.pm
sub list_ref ($ $) {
    my ($s, $i)=@_;
    is_natural0 $i or die "invalid index: ".show($i);
    my $orig_i= $i;
  LP: {
	$s= force $s;
	if (is_pair $s) {
	    if ($i <= 0) {
		unsafe_car $s
	    } else {
		$s= unsafe_cdr $s;
		$i--;
		redo LP;
	    }
	} else {
	    die (is_null $s ?
		 "requested element $orig_i of list of length ".($orig_i-$i)
		 : "improper list")
	}
    }
}

*FP::List::List::ref= *list_ref;


sub list {
    my $res= null;
    for (my $i= $#_; $i>=0; $i--) {
	$res= cons ($_[$i],$res);
    }
    $res
}

# Like 'list' but terminates the chain with the last argument instead
# of a 'null'. This shouldn't be used in normal circumstances. It's
# mainly here to make the output of FP_Show_show valid code.
sub improper_list {
    my $res= pop;
    for (my $i= $#_; $i>=0; $i--) {
	$res= cons ($_[$i],$res);
    }
    $res
}



# These violate the principle of a purely functional data
# structure. Are they ok since they are constructors (the outside
# world will never see mutation)? (Note that streams can be cyclic
# already without mutating the cons cells, by way of using a recursive
# binding (mutating the variable that holds it, "my $s; $s= cons 1,
# lazy { $s };").)

# WARNING: results of this function won't be deallocated
# automatically. You have to break the reference cycle explicitely!
sub circularlist {
    my $l= list (@_);
    my $last= $l->drop($#_);
    $$last[1]=$l;
    $l
}

# And the result of this function will open up (interrupt the cycle)
# as soon as you let go of the front element.

use Scalar::Util "weaken";

sub weaklycircularlist {
    my $l= list (@_);
    my $last= $l->drop($#_);
    $$last[1]=$l;
    weaken ($$last[1]);
    $l
}

use Chj::Destructor;

TEST {
    my $z=0;
    my $v= do {
	my $l= circularlist "a","b",Destructor{$z++},"d";
	$l->ref (5)
    };
    [ $z, $v ]
} [ 0, "b"]; # leaking the test list!

TEST {
    my $z=0;
    my $v= do {
	my $l= weaklycircularlist "a","b",Destructor{$z++},"d";
	$l->ref (5)
    };
    [ $z, $v ]
} [ 1, "b"]; # no leak.

TEST_EXCEPTION {
    my $z=0;
    my $v= do {
	my $l= weaklycircularlist "a","b",Destructor{$z++},"d";
	$l= $l->rest;
	$l->ref (4)
    };
    [ $z, $v ]
} 'improper list'; # nice message at least, thanks to undef != null


sub delayed (&) {
    my ($thunk)=@_;
    sub {
	# evaluate thunk, expecting a function and pass our arguments
	# to that function
	my $cont= &$thunk();
	goto &$cont
    }
}

sub list_of ($);
sub list_of ($) {
    my ($p)= @_;
    either \&is_null, is_pair_of ($p, delayed { list_of $p })
}

TEST { list_of (\&is_natural) -> (list 1,2,3) } 1;
TEST { list_of (\&is_natural) -> (list -1,2,3) } 0;
TEST { list_of (\&is_natural) -> (list 1,2," 3") } 0;
TEST { list_of (\&is_natural) -> (1) } 0;


sub list_length ($) {
    my ($l)=@_;
    my $len=0;
    while (!is_null $l) {
	$len++;
	$l= cdr $l;
    }
    $len
}

*FP::List::Pair::length= *list_length;
# method on Pair not List, since we defined a length method for Null
# explicitely

TEST { list (4,5,6)->caddr } 6;
TEST { list ()->length } 0;
TEST { list (4,5)->length } 2;


sub list_to_string ($) {
    my ($l)=@_;
    my $len= list_length $l;
    my $res= " "x$len;
    my $i=0;
    while (!is_null $l) {
	my $c= car $l;
	substr($res,$i,1)= $c;
	$l= cdr $l;
	$i++;
    }
    $res
}

*FP::List::List::string= *list_to_string;

TEST { null->string } "";
TEST { cons("a",null)->string } "a";


sub list_to_array ($) {
    my ($l)=@_;
    my $res= [];
    my $i=0;
    while (!is_null $l) {
	$$res[$i]= car $l;
	$l= cdr $l;
	$i++;
    }
    $res
}

*FP::List::List::array= *list_to_array;

sub list_to_purearray {
    my ($l)=@_;
    my $a= list_to_array $l;
    require FP::PureArray;
    FP::PureArray::unsafe_array_to_purearray ($a)
}

*FP::List::List::purearray= *list_to_purearray;

TEST {
    list (1,3,4)->purearray->map (sub{$_[0]**2})
}
  bless [1,9,16], "FP::PureArray";


sub list_sort ($;$) {
    @_==1 or @_==2 or die "wrong number of arguments";
    my ($l,$maybe_cmp)= @_;
    list_to_purearray ($l)->sort ($maybe_cmp)
}

*FP::List::List::sort= *list_sort;

TEST { require FP::Ops;
       list (5,3,8,4)->sort (\&FP::Ops::number_cmp)->array }
  [3,4,5,8];

TEST { ref (list (5,3,8,4)->sort (\&FP::Ops::number_cmp)) }
  'FP::PureArray'; # XX ok? Need to `->list` if a list is needed

TEST { list (5,3,8,4)->sort (\&FP::Ops::number_cmp)->list->car }
  3; # but then PureArray has `first`, too, if that's all you need.

TEST { list (5,3,8,4)->sort (\&FP::Ops::number_cmp)->first }
  3;

#(just for completeness)
TEST { list (5,3,8,4)->sort (\&FP::Ops::number_cmp)->stream->car }
  3;


sub rlist_to_array ($) {
    my ($l)=@_;
    my $res= [];
    my $len= list_length $l;
    my $i=$len;
    while (!is_null $l) {
	$i--;
	$$res[$i]= car $l;
	$l= cdr $l;
    }
    $res
}

*FP::List::List::reverse_array= *rlist_to_array;


sub list_to_values ($) {
    my ($l)=@_;
    @{list_to_array ($l)}
}

*FP::List::List::values= *list_to_values;

# XX naming inconsistency versus docs/design.md ? Same with
# rlist_to_array.
sub rlist_to_values ($) {
    my ($l)=@_;
    @{rlist_to_array ($l)}
}

*FP::List::List::reverse_values= *rlist_to_values;

TEST { [ list(3,4,5)->reverse_values ] }
  [5,4,3];


# (modified copy from FP::Stream, as always.. (todo))
sub list_for_each ($ $ ) {
    my ($proc, $s)=@_;
  LP: {
	$s= force $s; # still leave that in for the case of
                      # heterogenous lazyness?
	if (!is_null $s) {
	    &$proc(car $s);
	    $s= cdr $s;
	    redo LP;
	}
    }
}

*FP::List::List::for_each= flip \&list_for_each;

TEST_STDOUT {
    list(1,3)->for_each (*xprintln)
} "1\n3\n";



# tons of slightly adapted COPIES from FP::Stream. XX finally find a
# solution for this

sub list_drop ($ $);
sub list_drop ($ $) {
    my ($s, $n)=@_;
    while ($n > 0) {
	$s= force $s;
	die "list too short" if is_null $s;
	$s= cdr $s;
	$n--
    }
    $s
}

*FP::List::List::drop= *list_drop;


sub list_take ($ $);
sub list_take ($ $) {
    my ($s, $n)=@_;
	if ($n > 0) {
	    $s= force $s;
	    is_null $s ?
	      $s
		: cons(car $s, list_take( cdr $s, $n - 1));
	} else {
	    null
	}
}

*FP::List::List::take= *list_take;


sub list_slice ($ $);
sub list_slice ($ $) {
    my ($start,$end)=@_;
    $end= force $end;
    my $rec; $rec= sub {
	my ($s)=@_;
	my $rec=$rec;
	    $s= force $s;
	    if (is_null $s) {
		$s # null
	    } else {
		if ($s eq $end) {
		    null
		} else {
		    cons car($s), &$rec(cdr $s)
		}
	    }
    };
    @_=($start); goto &{Weakened $rec};
}

*FP::List::List::slice= *list_slice;
# maybe call it `cut_at` instead?

# /COPIES


sub string_to_list ($;$) {
    my ($str,$maybe_tail)=@_;
    my $tail= $maybe_tail // null;
    my $i= length($str)-1;
    while ($i >= 0) {
	$tail= cons(substr ($str,$i,1), $tail);
	$i--;
    }
    $tail
}

TEST{ [list_to_values string_to_list "abc"] }
  ['a','b','c'];
TEST{ list_length string_to_list "ao" }
  2;
TEST{ list_to_string string_to_list "Hello" }
  'Hello';


# XX HACK, COPY from FP::Array to work around circular dependency
sub array_fold_right ($$$) {
    @_==3 or die "wrong number of arguments";
    my ($fn,$tail,$a)=@_;
    my $i= @$a - 1;
    while ($i >= 0) {
	$tail= &$fn($$a[$i], $tail);
	$i--;
    }
    $tail
}
sub array_fold ($$$) {
    my ($fn,$start,$ary)=@_;
    for (@$ary) {
	$start= &$fn($_,$start);
    }
    $start
}
# /HACK

sub array_to_list ($;$) {
    my ($a,$maybe_tail)=@_;
    array_fold_right (\&cons, $maybe_tail // null, $a)
}

TEST{ list_to_string array_to_list [1,2,3] }
  '123';


# XX naming correct?
sub array_to_list_reverse ($;$) {
    my ($a,$maybe_tail)=@_;
    array_fold (\&cons, $maybe_tail // null, $a)
}

TEST{ list_to_string array_to_list_reverse [1,2,3] }
  '321';


sub list_reverse_with_tail ($$) {
    my ($l, $tail)=@_;
    while (!is_null $l) {
	$tail= cons car $l, $tail;
	$l= cdr $l;
    }
    $tail
}

sub list_reverse ($) {
    my ($l)=@_;
    list_reverse_with_tail ($l, $l->null)
}


*FP::List::List::reverse_with_tail= *list_reverse_with_tail;
*FP::List::List::reverse= *list_reverse;

TEST{ list_to_string list_reverse string_to_list "Hello" }
  'olleH';


sub list_strings_join ($$) {
    @_==2 or die "wrong number of arguments";
    my ($l,$val)=@_;
    # now depend on FP::Array anyway. Lazily. XX hack~
    require FP::Array;
    FP::Array::array_strings_join( list_to_array ($l), $val);
}

*FP::List::List::strings_join= *list_strings_join;

TEST { list (1,2,3)->strings_join("-") }
  "1-2-3";

sub list_strings_join_reverse ($$) {
    @_==2 or die "wrong number of arguments";
    my ($l,$val)=@_;
    # now depend on FP::Array anyway. Lazily. XX hack~
    require FP::Array;
    FP::Array::array_strings_join( rlist_to_array ($l), $val);
}

*FP::List::List::strings_join_reverse= *list_strings_join_reverse;

TEST { list (1,2,3)->strings_join_reverse("-") }
  "3-2-1";



# write as a S-expr (trying to follow R5RS Scheme)
sub _write_sexpr ($ $ $);
sub _write_sexpr ($ $ $) {
    my ($l,$fh, $already_in_a_list)=@_;
  _WRITE_SEXPR: {
	$l= force ($l,1);
	if (is_pair $l) {
	    xprint $fh, $already_in_a_list ? ' ' : '(';
	    _write_sexpr car $l, $fh, 0;
	    my $d= force (cdr $l, 1);
	    if (is_null $d) {
		xprint $fh, ')';
	    } elsif (is_pair $d) {
		# tail-calling _write_sexpr $d, $fh, 1
		$l=$d; $already_in_a_list=1; redo _WRITE_SEXPR;
	    } else {
		xprint $fh, " . ";
		_write_sexpr $d, $fh, 0;
		xprint $fh, ')';
	    }
	} elsif (is_null $l) {
	    xprint $fh, "()";
	} else {
	    # normal perl things; should have a show method already
	    # for this? whatever.
	    if (ref $l) {
		die "don't know how to write_sexpr this: ".show($l);
	    } else {
		# assume string; there's nothing else left.
		$l=~ s/"/\\"/sg;
		xprint $fh, '"',$l,'"';
	    }
	}
    }
}
sub write_sexpr ($ ; );
sub write_sexpr ($ ; ) {
    my ($l,$fh)=@_;
    _write_sexpr ($l, $fh || *STDOUT{IO}, 0)
}

TEST_STDOUT{ write_sexpr cons("123",cons("4",null)) }
  '("123" "4")';
TEST_STDOUT{ write_sexpr (string_to_list "Hello \"World\"")}
  '("H" "e" "l" "l" "o" " " "\"" "W" "o" "r" "l" "d" "\"")';
TEST_STDOUT{ write_sexpr (cons 1, 2) }
  '("1" . "2")';
#TEST_STDOUT{ write_sexpr cons(1, cons(cons(2, undef), undef))}
#  '';
# -> XX should print #f or something for undef ! Not give exception.
TEST_STDOUT { write_sexpr cons(1, cons(cons(2, null), null))}
  '("1" ("2"))';

*FP::List::List::write_sexpr= *write_sexpr;


sub list_zip2 ($$);
sub list_zip2 ($$) {
    @_==2 or die "expecting 2 arguments";
    my ($l,$m)=@_;
    (is_null $l ? $l
     : is_null $m ? $m
     : cons([car $l, car $m], list_zip2 (cdr $l, cdr $m)))
}

TEST { list_to_array list_zip2 list(qw(a b c)), list(2,3) }
  [[a=>2], [b=>3]];

TEST { list_to_array list_zip2 list(qw(a b)), list(2,3,4) }
  [[a=>2], [b=>3]];

*FP::List::List::zip= *list_zip2; # XX make n-ary


sub list_to_alist ($);
sub list_to_alist ($) {
    @_==1 or die "expecting 2 arguments";
    my ($l)=@_;
    is_null ($l) ? $l
      : do {
	  my ($k, $l2)= $l->first_and_rest;
	  my ($v, $l3)= $l2->first_and_rest;
	  cons (cons ($k, $v),
		list_to_alist $l3)
      }
}
*FP::List::List::alist= *list_to_alist;

TEST_STDOUT { list (a=> 10, b=>20)->alist->write_sexpr }
  '(("a" . "10") ("b" . "20"))';


# (mostly-copy from Stream.pm as always)
sub list_filter ($ $);
sub list_filter ($ $) {
    my ($fn,$l)=@_;
    #weaken $_[1];
    #lazy {
	$l= force $l;
	is_null $l ? null : do {
	    my $a= car $l;
	    my $r= list_filter ($fn,cdr $l);
	    &$fn($a) ? cons($a, $r) : $r
	}
    #}
}

*FP::List::List::filter= flip \&list_filter;


sub list_map ($ $);
sub list_map ($ $) {
    my ($fn,$l)=@_;
    is_null $l ? $l : cons(&$fn(car $l), list_map ($fn,cdr $l))
}

TEST { list_to_array list_map sub{$_[0]*$_[0]}, list 1,2,-3 }
  [1,4,9];


# n-ary map
sub list_mapn {
    my $fn=shift;
    for (@_) {
	return $_ if is_null $_
    }
    cons(&$fn(map {car $_} @_), list_mapn ($fn, map {cdr $_} @_))
}

TEST{ list_to_array list_mapn (sub { [@_] },
			    array_to_list( [1,2,3]),
			    string_to_list ("")) }
  [];
TEST{ list_to_array list_mapn (sub { [@_] },
			    array_to_list( [1,2,3]),
			    string_to_list ("ab")) }
  [[1,'a'],
   [2,'b']];


sub FP::List::List::map {
    @_>=2 or die "not enough arguments";
    my $l=shift;
    my $fn=shift;
    @_ ? list_mapn ($fn, $l, @_) : list_map ($fn, $l)
}


sub list_map_with_islast {
    @_>1 or die "wrong number of arguments";
    my $fn=shift;
    my @rest= map { is_null $_ ? return null : rest $_ } @_;
    my $is_last='';
    # return *number* of ending streams, ok? XX this is unlike
    # array_map_with_islast
    for (@rest) { $is_last++ if is_null $_ }
    cons(&$fn ($is_last,
	       map { $_->first } @_),
	 list_map_with_islast ($fn, @rest))
}

sub FP::List::List::map_with_islast {
    my ($l0, $fn, @l)= @_;
    list_map_with_islast($fn,$l0,@l)
}

TEST { list(1,2,20)->map_with_islast(sub { $_[0] })->array }
  [ '','',1 ];

TEST { list(1,2,20)->map_with_islast(sub { [@_] },
				     list "b","c")->array }
  [ ['', 1, "b"], [1, 2, "c"] ];




# left fold, sometimes called `foldl` or `reduce`
# (XX adapted copy from Stream.pm)
sub list_fold ($$$) {
    my ($fn,$start,$l)=@_;
    my $v;
  LP: {
	if (is_pair $l) {
	    ($v,$l)= first_and_rest $l;
	    $start= &$fn ($v, $start);
	    redo LP;
	}
    }
    $start
}

*FP::List::List::fold= rot3left \&list_fold;

TEST{ list_fold (\&cons, null, list (1,2))->array }
  [2,1];

TEST { list(1,2,3)->map(sub{$_[0]+1})->fold(sub{ $_[0] + $_[1]},0) }
  9;

sub list_fold_right ($ $ $);
sub list_fold_right ($ $ $) {
    my ($fn,$start,$l)=@_;
    if (is_pair $l) {
	no warnings 'recursion';
	my $rest= list_fold_right ($fn,$start,cdr $l);
	&$fn (car $l, $rest)
    } elsif (is_null $l) {
	$start
    } else {
	die "improper list"
    }
}

TEST{ list_fold_right sub {
	  my ($v, $res)=@_;
	  [$v, @$res]
      }, [], list(4,5,9) }
  [4,5,9];

sub FP::List::List::fold_right {
    my $l=shift;
    @_==2 or die "expecting 2 arguments";
    my ($fn,$start)=@_;
    list_fold_right($fn,$start,$l)
}

TEST { list(1,2,3)->map(sub{$_[0]+1})->fold_right(sub{$_[0]+$_[1]},0) }
  9;


# same as fold_right but passes the whole list remainder instead of
# only the car to the function
sub list_pair_fold_right ($$$);
sub list_pair_fold_right ($$$) {
    @_==3 or die "wrong number of arguments";
    my ($fn,$start,$l)=@_;
    if (is_pair $l) {
	no warnings 'recursion';
	my $rest= list_pair_fold_right ($fn,$start,cdr $l);
	&$fn ($l, $rest)
    } elsif (is_null $l) {
	$start
    } else {
	die "improper list"
    }
}

*FP::List::List::pair_fold_right= rot3left *list_pair_fold_right;

TEST_STDOUT { list(5,6,9)->pair_fold_right (*cons, null)->write_sexpr }
  '(("5" "6" "9") ("6" "9") ("9"))';


# no list_ prefix? It doesn't consume lists. Although, still FP::List
# specific. But there's no way to shorten it by way of method
# calling. For FP::Stream, call it stream_unfold, similarly for other
# *'special'* kinds of lists?

# unfold p f g seed [tail-gen] -> list

# p: predicate function, wenn true for seed stops production;
# f: function to produce output value from seed;
# g: function to produce the next seed value;
# seed: the initial seed value;
# tail-gen: optional function to map the last seed value, the value
#           `null` is taken otherwise

# For more documentation, see
# http://srfi.schemers.org/srfi-1/srfi-1.html#FoldUnfoldMap

sub unfold ($$$$;$);
sub unfold ($$$$;$) {
    @_==4 or @_==5 or die "wrong number of arguments";
    my ($p, $f, $g, $seed, $maybe_tail_gen)= @_;
    &$p ($seed) ?
      (defined $maybe_tail_gen ? &$maybe_tail_gen ($seed) : null)
	: cons (&$f ($seed), unfold ($p, $f, $g, &$g($seed), $maybe_tail_gen));
}

TEST { unfold (*is_zero, *inc, *dec, 5)->array } [6, 5, 4, 3, 2];
TEST { unfold (*is_zero, *inc, *dec, 5, *list)->array } [6, 5, 4, 3, 2, 0];


# unfold-right p f g seed [tail] -> list

sub unfold_right ($$$$;$);
sub unfold_right ($$$$;$) {
    @_==4 or @_==5 or die "wrong number of arguments";
    my ($p, $f, $g, $seed, $maybe_tail)= @_;
    my $tail= @_==5 ? $maybe_tail : null;
  LP: {
	if (&$p ($seed)) {
	    $tail
	} else {
	    ($seed,$tail)= (&$g ($seed),
			    cons (&$f ($seed), $tail));
	    redo LP;
	}
    }
}

TEST { unfold_right (*is_zero, *inc, *dec, 5)->array } [2, 3, 4, 5, 6];
TEST { unfold_right (*is_zero, *inc, *dec, 5, list 99)->array } [2, 3, 4, 5, 6, 99];



sub list_append ($ $) {
    @_==2 or die "wrong number of arguments";
    my ($l1,$l2)=@_;
    list_fold_right (\&cons, $l2, $l1)
}

TEST{ list_to_array  list_append (array_to_list (["a","b"]),
			       array_to_list([1,2])) }
  ['a','b',1,2];

*FP::List::List::append= *list_append;

TEST{ array_to_list (["a","b"]) ->append(array_to_list([1,2])) ->array }
  ['a','b',1,2];


sub list_to_perlstring ($) {
    my ($l)=@_;
    list_to_string
      cons ("'",
	    list_fold_right sub {
		my ($c,$rest)= @_;
		my $out= cons ($c, $rest);
		if ($c eq "'") {
		    cons ("\\", $out)
		} else {
		    $out
		}
	    }, cons("'",null), $l)
}

TEST{ list_to_perlstring string_to_list  "Hello" }
  "'Hello'";
TEST{ list_to_perlstring string_to_list  "Hello's" }
  q{'Hello\'s'};

*FP::List::List::perlstring= *list_to_perlstring;


sub list_drop_last ($);
sub list_drop_last ($) {
    my ($l)=@_;
    if (is_null ($l)) {
	die "drop_last: got empty list"
	# XX could make use of OO for the distinction instead
    } else {
	my ($a,$r)= $l->first_and_rest;
	is_null ($r) ? $r : cons($a, list_drop_last $r)
    }
}

*FP::List::List::drop_last= *list_drop_last;

TEST { list (3,4,5)->drop_last->array }
  [3,4];
TEST_EXCEPTION { list ()->drop_last->array }
  "drop_last: got empty list";


sub list_drop_while ($ $) {
    my ($pred,$l)=@_;
    while (!is_null $l and &$pred(car $l)) {
	$l=cdr $l;
    }
    $l
}

TEST { list_to_string list_drop_while (sub{$_[0] ne 'X'},
				       string_to_list "Hello World") }
  "";
TEST { list_to_string list_drop_while (sub{$_[0] ne 'o'},
				       string_to_list "Hello World") }
  "o World";

*FP::List::List::drop_while= flip \&list_drop_while;

TEST { string_to_list("Hello World")
	 ->drop_while(sub{$_[0] ne 'o'})
	   ->string }
  "o World";


sub rtake_while_ ($ $) {
    my ($pred,$l)=@_;
    my $res= $l->null;
    my $c;
    while (!is_null $l and &$pred($c= car $l)) {
	$res= cons $c,$res;
	$l=cdr $l;
    }
    ($res,$l)
}

*FP::List::List::rtake_while_= flip \&rtake_while_;

sub list_rtake_while ($ $) {
    my ($pred,$l)=@_;
    my ($res,$rest)= rtake_while_ ($pred,$l);
    wantarray ? ($res,$rest) : $res
}

*FP::List::List::rtake_while= flip \&list_rtake_while;

TEST{ list_to_string list_reverse (list_rtake_while \&char_is_alphanumeric,
				   string_to_list "Hello World") }
  'Hello';

sub take_while_ ($ $) {
    my ($pred,$l)=@_;
    my ($rres,$rest)= list_rtake_while ($pred,$l);
    (list_reverse $rres,
     $rest)
}

*FP::List::List::take_while_= flip \&take_while_;

sub list_take_while ($ $) {
    my ($pred,$l)=@_;
    my ($res,$rest)= take_while_ ($pred,$l);
    wantarray ? ($res,$rest) : $res
}

*FP::List::List::take_while= flip \&list_take_while;

TEST { list_to_string list_take_while (sub{$_[0] ne 'o'},
				       string_to_list "Hello World") }
  "Hell";
TEST { list_to_string list_take_while (sub{$_[0] eq 'H'},
				       string_to_list "Hello World") }
  "H";
TEST { list_to_string list_take_while (sub{1}, string_to_list "Hello World") }
  "Hello World";
TEST { list_to_string list_take_while (sub{0}, string_to_list "Hello World") }
  "";


sub list_every ($$) {
    my ($pred,$l)=@_;
  LP: {
	if (is_pair $l) {
	    (&$pred (car $l)) and do {
		$l= cdr $l;
		redo LP;
	    }
	} elsif (is_null $l) {
	    1
	} else {
	    # improper list
	    # (XX check value instead? But that would be improper_every.)
	    #0
	    die "improper list"
	}
    }
}

*FP::List::List::every= flip \&list_every;

# XXX do we want this alias? Or do we just want to rename every to
# all?
sub list_all ($$);
*list_all= *list_every;

*FP::List::List::all= flip \&list_every;

TEST { [ map { list_every sub{$_[0]>0}, $_ }
	 list (1,2,3),
	 list (1,0,3),
	 list (),
       ] }
  [1, '', 1];

use FP::Char 'char_is_alphanumeric';

TEST { string_to_list("Hello") ->every(\&char_is_alphanumeric) }
  1;
TEST { string_to_list("Hello ") ->every(\&char_is_alphanumeric) }
  '';


sub list_none ($$) {
    my ($pred,$l)=@_;
    list_every (complement ($pred), $l)
}

*FP::List::List::none= flip \&list_none;

TEST { string_to_list("Hello") ->none(\&char_is_alphanumeric) }
  '';
TEST { string_to_list(" -()&") ->none(\&char_is_alphanumeric) }
  1;
TEST {
    my $z=0;
    my $r=string_to_list(" -()&a")->none(sub { $z++; char_is_alphanumeric $_[0] });
    [$z,$r]
}
  [6, ''];
TEST {
    my $z=0;
    my $r=string_to_list(" a-()&a")->none(sub { $z++; char_is_alphanumeric $_[0] });
    [$z,$r]
}
  [2, ''];


sub list_any ($ $) {
    my ($pred,$l)=@_;
  LP: {
	if (is_pair $l) {
	    (&$pred (car $l)) or do {
		$l= cdr $l;
		redo LP;
	    }
	} elsif (is_null $l) {
	    0
	} else {
	    die "improper list"
	}
    }
}

*FP::List::List::any= flip \&list_any;

TEST{ list_any sub { $_[0] % 2 }, array_to_list [2,4,8] }
  0;
TEST{ list_any sub { $_[0] % 2 }, array_to_list [] }
  0;
TEST{ list_any sub { $_[0] % 2 }, array_to_list [2,5,8]}
  1;
TEST{ list_any sub { $_[0] % 2 }, array_to_list [7] }
  1;


# The following two functions differ from their paragons from SRFI-1
# in that they do not return false or undef on failure, but (), and
# carry `perhaps` in their name of this reason.

sub list_perhaps_find_tail ($$) {
    @_==2 or die "wrong number of arguments";
    my ($fn, $l)=@_;
  LP: {
	if (is_null $l) {
	    ()
	} else {
	    my ($v,$l1)= $l->first_and_rest;
	    if (&$fn ($v)) {
		$l
	    } else {
		$l= $l1;
		redo LP
	    }
	}
    }
}

*FP::List::List::perhaps_find_tail= flip \&list_perhaps_find_tail;

TEST {
    list(3,1,37,-8,-5,0,0)->perhaps_find_tail (*is_even)->array }
  [-8,-5,0,0];
TEST { [list(3,1,37,-5)->perhaps_find_tail (*is_even)] }
  [];


sub list_perhaps_find ($$) {
    @_==2 or die "wrong number of arguments";
    my ($fn, $l)=@_;
    if (my ($l)= list_perhaps_find_tail ($fn, $l)) {
	unsafe_car $l
    } else {
	()
    }
}

*FP::List::List::perhaps_find= flip \&list_perhaps_find;

TEST { list(3,1,4,1,5,9)->perhaps_find(*is_even) }
  4;


# And then still also add the SRFI-1 counterparts, without `maybe` in
# the names as they should have according to our guidelines, XX hmm.


#sub list_find_tail ($$);
#  sigh, can't retain the prototypes unless writing perhaps_to_maybe
#  for every number of arguments.
*list_find_tail= perhaps_to_maybe (\&list_perhaps_find_tail);
*FP::List::List::find_tail= flip \&list_find_tail;

#sub list_find ($$);
*list_find= perhaps_to_maybe (\&list_perhaps_find);
*FP::List::List::find= flip \&list_find;

TEST { list(3,1,4,1,5,9)->find(*is_even) }
  4;
TEST { list(3,1,37,-8,-5,0,0)->find_tail (*is_even)->array }
  [-8,-5,0,0];
TEST { [list(3,1,37,-5)->find_tail (*is_even)] }
  [undef];


# Turn a mix of (nested) arrays and lists into a flat list.

# If the third argument is given, it needs to be a reference to either
# lazy or lazyLight. In that case it will force promises, but only
# lazily (i.e. provide a promise that will do the forcing and consing).

sub mixed_flatten ($;$$);
sub mixed_flatten ($;$$) {
    my ($v,$maybe_tail,$maybe_delay)=@_;
    my $tail= $maybe_tail//null;
  LP: {
	if ($maybe_delay and is_promise $v) {
	    my $delay= $maybe_delay;
	    &$delay
	      (sub {
		   @_=(force($v), $tail, $delay); goto \&mixed_flatten;
	       });
	} else {
	    if (is_null $v) {
		$tail
	    } elsif (is_pair $v) {
		no warnings 'recursion';
		$tail= mixed_flatten (cdr $v, $tail, $maybe_delay);
		$v= car $v;
		redo LP;
	    } elsif (ref $v eq "ARRAY") {
		@_= (sub {
			 @_==2 or die "wrong number of arguments";
			 my ($v,$tail)=@_;
			 no warnings 'recursion';
			 # ^XX don't understand why it warns here
			 @_=($v,$tail,$maybe_delay); goto \&mixed_flatten;
		     },
		     $tail,
		     $v);
		require FP::Stream; # XX ugly? de-circularize?
		goto ($maybe_delay
		      ? \&FP::Stream::stream__array_fold_right
		      #^ XX just expecting it to be loaded
		      : \&array_fold_right);
	    } else {
		#warn "improper list: $v"; well that's part of the spec, man
		cons ($v, $tail)
	    }
	}
    }
}

*FP::List::List::mixed_flatten= flip \&mixed_flatten;

TEST{ list_to_array mixed_flatten [1,2,3] }
  [1,2,3];
TEST{ list_to_array mixed_flatten [1,2,[3,4]] }
  [1,2,3,4];
TEST{ list_to_array mixed_flatten [1,cons(2, [ string_to_list "ab" ,4])] }
  [1,2,'a','b',4];
TEST{ list_to_string mixed_flatten [string_to_list "abc",
				 string_to_list "def",
				 "ghi"] }
  'abcdefghi';  # only works thanks to perl chars and strings being
                # the same datatype

TEST_STDOUT{ write_sexpr( mixed_flatten
			  lazyLight { cons(lazy { 1+1 }, null)},
			  undef,
			  \&lazyLight) }
  '("2")';
TEST_STDOUT{ write_sexpr( mixed_flatten
			  lazyLight { cons(lazy { [1+1,lazy {2+1}] },
					   null) },
			  undef,
			  \&lazyLight) }
  '("2" "3")';

TEST_STDOUT{
    sub countdown {
	my ($i)=@_;
	if ($i) {
	    lazyLight {cons ($i, countdown($i-1))}
	} else {
	    null
	}
    }
    write_sexpr ( mixed_flatten
		  lazyLight { cons(lazy { [1+1,countdown 10] }, null)},
		  undef,
		  \&lazyLight)
}
  '("2" "10" "9" "8" "7" "6" "5" "4" "3" "2" "1")';

TEST_STDOUT{ write_sexpr
	       (mixed_flatten
		[lazyLight { [3,[9,10]]}],
		undef,
		\&lazyLight ) }
    '("3" "9" "10")';
TEST_STDOUT { write_sexpr
		(mixed_flatten
		 [1,2, lazyLight { [3,9]}],
		 undef,
		 \&lazyLight) }
    '("1" "2" "3" "9")';



use FP::Char 'is_char';

sub is_charlist ($) {
    my ($l)=@_;
    list_every \&is_char, $l
}

*FP::List::List::is_charlist= *is_charlist;

use Carp;

sub ldie {
    # perl string arguments are messages, char lists are turned to
    # perl-quoted strings, then everyting is appended
    my @strs= map {
	if (is_charlist $_) {
	    list_to_perlstring $_
	} elsif (is_null $_) {
	    "()"
	} else {
	    # XX have a better write_sexpr that can fall back to something
	    # better?, and anyway, need string
	    $_
	}
    } @_;
    croak join("",@strs)
}


1
