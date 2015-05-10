#
# Copyright 2013-2015 by Christian Jaeger, ch at christianjaeger ch
# Published under the same terms as perl itself
#

=head1 NAME

PXML::XHTML

=head1 SYNOPSIS

=head1 DESCRIPTION


=cut


package PXML::XHTML;
@ISA="Exporter"; require Exporter;

use strict; use warnings; use warnings FATAL => 'uninitialized';

use PXML;

our $nbsp= "\xa0";

our $tags=
     [
          'a',
          'abbr',
          'acronym',
          'address',
          'applet',
          'area',
          'b',
          'base',
          'basefont',
          'bdo',
          'big',
          'blockquote',
          'body',
          'br',
          'button',
          'caption',
          'center',
          'cite',
          'code',
          'col',
          'colgroup',
          'dd',
          'del',
          'dfn',
          'dir',
          'div',
          'dl',
          'dt',
          'em',
          'fieldset',
          'font',
          'form',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
          'head',
          'hr',
          'html',
          'i',
          'iframe',
          'img',
          'input',
          'ins',
          'isindex',
          'kbd',
          'label',
          'legend',
          'li',
          'link',
          'map',
          'menu',
          'meta',
          'noframes',
          'noscript',
          'object',
          'ol',
          'optgroup',
          'option',
          'p',
          'param',
          'pre',
          'q',
          's',
          'samp',
          'script',
          'select',
          'small',
          'span',
          'strike',
          'strong',
          'style',
          'sub',
          'sup',
          'table',
          'tbody',
          'td',
          'textarea',
          'tfoot',
          'th',
          'thead',
          'title',
          'tr',
          'tt',
          'u',
          'ul',
          'var'
     ];

our $funcs=
  [
   map {
       my $tag=$_;
       [
	uc $tag,
	sub {
	    my $atts= ref($_[0]) eq "HASH" ? shift : undef;
	    PXML::PXHTML->new($tag, $atts, [@_]);
	}
       ]
   } @$tags
  ];

for (@$funcs) {
    my ($name, $fn)=@$_;
    no strict 'refs';
    *{"PXML::XHTML::$name"}= $fn
}

our @EXPORT_OK= ('$nbsp', map { $$_[0] } @$funcs);
our %EXPORT_TAGS=(all=>\@EXPORT_OK);

{
    package PXML::PXHTML;
    our @ISA= "PXML";
    # serialize to HTML5 compatible representation:
    sub require_printing_nonvoid_elements_nonselfreferential  {
	1
    }
    use PXML::HTML5 '$html5_void_element_h';
    sub void_element_h {
	$html5_void_element_h
    }
}


1