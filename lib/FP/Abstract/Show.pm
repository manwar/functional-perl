#
# Copyright (c) 2019 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

FP::Abstract::Show - equality protocol

=head1 SYNOPSIS

 package FPShowExample::Foo {
     sub new { my $class= shift; bless [@_], $class }
     sub FP_Show_show {
         my ($self, $show)=@_;
         # $show is for recursive use
         "FPShowExample::Foo->new(".join(", ",
              map { $show->($_) } @$self).")"
     }
 }

 use FP::Show;

 is show(FPShowExample::Foo->new("hey", new FPShowExample::Foo 5+5)),
    "FPShowExample::Foo->new('hey', FPShowExample::Foo->new(10))";

=head1 DESCRIPTION

For an introduction, see L<FP::Show>.

The reason that `FP_Show_show` is getting a `$show` argument is to
provide for (probably evil, though) context sensitive formatting, but
more importantly to hopefully enable to do pretty-printing and cut-off
features (this is *alpha* though, see whether this works out).


=head1 TODO

Handle circular data structures.

Pretty-printing

Declare that non-pretty-printing show must only print one line?

Cut-offs at configurable size

Configuration for whether to force promises

=head1 SEE ALSO

L<FP::Show>

=head1 NOTE

This is alpha software! Read the package README.

=cut


package FP::Abstract::Show;

use strict; use warnings; use warnings FATAL => 'uninitialized';

sub fp_interface_method_names {
    ("FP_Show_show")
}


1
