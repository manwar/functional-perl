#
# Copyright (c) 2015-2019 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

FP::Abstract::Sequence - functional sequence protocol

=head1 SYNOPSIS

 use FP::Predicates "is_sequence"; # since we can't have it in
                                   # FP::Abstract::Sequence
 use FP::PureArray;
 use FP::StrictList;
 use FP::List;
 use FP::Stream;
 use FP::Array 'array';

 use Chj::TEST;

 TEST { list(purearray(3,4),
             strictlist(3,4),
             list(3,4),
             stream(3,4),
             cons(3,4), # ok this can't really count as a sequence,
                        # what to do about it?
             array(3,4), # Could `autobox` change this?
             3,
             {3=>4},
        )->map(*is_sequence)->array }
  [ 1,1,1,1,1,'','','' ];

=head1 DESCRIPTION

This is a functional protocol, i.e. its use does not exert any side
effects. It does *not* imply `FP::Sequence::Pure`, though; impure data
structure might like to implement it all the same.

XX This is a work in progress. More base implementations should be
moved here, etc.

Also, methods that are only implemented here are inconsistent in that
they can't be imported as functions from any module. Should we really
move functions over as plain wrappers across method calls
(only?). Although perhaps it's fair to (only) have those functions
importable under a type specific name that have type specific
implementations.

=head1 SEE ALSO

L<FP::Sequence::Pure>

=head1 NOTE

This is alpha software! Read the package README.

=cut


package FP::Abstract::Sequence;

use strict; use warnings; use warnings FATAL => 'uninitialized';

require FP::List; # "use"ing it would create a circular dependency
use FP::Array_sort qw(on_maybe);
use FP::Lazy;
use FP::Ops qw(add mult);
use FP::Predicates qw(complement);

use Chj::NamespaceCleanAbove;

sub fp_interface_method_names {
    my $class= shift;
    (# base definition in this file hence not necessary to specify
     # here except for the sake of safety in case the base implementation is
     # removed:
     qw(
     flatten
     join
     extreme
     min
     max
     minmax
     subsection
     make_reduce
     reduce
     reduce_right
     sum
     product
     none
     ),
     # virtual methods:
     grep {
         not /^TODO/
     }
     qw(
     is_null
     first rest
     first_and_rest
     maybe_first maybe_rest
     perhaps_first perhaps_rest
     perhaps_first_and_rest
     map
     map_with_islast
     filter
     TODO_filter_with_tail
     drop_while
     TODO_rtake_while_and_rest
     TODO_rtake_while
     TODO_take_while_and_rest
     take_while
     every
     any
     find
     fold
     fold_right
     preferred_fold
     append
     reverse
     take
     drop
     xone
     perhaps_one
     zip
     for_each
     join
     strings_join
     length
     second
     cons
     array
     list
     stream
     sort
     ),
     # $class->SUPER::fp_interface_method_names
    )
}
#XXX different protocol for random access ones:
#hmm add ref here too?  vs. efficient_ref  etc. *?*  or  slow_ref  or somthing?
#  InefficientSequence
#     ref
# last
# butlast
#  also  sub  subsection  slice ?
# *set= blessing \&array_set;
# *push= blessing \&array_push;
# *pop= blessing_snd \&array_pop;
# *shift= blessing_snd \&array_shift;
# *unshift= blessing \&array_unshift;

#XXX other
# group group_by
#     zip2



# XXX these don't weaken the caller arguments, thus will leak for
# streams. How to solve this (and not copy-paste-adapt the methods
# manually) without fixing perl?

sub flatten {
    @_==1 or @_==2 or die "wrong number of arguments";
    my ($self, $perhaps_tail)=@_;
    $self->fold_right
      (sub {
           my ($v, $rest)=@_;
           $v->append($rest)
       },
       @_==2 ? $perhaps_tail : FP::List::null());
}

# XXX and on top of that, these return a lazy result even if the input
# isn't; related to the above issue. Find solution for both.

# unlike strings_join which returns a single string, this builds a new
# sequence with the given value between all elements of the original
# sequence

# (XX only works computationally efficient for *some* sequences;
# introduce an FP::Abstract::IterativeSequence or so and move it
# there?)
sub join {
    @_==2 or die "wrong number of arguments";
    my ($self, $value)=@_;
    # (should we recurse locally like most sequence functions? Or is
    # it actually a good idea to call the method on the rest (for
    # improper_listS, but once we introduce a `cons` method on
    # PureArray etc. that won't happen anymore?)?)
    lazy {
        $self->is_null ? $self :
          do {
              my ($v,$rest)= $self->first_and_rest;
              $rest->is_null ? $self
                : FP::List::cons($v,
                                 FP::List::cons($value, $rest->join($value)))
          }
    }
}



# XX better name?
sub extreme {
    @_==2 or die "wrong number of arguments";
    my ($self, $cmp)=@_;
    # XXX: fold_right is good for FP::Stream streaming. left fold will
    # be better for FP::List. How? Add fold_left for explicit left
    # folding and make fold chose the preferred solution for
    # order-irrelevant folding?
    $self->rest->fold
      (sub {
           my ($v, $res)=@_;
           &$cmp($v, $res) ? $v : $res
       },
       $self->first);
}

sub min {
    @_==1 or @_==2 or die "wrong number of arguments";
    my ($self, $maybe_extract)=@_;
    $self->extreme(on_maybe $maybe_extract, sub { $_[0] < $_[1] })
}

sub max {
    @_==1 or @_==2 or die "wrong number of arguments";
    my ($self, $maybe_extract)=@_;
    $self->extreme(on_maybe $maybe_extract, sub { $_[0] > $_[1] })
}

sub minmax {
    @_==1 or @_==2 or die "wrong number of arguments";
    my ($self, $maybe_extract)=@_;
    # XXX same comment as in `extreme`
    @{$self->rest->fold
        (defined $maybe_extract ?
         sub {
             my ($v, $res)=@_;
             my ($min,$max)= @$res;
             my $v_ = &$maybe_extract($v);
             [ $v_ < &$maybe_extract($min) ? $v : $min,
               $v_ > &$maybe_extract($max) ? $v : $max ]
         }
         :
         sub {
             my ($v, $res)=@_;
             my ($min,$max)= @$res;
             [ $v < $min ? $v : $min,
               $v > $max ? $v : $max ]
         },
         [$self->first, $self->first])}
}


sub subsection {
    @_==3 or die "wrong number of arguments";
    my ($self, $i0, $i1)=@_;
    # XXX same comment as in `extreme`
    $self->drop($i0)->take($i1 - $i0)
}


# Reduce is a variant of fold that doesn't require an initial
# reduction value but instead takes $seq.first() as the initial
# reduction value (it hence only works in general if the types of the
# two arguments of $fn are the same). If $seq is empty, produces the
# result by calling $fn with no arguments.

# Note: this base implementation relies on an efficient ->rest
# operation; for types where ->rest can't be made efficient (via
# e.g. slices), override this implementation!

sub make_reduce {
    my ($_class, $fold)=@_;
    sub {
        @_==2 or die "wrong number of arguments";
        my ($seq, $fn)= @_;
        if ($seq->is_null()) {
            &$fn()
        } else {
            my ($first, $rest)= $seq->first_and_rest;
            $rest->$fold($fn,$first)
        }
    }
}

# This variant folds from whichever side makes more sense for the
# type:
#  *reduce= __PACKAGE__->make_reduce("preferred_fold");

# But, the question is really eager vs. lazy evaluation, i.e. foldl vs
# foldl'. Should we do that? For now just:

sub reduce;
*reduce= __PACKAGE__->make_reduce("fold");

# These variants are explicit in which side they are folding from:

sub reduce_right;
*reduce_right= __PACKAGE__->make_reduce("fold_right");


sub sum {
    @_==1 or die "wrong number of arguments";
    $_[0]->reduce(*add)
}

sub product {
    @_==1 or die "wrong number of arguments";
    $_[0]->reduce(*mult)
}

sub none {
    @_==2 or die "wrong number of arguments";
    my ($s, $pred)=@_;
    $s->every (complement $pred)
}


_END_
