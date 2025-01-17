#
# Copyright (c) 2014-2019 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

FP::Combinators - function combinators

=head1 SYNOPSIS

    use FP::Ops 'div';
    use FP::Combinators 'flip';

    is div(2,3), 2/3;
    is flip(\&div)->(2,3), 3/2;

=head1 DESCRIPTION

"A combinator is a higher-order function that uses only function
application and earlier defined combinators to define a result from
its arguments."

(from https://en.wikipedia.org/wiki/Combinator)


=head1 SEE ALSO

L<FP::Optional>

=head1 NOTE

This is alpha software! Read the package README.

=cut


package FP::Combinators;
@ISA="Exporter"; require Exporter;
@EXPORT=qw();
@EXPORT_OK=qw(compose compose_scalar maybe_compose compose_1side
              flip flip2of3 rot3right rot3left);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';

use Chj::TEST;

sub compose {
    my (@fn)= reverse @_;
    sub {
        my (@v)= @_;
        for my $fn (@fn) {
            @v= &$fn(@v);
        }
        wantarray ? @v : $v[-1]
    }
}

# same as compose, but request scalar context between the calls:

sub compose_scalar {
    my (@fn)= reverse @_;
    my $f0= pop @fn;
    my $fx= shift @fn;
    sub {
        my $v= &$fx;
        for my $fn (@fn) {
            $v= &$fn($v);
        }
        @_=($v); goto &$f0
    }
}

TEST { compose (sub { $_[0]+1 }, sub { $_[0]+$_[1] })->(2,3) }
  6;
TEST { compose_scalar  (sub { $_[0]+1 }, sub { $_[0]+$_[1] })->(2,3) }
  6;

TEST { compose (sub { $_[0] / ($_[1]//5) },
                sub { @_ },
                sub { $_[1], $_[0] })
         ->(2,3) }
  1.5;
TEST { compose_scalar (sub { $_[0] / ($_[1]//5) },
                       sub { @_ },
                       sub { $_[1], $_[0] })
         ->(2,3) }
  1/5;


# a compose that short-cuts when there is no defined intermediate
# result:

sub maybe_compose {
    my (@fn)= reverse @_;
    sub {
        my (@v)= @_;
        for (@fn) {
            # return undef, not (), for 'maybe_'; the latter would ask
            # for convention 'perhaps_', ok?
            return undef unless @v>1 or defined $v[0];
            @v= &$_(@v);
        }
        wantarray ? @v : $v[-1]
    }
}

TEST { maybe_compose (sub { die "foo @_" }, sub { undef }, sub { @_ })->(2,3) }
  undef;
TEST { maybe_compose (sub { die "foo @_" }, sub { undef })->(2,3) }
  undef;
TEST { maybe_compose (sub { [@_] }, sub { @_ })->(2,3) }
  [2,3];


# a compose with 1 "side argument" (passed to subsequent invocations unmodified)
sub compose_1side ($$) {
    my ($f, $g)=@_;
    sub {
        my ($a,$b)=@_;
        #XX TCO?
        &$f (scalar &$g ($a, $b), $b)
    }
}



use Carp;

# XX should flip work like the curried versions (e.g. in Haskell),
# i.e. not care about remaining arguments and simply flip the first
# two? That would save the need for flip2of3 etc., but it would also
# be less helpful for error-checking.

sub flip ($) {
    my ($f)=@_;
    sub {
        @_==2 or croak "expecting 2 arguments";
        @_=($_[1], $_[0]); goto &$f
    }
}

TEST { flip (sub { $_[0] / $_[1] })->(2,3) }
  3/2;

# same as flip but pass a 3rd argument unchanged (flip 2 in 3)
sub flip2of3 ($) {
    my ($f)=@_;
    sub {
        @_==3 or croak "expecting 3 arguments";
        @_=($_[1], $_[0], $_[2]); goto &$f
    }
}

sub rot3right ($) {
    my ($f)=@_;
    sub {
        @_==3 or croak "expecting 3 arguments";
        @_=($_[2], $_[0], $_[1]); goto &$f
    }
}

sub rot3left ($) {
    my ($f)=@_;
    sub {
        @_==3 or croak "expecting 3 arguments";
        @_=($_[1], $_[2], $_[0]); goto &$f
    }
}


1
