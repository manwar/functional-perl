#
# Copyright (c) 2015 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

Chj::Destructor

=head1 SYNOPSIS

    use Chj::Destructor;

    my $z=0;
    {
       my $x= ["foo", Destructor { $z++ }];
    }
    is $z, 1;


=head1 DESCRIPTION

Util to help debug or test memory deallocation.

=head1 SEE ALSO

End.pm, but that one does not type-check the destructor argument
early, nor does it localize error variables in its DESTROY method.

=head1 NOTE

This is alpha software! Read the package README.

=cut


package Chj::Destructor;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(Destructor);
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';

{
    package Chj::Destructor::_;
    use FP::Predicates ":all";
    use FP::Struct [[*is_procedure, "thunk"]];
    sub DESTROY {
        my ($self)=@_;
        local ($@,$!,$?,$^E,$.);
        $self->thunk->()
    }
    _END_
}

sub Destructor (&) {
    Chj::Destructor::_->new ($_[0])
}

use Chj::TEST;

TEST {
    my $z=0;
    {
        my $x= ["foo", Destructor { $z++ }];
    }
    $z
} 1;


1
