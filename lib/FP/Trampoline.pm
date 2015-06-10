#
# Copyright 2015 by Christian Jaeger, ch at christianjaeger ch
# This is free software, offered under the terms of the MIT License.
# See the file COPYING that came bundled with this file.
#

=head1 NAME

FP::Trampoline -- tail call optimization without reliance on goto

=head1 SYNOPSIS

 use FP::Trampoline; # exports `T` and `trampoline`

 sub iterative_fact {
     my ($n,$tot)= @_;
     $n > 1 ? T{ iterative_fact ($n-1, $tot*$n) } : $tot
     # or
     # $n > 1 ? TC *iterative_fact, $n-1, $tot*$n : $tot
 }
 sub fact {
     my ($n)=@_;
     trampoline iterative_fact ($n, 1)
 }

=head1 DESCRIPTION

Perl has direct support for optimized (i.e. non-stack-eating) tail
calls, by way of `goto $subref`, but there are still bugs in current
versions of Perl with regards to memory handling in certain situations
(see L<t/perl/goto-leak>). Trampolining is a technique that works
without reliance on any tail call optimization support by the host
language. Its drawbacks are more overhead and the requirement to put a
`trampoline`ing call around any function that employs trampolining.

=head1 FUNCTIONS

=item T { ... }

Returns a closure blessed into the `FP::Trampoline::Continuation`
namespace, which represents a trampolining continuation.

=item TC $fn, $arg1...

Returns a `FP::Trampoline::Call` object, which represents the same
thing, but can only be used for a call ('Trampoline Call'). The
advantage is that the arguments for the call are evaluated eagerly,
which makes it work for dynamic variables, too (like `$_` or
local'ized globals).

=item trampoline ($value)

The trampoline that bounces back as long as it receives a trampolining
continuation: if so, the continuation is run, and the result passed to
the `trampoline` again, otherwise it is returned directly.

=cut


package FP::Trampoline;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(T TC trampoline);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings FATAL => 'uninitialized';

sub T (&) {
    bless $_[0], "FP::Trampoline::Continuation"
}

sub TC {
    bless [@_], "FP::Trampoline::Call"
}

sub trampoline ($) {
    my ($v)=@_;
    @_=(); # so that calling a continuation does not need () (possible
           # speedup)
    while (1) {
	if (my $r= ref $v) {
	    $v=
	      ($r eq "FP::Trampoline::Continuation" ? &$v
	       : $r eq "FP::Trampoline::Call" ? do {
		   $$v[0]->(@$v[1..$#$v])
	       }
	       : return $v);
	} else {
	    return $v
	}
    }
}

1