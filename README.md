# Functional programming on Perl 5

This project aims to provide modules as well as tutorials and
introductionary materials and other knowledge to work in a functional
style on Perl.

## Status: experimental

The project should not be used for production code yet for the
following reasons:

* the chosen namespaces and interfaces are still in flux; it hasn't
  been released to CPAN yet for this reason

* some modules may be replaced with other more widely used ones in the
  interest of keeping with the common base

* tutorials are not complete yet, and less experienced Perl
  programmers will have difficulties writing or debugging code in this
  style on Perl without proper introduction

* some problems in the perl interpreter leading to memory leaks or
  retention issues when using this style have only been fixed
  recently, and some more exotic ones are still waiting to be fixed

We welcome anyone interested to play with the code, ask
questions, provide feedback, and perhaps contribute examples, ideas or
teaching materials.  We are also hoping to work with interested core
perl developers on fixing the remaining issues in the interpreter.

Please send [me](http://leafpair.com/contact) your suggestions!


## Parts

* [FP::Struct](lib/FP/Struct.pm): a class generator that creates
  functional setters and takes predicate functions for type checking

* [lib/FP/](lib/FP/): library of pure functions and
  functional data structures

* [PXML](lib/PXML.pm),
  [PXML::XHTML](lib/PXML/XHTML.pm),
  [PXML::HTML5](lib/PXML/HTML5.pm),
  [PXML::SVG](lib/PXML/SVG.pm),
  [PXML::Tags](lib/PXML/Tags.pm),
  [PXML::Serialize](lib/PXML/Serialize.pm):
  "templating system" for XML based markup languages by way of Perl
  functions. Docs and tests are in [ftemplate/](ftemplate/).

* some developer utilities: [Chj::repl](lib/Chj/repl.pm),
  [Chj::ruse](lib/Chj/ruse.pm), [Chj::Backtrace](lib/Chj/Backtrace.pm)

* [lib/Chj/IO/](lib/Chj/IO/), and its users/wrappers
  [Chj::xopen](lib/Chj/xopen.pm),
  [Chj::xopendir](lib/Chj/xopendir.pm),
  [Chj::xoutpipe](lib/Chj/xoutpipe.pm),
  [Chj::xpipe](lib/Chj/xpipe.pm),
  [Chj::xtmpfile](lib/Chj/xtmpfile.pm):
  operations on filehandles that throw exceptions on errors, plus
  many utilities.
  Should probably be dropped in favor of something else, suggestions
  welcome.

* a few more modules that are used by the above (some originally part
  of [chj-perllib](https://github.com/pflanze/chj-perllib))


## Documentation

### How to program functionally in Perl 5

This needs a separate "how to" page; for now, see [howto and
comparison to Scheme](docs/howto_and_comparison_to_Scheme.md).

### Presentation

[These](http://functional-perl.org/london.pm-talk/) are the slides of
a presentation and is a better introduction and doesn't talk about
Scheme, but there's no recording and the slides may not be saying
enough for understanding. (Todo: rewrite into a tutorial.)

### Intro

The [intro](intro/) directory contains scripts introducing the
concepts, including the basics of functional programming (work in
progress). The scripts are meant to be viewed in this order:

1. [basics](intro/basics)
1. [tailcalls](intro/tailcalls)
1. [more_tailcalls](intro/more_tailcalls)

### Examples

The [examples](examples/) directory contains scripts showing off the
possibilities.


## Installation

For simplicity during development there are no installer instructions,
instead the bundled scripts modify the library load path to find the
files locally. All modules are in `lib/`, `use lib` that path is all
that's needed. (Just tell if you would like installer support.)

## Dependencies

* to run the test suite: `Test::Requires`

* to run all the tests (otherwise some are skipped):
  `BSD::Resource`, `Method::Signatures`, `Text::CSV`, `URI`

* to use `bin/repl` interactively, `Term::ReadLine::Gnu`

* to use nicer syntax for tail call optimization: `Sub::Call::Tail`


## See also

* For a real program using these modules, see
  [ml2json](http://ml2json.christianjaeger.ch).

* A [post](https://news.ycombinator.com/item?id=8734719) about streams
  in Scheme mentioning the memory retention issues that even some
  Scheme implementations can have.
