#
# Copyright 2014 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

Chj::FP::Predicates

=head1 SYNOPSIS

=head1 DESCRIPTION

Useful as predicates for Chj::Struct field definitions.

=cut


package Chj::FP::Predicates;
@ISA="Exporter"; require Exporter;
@EXPORT=qw(
	      stringP
	      natural0P
	      naturalP
	      boolean01P
	      booleanP
	      hashP
	      arrayP
	      procedureP
	      classP
	 );
@EXPORT_OK=qw();
%EXPORT_TAGS=(all=>[@EXPORT,@EXPORT_OK]);

use strict;

sub stringP ($) {
    not ref ($_[0]) # relax?
}

sub natural0P ($) {
    not ref ($_[0]) # relax?
      and $_[0]=~ /^\d+\z/
}

sub naturalP ($) {
    not ref ($_[0]) # relax?
      and $_[0]=~ /^\d+\z/ and $_[0]
}

# strictly 0 or 1
sub boolean01P ($) {
    not ref ($_[0]) # relax?
      and $_[0]=~ /^[01]\z/
}

# undef, 0, "", or 1
sub booleanP ($) {
    not ref ($_[0]) # relax?
      and (! $_[0]
	   or
	   $_[0] eq "1");
}


sub hashP ($) {
    defined $_[0] and ref ($_[0]) eq "HASH"
}

sub arrayP ($) {
    defined $_[0] and ref ($_[0]) eq "ARRAY"
}

sub procedureP ($) {
    defined $_[0] and ref ($_[0]) eq "CODE"
}

sub classP ($) {
    my ($cl)=@_;
    sub ($) {
	UNIVERSAL::isa ($_[0], $cl);
    }
}


1
