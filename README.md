Check the [functional-perl website](http://functional-perl.org/) for
properly formatted versions of these documents.

---

# Functional programming on Perl

This project aims to provide modules as well as tutorials and
introductionary materials to work in a functional style on Perl 5.

<with_toc>

## Teaser

This is an example of the kind of code this project aims to make possible:

    # Generate functions which construct PXML objects (objects that
    # can be serialized to XML) with the names given her as the XML
    # tag names:
    use PXML::Tags qw(myexample protocol-version records record a b c d);
    # The functions are generated in all-uppercase so as to minimize
    # the chances for naming conflicts and to let them stand apart.

    print RECORD(A("hi"),B("there"))->string; 
    # prints: <record><a>hi</a><b>there</b></record>

    # Now create a bigger document, with its inner parts built from
    # external inputs:
    MYEXAMPLE
      (PROTOCOL_VERSION ("0.123"),
       RECORDS
       (csv_file_to_rows($inpath, {eol=> "\n", sep_char=> ";"})
        # skip the header row
        ->rest
        # map rows to XML elements
        ->map(sub {
                  my ($a,$b,$c,$d)= @{$_[0]};
                  RECORD A($a), B($b), C($c), D($d)
              })))
      # print XML document to disk
      ->xmlfile($outpath);

    # Note that the MYEXAMPLE document above is built lazily:
    # `csv_file_to_rows` returns a *lazy* list of rows, ->rest causes
    # the first CSV row to be read and dropped and returns the
    # remainder of the lazy list, ->map returns a new lazy list which
    # is passed as argument to RECORDS, which returns a PXML object
    # representing a 'records' XML element, that is then passed to
    # MYEXAMPLE which returns a PXML object representing a 'myexample'
    # XML element. PXML objects come with a xmlfile method which
    # serializes the document to a file, and only while it runs, when
    # it encounters the embedded lazy lists, it walks those evaluating
    # the list items one at a time and dropping each item immediately
    # after printing. This means that only one row of the CSV file
    # needs to be held in memory at any given point.

See [examples/csv_to_xml_short](examples/csv_to_xml_short) for the
complete script, and the [examples](examples/README.md) page for more.

The above example shows the use of functions as a "template system".

Note that the example assumes that steps have been taken so that the
CSV file doesn't change until the serialization step has completed,
otherwise functional purity is broken; the responsibility to ensure
this assumption is left to the programmer (see
[[howto#Pure_functions_versus_I/O_and_other_side-effects]] for more
details about this).

If you'd like to see a practical step-by-step introduction, read the
[[intro]].

Even if you're not interested in lazy evaluation like in the above,
this project may help you write parts of programs in a purely
functional way, and benefit from the decreased coupling and improved
testability and debuggability that this brings.


## Status: experimental

There are several reasons that this project should be considered
experimental at this time:

* there are some remaining issues which appear to be in the perl
  interpreter that, in some cases, lead to memory being retained for
  longer than necessary when using lazy lists

* also in the area of lazy lists, the current need in some situations
  to use `Keep` and `weaken` to guide deallocation of list elements is
  unfortunate; ideally the perl interpreter is extended with a pragma
  that, when enabled, makes it automatically let go of unused list
  elements (lexical lifetimes).

* the project is currently using some modules which the author
  developed a long time ago and could be replaced with other existing
  ones from CPAN (e.g. `Chj::xperlfunc`, `Chj::IO::`).

* `FP::Struct` was implemented as a class generator for classes that
  come with functional setters (setters which don't mutate the
  objects, but return modified versions). The author also liked to see
  where a very simple approach may lead to (e.g. use of predicate
  functions for type checking). The aim was to provide a very easy and
  concise way to write classes. This is experimental, and may be
  deprecated in favour of extending existing class generators where
  needed and using them instead.

* the namespaces are not fixed yet (in particular, everything in
  `Chj::` should probably be renamed); also, the interfaces should be
  treated as alpha. More abstract types (like
  `FP::Abstract::Sequence`) should be defined.

* get it working correctly first, then fast: some operations aren't
  efficient yet. There is no functional sequence data structure yet
  that allows efficient random access, and none for functional
  hashmaps with efficient updates, but the author has plans to address
  those. Also the author has plans for implementing mechanisms to make
  chains of sequence operations (like
  `$foo->map($bar)->filter($baz)->drop(10)->reverse->drop(5)`) as
  performant as the imperative equivalent.

There is a lot that still needs to be done, and it depends on the
author or other people be able and willing to invest the time.

(An approach to use this project while avoiding breakage due to future
changes could be to add the
[functional-perl Github repository](https://github.com/pflanze/functional-perl)
as a Git submodule to the project using it and have it access it via
`use lib`. Tell if you'd like to see stable branches of older versions
with fixes.)


## Parts

* `FP::Struct`: a class generator that creates
  functional setters and accepts predicate functions for type checking
  (for the reasoning see the [[howto#Object_oriented_functional_programming]])

* [lib/FP/](lib/FP/): a library of pure functions and
  functional data structures, including various sequences (pure
  arrays, linked lists and lazy streams).

* the "PXML" [functional XML](functional_XML/README.md) "templating
  system" for XML based markup languages by way of Perl
  functions.

* some developer utilities: `FP::Repl`, `Chj::ruse`, `Chj::Backtrace`,
  `FP::Repl::Trap`.

* [lib/Chj/IO/](lib/Chj/IO/), and its users/wrappers
  `Chj::xopen`,
  `Chj::xopendir`,
  `Chj::xoutpipe`,
  `Chj::xpipe`,
  `Chj::xtmpfile`:
  operations on filehandles that throw exceptions on errors by
  default, plus many utilities.
  I wrote these around 15 years ago, as a means to offer IO with
  exceptions and more features, but in the mean time alternatives have
  been grown that are probably just as good or better. Do you know
  which replacements this project should be using?

* a few more modules that are used by the above (some originally part
  of [chj-perllib](https://github.com/pflanze/chj-perllib))

* [Htmlgen](htmlgen/README.md), the tool used to generate this
  website, built using the above.


## Documentation

It probably makes sense to look through the docs roughly in the given
order, but if you can't follow the presentation, skip to the intro,
likewise if you're bored skip ahead to the examples and the
howto/design documents.

* [__Introduction to using the functional-perl modules__](//intro.md)

    This is the latest documentation addition (thus has the best
    chance of being up to date), and is aiming to give a pretty
    comprehensive overview which doesn't require you to read the other
    docs first. Some of the info here is duplicated (in more detail)
    in the other documents. If this is too long, take a look at the
    presentation below or the example scripts.

* [__Presentation__](http://functional-perl.org/london.pm-talk/)

    These are the slides of an introductory presentation, but there's
    no recording and the slides may not be saying enough for
    understanding. It's also somewhat outdated.

* [__Intro directory__](intro/)

    The `intro` directory contains scripts introducing the concepts,
    including the basics of functional programming (work in
    progress). The scripts are meant to be viewed in this order:

    1. [basics](intro/basics)
    1. [tailcalls](intro/tailcalls)
    1. [more_tailcalls](intro/more_tailcalls)

    This doesn't go very far yet (todo: add more). Also, please note
    that `Sub::Call::Tail` is currently broken with newer Perl
    versions (todo: look into fixing it or whether it is possible to
    imlement it in a simpler manner).

* [__Examples__](examples/README.md)

    The `examples` directory contains scripts showing off the
    possibilities. You will probably not understand everything just
    from looking at these, but they will give an impression.

* __Our howto and design documents__

    * *[How to write functional programs on Perl 5](docs/howto.md)* is
      describing the necessary techniques to use the functional style on
      Perl. (Todo: this may be too difficult for someone who doesn't know
      anything about functional programming; what to do about it?)

    * *[The design principles used in the functional-perl
      library](docs/design.md)* is descibing the organization and ideas
      behind the code that the functional-perl project offers.

* __Book__

    If you need a more gentle introduction into the ideas behind
    functional programming, you may find it in *[Higher-Order
    Perl](http://hop.perl.plover.com/)* by Mark Jason Dominus.  This book
    was written long before the functional-perl project was started, and
    does various details differently.

Please ask [me](http://leafpair.com/contact) or on the
[[mailing_list]] if you'd like to meet up in London, Berlin or
Switzerland to get an introduction in person.


## Dependencies

* to use `bin/repl` or the repl in the intro and examples scripts
  interactively, `Term::ReadLine::Gnu` and `PadWalker` (and optionally
  `Eval::WithLexicals` if you want to use the :m/:M modes, and
  `Capture::Tiny` to see code definition location information and
  `Sub::Util` to see function names when displaying code refs.)

* to run the test suite: `Test::Requires`

* to run all the tests (otherwise some are skipped): in addition to
  the above, `Test::Pod::Snippets`, `BSD::Resource`,
  `Method::Signatures`, `Function::Parameters`, `Sub::Call::Tail`,
  `Text::CSV`, `DBD::CSV`, `Text::CSV`, `URI`, `Text::Markdown`,
  `Clone`. Some of these are also necessary to run `htmlgen/gen` (or
  `website/gen` to build the website), see
  [Htmlgen](htmlgen/README.md) for details.

(Todo: should all of the above be listed in PREREQ_PM in Makefile.PL?)


## Installation

    git clone https://github.com/pflanze/functional-perl.git
    cd functional-perl

    # to get the latest release, which is $FP_COMMITS_DIFFERENCE behind master:
    git checkout -b $FP_VERSION_UNDERSCORES $FP_VERSION

    # to verify the same against MitM attacks:
    gpg --recv-key 04EDB072
    git tag -v $FP_VERSION
    # You'll find various pages in search engines with my fingerprint,
    # or you may find a trust chain through one of the signatures on my
    # older key 1FE692DA, that this one is signed with.

The bundled scripts modify the library load path to find the files
locally, thus no installation is necessary. All modules are in the
`lib/` directory, `export PERL5LIB=path/to/functional-perl/lib` is all
that's needed.

The normal `perl Makefile.PL; make test && make install` process
should work as well. The repository is probably going to be split into
or will produce several separate CPAN packages in the future, thus
don't rely on the installation process working the way it is right
now.


</with_toc>
