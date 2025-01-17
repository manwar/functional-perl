#
# Copyright (c) 2003-2014 Christian Jaeger, copying@christianjaeger.ch
#
# This is free software, offered under either the same terms as perl 5
# or the terms of the Artistic License version 2 or the terms of the
# MIT License (Expat version). See the file COPYING.md that came
# bundled with this file.
#

=head1 NAME

Chj::IO::Tempfile

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 NOTES

If you kill the program i.e. using Ctl-C, it will not clean up
its temp file.

=head1 NOTE

This is alpha software! Read the package README.

=cut


package Chj::IO::Tempfile;
use base "Chj::IO::File";
use strict; use warnings; use warnings FATAL => 'uninitialized';
use Fcntl;
use Carp;
use POSIX qw(EEXIST EINTR ENOENT);
use Chj::singlequote ();

our $MAXTRIES=10;
our $DEFAULT_AUTOCLEAN=1; # 0=never unlink automatically, 1= unlink on
                          # destruction, 2= unlink immediately.

my %metadata;
# numified => [ basepath,
#               autoclean,
#               [{hashwithattributes}],
#             ]

sub xtmpfile {
    my $proto=shift;
    my ($maybe_basepath,$mode,$autoclean,$mkdircb)=@_;
    # basepath: /dir/startofname (or: /dir/, but not /dir ),
    #           or a function which receives an autogenerated basepath
    #           and a random number and should return the path to use
    my $genpath= do{
        my $gen_base= sub {
            my ($n)= $0=~ m{(.*[^.]{2,}.*)}; # at least 2 non-"." characters
            $n=~ tr/\//-/;
            "/tmp/$n"
        };
        my $mk_basepath_n= sub {
            my ($basepath)=@_;
            sub {
                my ($n)=@_;
                "$basepath$n"
            }
        };
        if ($maybe_basepath) {
            if (ref ($maybe_basepath) eq 'CODE') {
                my $basepath= &$gen_base;
                sub {
                    my ($n)=@_;
                    &$maybe_basepath($basepath,$n)
                }
            } else {
                &$mk_basepath_n($maybe_basepath)
            }
        } else {
            &$mk_basepath_n(&$gen_base)
        }
    };
    defined $mode or $mode= 0600;
    defined $autoclean or $autoclean=$DEFAULT_AUTOCLEAN;
    my $self;
    my $tries=0;my $called_mkdircb;
  TRY: {
        my $last_path;
        eval {
            $!=0;
            #better today:
            $Chj::IO::ERRNO=0;
            my $rand= int(rand(99999)*100000+rand(99999));
            # ^ XX probably not good enough against DoS or fork
            my $path= &$genpath($rand);
            $last_path=$path;
            #$DB::single=1;
            $self= $proto->xsysopen($path, O_EXCL|O_CREAT|O_RDWR,$mode);
            if ($autoclean==2) {
                unlink $path
                  or croak "xtmpfile: could not unlink ".Chj::singlequote($path).
                    " that we created moments ago ???: $!";
                undef $path;
            }
            $metadata{pack"I",$self}=[&$genpath(""),$autoclean];
        };
        if ($@) {
            if ($Chj::IO::ERRNO==EEXIST or $Chj::IO::ERRNO == EINTR) {
                # ^ not sure whether the latter test is needed
                if (++$tries < $MAXTRIES) {
                    redo TRY;
                } else {
                    croak "xtmpfile: too many attempts to create a ".
                      "tempfile, last attempt was ".
                        Chj::singlequote($last_path);
                }
            } elsif ($Chj::IO::ERRNO== ENOENT and $mkdircb) {
                if ($called_mkdircb) {
                    croak "xtmpfile: got ENOENT but mkdir-callback has ".
                      "already been called, for attempt ".
                        Chj::singlequote($last_path);
                } else {
                    #&$mkdircb;
                    $mkdircb->(&$genpath(""));
                    $called_mkdircb=1;
                    redo TRY;
                }
            } else {
                croak
                  "xtmpfile: could not create tempfile at ".
                    Chj::singlequote($last_path).": $@";
            }
        }
    }
    $self
}

sub autoclean {
    my $self=shift;
    if (@_) { # set
        my ($v)=@_;
        $metadata{pack"I",$self}[1]=$v;
        # should we return former setting? does that really make sense?
    }
    else {
        $metadata{pack"I",$self}[1]
    }
}

# No need to override the xunlink method.

sub xrename {
    my $self=shift;
    $self->SUPER::xrename(@_);
    $metadata{pack"I",$self}[1]=0;
}

# This one is a bit non-sensible, since xlink is enough, unlinkig
# source anyway.
sub xlinkunlink {
    my $self=shift;
    $self->SUPER::xlinkunlink(@_);
    $metadata{pack"I",$self}[1]=0;
}

sub DESTROY {
    my $self=shift;
    local ($@,$!,$?);
    if (defined(my $path= $self->path)) {
        if ($metadata{pack"I",$self}[1] == 1) {
            unlink $path
              or warn "DESTROY: unlink ".$self->quotedname.": $!";
        }
    }
    delete $metadata{pack"I",$self};
    $self->SUPER::DESTROY;
}
        

# (where am I using this?)
sub attribute { # :lvalue does not work because of perl bugs. :-(
    my $self=shift;
    my $key=shift;
    if (@_) {
        ($metadata{pack "I",$self}[2]{$key})=@_
    } else {
        $metadata{pack "I",$self}[2]{$key}
    }
}


sub _xlinkrename {
    my ($from,$to)=@_;# to must be file path, not dir.
    my $tobase=$to; $tobase=~ s{/?([^/]+)\z}{}
      or croak "_xlinkrename: missing to parameter";
    my $toname= $1; $tobase.="/" if length $tobase;
    for (1..10) {
        my $tmppath= "$tobase.$toname.".rand(10000);
        if (link $from, $tmppath) {
            if (rename $tmppath, $to) {
                return;
            } else {
                croak "_xlinkrename: rename ".Chj::singlequote($tmppath).
                  ", ".Chj::singlequote($to).": $!";
            }
        } else {
            if ($! == EEXIST) {
                next;
            } else {
                croak "_xlinkrename: link ".Chj::singlequote($from).
                  ", ".Chj::singlequote($tmppath).": $!";
            }
        }
    }
    croak "_xlinkrename: too many attempts to make a link from ".
      Chj::singlequote($from)." to a random name around ".
          Chj::singlequote($to).": $!";
}


our $warn_all_failures= 1;

sub xreplace_or_withmode {
    my $self=shift;
    my ($targetpath,$orwithmode)=@_;
    # $orwithmode can be an integer, an octal string, or a stat
    # object; in case of a stat object and if running as root, it also
    # keeps uid/gid.
    my $path= $self->xpath;
    my ($uid,$gid,$mode);
    if (($uid,$gid,$mode)=(stat $targetpath)[4,5,2]) {
        my $euid= (stat $path)[4]; # better than $> because of peculiarities
        defined $euid
          or croak "xreplace_or_withmode: ?? can't stat own file ".
            Chj::singlequote($path).": $!";
        if ($euid == 0) {
            $!= undef;
            chown $uid,$gid, $path
              or croak "xreplace_or_withmode: chown ".
                Chj::singlequote($path).": $!";
        } else {
            if ($uid != $euid) {
                carp "xreplace_or_withmode: warning: cannot set owner of ".
                  Chj::singlequote($path)." to $uid since we are not root"
                      if $warn_all_failures;
                $mode &= 0777; # see below
            }
            $!= undef;
            chown $euid,$gid, $path
              or do {
                  # only a warning, ok?
                  carp "xreplace_or_withmode: warning: could not set group of ".
                    Chj::singlequote($path)." to $gid: $!"
                        if $warn_all_failures;
                  $mode &= 0777; # mask off setuid and such stuff. correct?
              };
        }
        # keep backup:
        # we need it atomic, thus link. but a 'replacing link'.
        eval {
            _xlinkrename $targetpath, "$targetpath~"; # make configurable?
            1
        } || do {
            warn "xreplace_or_withmode: warning: could not make backup file: $@"
              if $warn_all_failures;
        }
    } else {
        if (defined $orwithmode) {
            if (ref $orwithmode) {
                # assuming stat object
                $mode= $orwithmode->permissions;
                if ($> == 0) {
                    $!= undef;
                    chown $orwithmode->uid, $orwithmode->gid, $path
                      or croak "xreplace_or_withmode: chown ".
                        Chj::singlequote($path).": $!";
                }
            } else {
                if ($orwithmode=~ /^0/) {
                    $orwithmode= oct $orwithmode;
                    defined($orwithmode)
                      or croak "xreplace_or_withmode: illegal octal ".
                        "withmode value given";
                    # ^ well, never happens when givint numbers not strings
                }
                $mode= $orwithmode; # & 0777; # mask off dito, since we do not know which uid/gid the programmer meant. which is a bug in itself.   wellll , programmer should know what he's doing then, right?
            }
        } else {
            croak "xreplace_or_withmode: error getting target permissions".
              " and no default mode given, stat ".
                Chj::singlequote($targetpath).": $!";
        }
    }
    $!= undef;
    chmod $mode, $path
      or croak "xreplace_or_withmode: chmod ".
        Chj::singlequote($path).": $!";
    $self->xrename($targetpath);
}


sub xputback { # better name?
    my $self=shift;
    my ($maybe_orwithmode)=@_;
    croak "xputback: file ".$self->quotedname." is still open"
      if $self->opened;
    my $basepath= $metadata{pack"I",$self}[0];
    $self->xreplace_or_withmode($basepath, $maybe_orwithmode);
}


sub basepath {
    my $self=shift;
    $metadata{pack"I",$self}[0]
}


1
