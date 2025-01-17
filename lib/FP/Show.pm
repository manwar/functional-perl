#
# Copyright (c) 2015-2019 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

FP::Show - give (nice) code representation for debugging purposes

=head1 SYNOPSIS

 use FP::Show; # exports 'show'
 use FP::List;

 is show(list(3, 4)->map(sub{$_[0]*10})), "list(30, 40)";


=head1 DESCRIPTION

The 'show' function takes a value and returns a string of Perl code
which when evaluated should produce an equivalent clone of that value
(assuming that the Perl functions used in the string are imported into
the namespace where the code is evaluated).

It is somewhat like Data::Dumper, but enables classes to determine the
formatting of their instances by implementing the
L<FP::Abstract::Show> protocol (for details, see there). This allows
for concise, more highlevel output than just showing the bare
internals. It's, for example, normally not useful when inspecting data
for debugging to know that an instance of FP::List consists of a chain
of FP::List::Pair objects which in turn are made of blessed arrays or
what not; just showing a call to the same convenience constructor
function that can be used normally to create such a value is a better
choice (see the example in the SYNOPSIS, and for more examples the
`intro` document of the Functional Perl distribution or website).

`show` always works, regardless of whether a value implements the
protocol--it falls back to L<Data::Dumper>.


=head1 ALTERNATIVES

Data::Dumper *does* have a similar feature, $Data::Dumper::Freezer,
but it needs the object to be mutated, which is not what one will
want.

Why not use string overloading instead? Because '""' overloading is
returning 'plain' strings, not perl code (or so it seems, is there any
spec that defines exactly what it means?) Code couldn't know whether
to quote the result:

 sub foo2 {
     my ($l)=@_;
     # this is quoting safe:
     die "not what we wanted: ".show($l)
     # this would not be:
     #die "not what we wanted: $l"
 }

 eval { foo2 list 100-1, "bottles"; };
 like $@, qr/\Qnot what we wanted: list(99, 'bottles')/;
 eval { foo2 "list(99, 'bottles')"; };
 like $@, qr/\Qnot what we wanted: 'list(99, \'bottles\')'/;
 # so how would you tell which value foo2 really got in each case,
 # just from looking at the message?

 # also:
 eval { foo2 +{a=> 1, b=>10}; };
 like $@, qr/\Qnot what we wanted: +{a => 1, b => 10}/;
   # would die with something like:
   #   not what we wanted: HASH(0xEADBEEF)
   # which isn't very informative

Embedding pointer values in the output also means that it can't be
used for automatic testing. (Even with a future implementation of
cut-offs, values returned by `show` will be good enough when what one
needs to do is compare against a short representation. Also, likely we
would implement the cut-off value as an optional parameter.)

=head1 BUGS

Show can't currently handle circular data structures (it will run out
of stack space.) Not hard to fix (turtle and hare algo), just need to
do it.

=head1 SEE ALSO

L<FP::Abstract::Show> for the protocol definition. Note that FP::Show
also works on values which don't implement the protocol (fall back to
Data::Dumper).

L<http://www.functional-perl.org/docs/intro.xhtml> for the mentioned intro.

L<FP::Equal>

=head1 NOTE

This is alpha software! Read the package README.

=cut


package FP::Show;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(show);
@EXPORT_OK=qw(show_many);
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';

use Chj::TerseDumper qw(terseDumper);
use Scalar::Util qw(reftype);
use Devel::Peek q(DumpWithOP);
use Capture::Tiny qw(capture_stderr);

sub keyshow ($) {
    my ($str)=@_;
    ($str=~ /^\w+$/s
     and
     # make sure it's not just an integer, as that would not be quoted
     # by perl and if big enough yield something different than the
     # string
     $str=~ /[a-zA-Z]/s
    ) ? $str : terseDumper($str)
}

our $primitive_show=
  +{
    # these return string or (string, bool) where the bool indicates
    # the string already contains blessing
    ARRAY=> sub {
        my ($v,$show)=@_;
        "[".join(", ",
                 map { &$show ($_) } @$v)."]";
    },
    HASH=> sub {
        my ($v,$show)=@_;
        "+{".join(", ",
                  map { keyshow($_)." => ".&$show ($$v{$_}) }
                  sort
                  keys %$v)."}";
    },
    REF=> sub { # references to references
        my ($v,$show)=@_;
        "\\(".&$show ($$v).")"
    },
    GLOB=> sub {
        my ($v,$show)=@_;
        (terseDumper($v), 1)
    },
    SCALAR=> sub {
        my ($v,$show)=@_;
        (terseDumper($v), 1)
    },
    CODE=> sub {
        my ($v,$show)=@_;
        my $info= capture_stderr { DumpWithOP($v) };
        my @FILE= $info=~ m/\bFILE *= *("[^"]*"|\S+) *\n/g;
        my @LINE= $info=~ m/\bLINE *= *(\d+) *\n/g; # col?..
        my $location= do {
            if (@FILE) {
                my $filestr= $FILE[-1];
                if (@LINE) {
                    my $line= $LINE[0];
                    "at $filestr line $line"
                } else {
                    "at $filestr (line unknown)"
                }
            } else {
                "(no location found)"
            }
        };

        my ($name, $maybe_prototype)=
          eval { require Sub::Util; 1 } ?
          (Sub::Util::subname($v),
           Sub::Util::prototype($v))
          : ("(for name, install Sub::Util)",
             undef);

        my $prototypestr= defined $maybe_prototype ? "($maybe_prototype) " : "";

        my $dummystr= "DUMMY: $name $location";
        "sub ".$prototypestr."{ ".show($dummystr)." }"
    },
    # Don't really have any sensible serialization for these either,
    # but at least prevent them from hitting Data::Dumper which issues
    # warnings and returns invalid syntax in XS mode and gives plain
    # exceptions in useperl mode:
    IO=> sub {
        my ($v,$show)=@_;
        my $fileno= fileno($v) // "UNKNOWN";
        "IO($fileno)"
    },
    LVALUE=> sub {
        my ($v,$show)=@_;
        "LVALUE(UNKNOWN)"
    },
   };

sub show ($) {
    my ($v)=@_;
    if (length ref($v)) {
        if (my $m= UNIVERSAL::can ($v, "FP_Show_show")) {
            (&$m ($v,*show))[0]
        } elsif ($m= $$primitive_show{ref $v}) {
            (&$m ($v,*show))[0]
        } elsif ($m= $$primitive_show{reftype $v}) {
            # blessed basic type
            my ($str, $includes_blessing)= &$m($v,*show);
            $includes_blessing ? $str
              : "bless($str, " . &show(ref($v)) . ")"
        } else {
            terseDumper($v)
        }
    } else {
        terseDumper($v)
    }
}


sub show_many {
    join(", ", map { show $_ } @_)
}


1
