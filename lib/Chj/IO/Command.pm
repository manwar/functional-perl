#
# Copyright (c) 2007-2015 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

Chj::IO::Command

=head1 SYNOPSIS

 use Chj::IO::Command;
 # my $mail= Chj::IO::Command->new_out("sendmail","-t");  or:
 # my $mail= Chj::IO::Command->new_writer("sendmail","-t"); or:
 my $mail= Chj::IO::Command->new_receiver("sendmail","-t");
 warn "sendmail has pid ".$mail->pid;
 $mail->xprint("From:..\nTo:..\n\n...");
 my $exitcode= $mail->xfinish;
 # my $date= Chj::IO::Command->new_in("date")->xcontent;
 # my $date= Chj::IO::Command->new_reader("date")->xcontent;
 my $date= Chj::IO::Command->new_sender("date")->xcontent;
 # there's also ->new_err, which allows to gather errors

 # or catch stdout and stderr both together:
 my $str= Chj::IO::Command->new_combinedsender("foo","bar","baz")->xcontent;


=head1 DESCRIPTION

Launches external commands with input or output pipes.
Inherits from Chj::IO::Pipe.

There is no support for multiple pipes to the same process.

=head1 NOTE

'new_in' does mean input from the view of the main process. May be a
bit confusing, since it's stdout of the subprocess. Same thing for
'new_out'.  Maybe the aliases 'new_reader' and 'new_writer' are a bit
less confusing (true?).

=head1 SEE ALSO

L<Chj::IO::CommandBidirectional>, L<Chj::IO::CommandCommon>, L<Chj::IO::Pipe>,
L<Chj::IO::CommandStandalone>

=head1 NOTE

This is alpha software! Read the package README.

=cut


package Chj::IO::Command;

use strict; use warnings; use warnings FATAL => 'uninitialized';

use base qw(
            Chj::IO::CommandCommon
            Chj::IO::Pipe
            IO
           );
sub import {};

use Chj::xpipe;


sub new_out {
    my $class=shift;
    local $^F=0;
    my ($r,$self)=xpipe;
    bless $self,$class;
    $self->xlaunch($r,0,@_); ## und wie gebe ich den Namen an?
    # goto form: würd hier auch nix helfen da oben hard codiert. EBEN: ich brauch ein
    # croak das den Ort der Herkunft anzeigen kann. à la mein DEBUG().
}
*new_writer= *new_out;
*new_write= *new_out;
*new_receiver= *new_out;

sub new_in {
    my $class=shift;
    local $^F=0;
    my ($self,$w)=xpipe;
    bless $self,$class;
    $self->xlaunch($w,1,@_);
}
*new_reader= *new_in;
*new_read= *new_in;
*new_sender= *new_in;

sub new_combinedsender {
    my $class=shift;
    local $^F=0;
    my ($self,$w)=xpipe;
    bless $self,$class;
    $self->xlaunch3(undef,$w,$w,@_);
}

sub new_combinedsender_with_stdin {
    my $class=shift;
    local $^F=0;
    my $stdin= shift;
    my ($self,$w)=xpipe;
    bless $self,$class;
    $self->xlaunch3($stdin,$w,$w,@_);
}

sub assume_with_maybe_stdin_stdout_stderr {
    my $class=shift;
    @_>4 or die "not enough arguments";
    my $self=shift;
    my $in= shift;
    my $out= shift;
    my $err= shift;
    local $^F=0;
    bless $self,$class;
    $self->xlaunch3($in,$out,$err,@_);
}

sub new_err {
    my $class=shift;
    local $^F=0;
    my ($self,$w)=xpipe;
    bless $self,$class;
    $self->xlaunch($w,2,@_);
}

sub new_receiver_with_stderr_to_fh {
    my $class=shift;
    my $errfh=shift;
    local $^F=0;
    my ($r,$self)=xpipe;
    bless $self,$class;
    $self->xlaunch3($r,undef,$errfh,@_); ## ... (vgl oben)
}

sub new_receiver_with_stdout_to_fh {
    my $class=shift;
    my $outfh=shift;
    local $^F=0;
    my ($r,$self)=xpipe;
    bless $self,$class;
    $self->xlaunch3($r,$outfh,undef,@_);
}

1
