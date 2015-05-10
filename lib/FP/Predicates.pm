#
# Copyright 2014-2015 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

FP::Predicates

=head1 SYNOPSIS

=head1 DESCRIPTION

Useful as predicates for FP::Struct field definitions.

=cut


package FP::Predicates;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(
	      is_string
	      is_nonnullstring
	      is_natural0
	      is_natural
	      is_even is_odd
	      is_boolean01
	      is_boolean
	      is_hash
	      is_array
	      is_procedure
	      is_class_name
	      is_instance_of

	      is_filename

	      maybe
	      true
	      false
	      complement
	      either
	      all_of both
	 );
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict; use warnings; use warnings FATAL => 'uninitialized';
use Chj::TEST;

sub is_string ($) {
    not ref ($_[0]) # relax?
}

sub is_nonnullstring ($) {
    not ref ($_[0]) # relax?
      and length $_[0]
}

sub is_natural0 ($) {
    not ref ($_[0]) # relax?
      and $_[0]=~ /^\d+\z/
}

sub is_natural ($) {
    not ref ($_[0]) # relax?
      and $_[0]=~ /^\d+\z/ and $_[0]
}

sub is_even ($) {
    ($_[0] & 1) == 0
}

sub is_odd ($) {
    ($_[0] & 1)
}

TEST { [map { is_even $_ } -3..3] }
  ['',1,'',1,'',1,''];
TEST { [map { is_odd $_ } -3..3] }
  [1,0,1,0,1,0,1];
TEST { [map { is_even $_ } 3,3.1,4,4.1,-4.1] }
  # XXX what should it give?
  ['','',1,1,1];


# strictly 0 or 1
sub is_boolean01 ($) {
    not ref ($_[0]) # relax?
      and $_[0]=~ /^[01]\z/
}

# undef, 0, "", or 1
sub is_boolean ($) {
    not ref ($_[0]) # relax?
      and (! $_[0]
	   or
	   $_[0] eq "1");
}


sub is_hash ($) {
    defined $_[0] and ref ($_[0]) eq "HASH"
}

sub is_array ($) {
    defined $_[0] and ref ($_[0]) eq "ARRAY"
}

sub is_procedure ($) {
    defined $_[0] and ref ($_[0]) eq "CODE"
}


my $classpart_re= qr/\w+/;

sub is_class_name ($) {
    my ($v)= @_;
    not ref ($v) and $v=~ /^(?:${classpart_re}::)*$classpart_re\z/;
}

sub is_instance_of ($) {
    my ($cl)=@_;
    is_class_name $cl or die "need class name string, got: $cl";
    sub ($) {
	UNIVERSAL::isa ($_[0], $cl);
    }
}


# should probably be in a filesystem lib instead?
sub is_filename ($) {
    my ($v)=@_;
    (is_nonnullstring ($v)
     and !($v=~ m|/|)
     and !($v eq ".")
     and !($v eq ".."))
}

sub maybe ($) {
    my ($pred)=@_;
    sub ($) {
	my ($v)=@_;
	defined $v ? &$pred ($v) : 1
    }
}


sub true {
    1
}

sub false {
    0
}

sub complement ($) {
    my ($f)=@_;
    sub {
	! &$f(@_)
    }
}

TEST {
    my $t= complement (\&is_natural);
    [map { &$t($_) } (-1,0,1,2,"foo")]
} [1,1,'','',1];


sub either {
    my (@fn)=@_;
    sub {
	for my $fn (@fn) {
	    my $v= &$fn;
	    return $v if $v;
	}
	0
    }
}

TEST {
    my $t= either \&is_natural, \&is_boolean;
    [map { &$t($_) } (-1,0,1,2,"foo")]
} [0,1,1,2,0];


sub all_of {
    my (@fn)=@_;
    sub {
	for my $fn (@fn) {
	    return undef unless &$fn;
	}
	1
    }
}

sub both ($$) {
    @_==2 or die "expecting 2 arguments";
    all_of (@_)
}


1