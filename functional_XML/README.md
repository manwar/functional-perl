(Check the [functional-perl website](http://functional-perl.org/) for
properly formatted versions of these documents.)

---

# Functional XML (and HTML, SVG, ..) generation

PXML intends to be a simple, Perl based representation for XML, or at
least the subset that's necessary for doing most tasks. Currently it
doesn't support XML namespaces properly (manually prefixing element
names may be a workable solution, though?). It is meant to *produce*
XML output; handling parsed XML is out of the current scope. 

Its in-memory representation are `PXML` objects. Serialization to
file handles is done using procedures from
`PXML::Serialize`. 

The body of elements can be a mix of standard Perl arrays, linked
lists based on `FP::List`, and promises (`FP::Lazy`) which
allows for the generation of streaming output.

Direct creation of XML elements:

    use PXML;
    my $element= PXML->new("a", {href=> "http://myserver.com"}, ["my server"]);

Using 'tag functions' for shorter code:

    use PXML::XHTML;
    my $element= A({href=> "http://myserver.com"}, "my server");

See [`test`](test) and [`testlazy`](testlazy) for complete examples,
and [`examples/csv2xml`](../examples/csv2xml) for a simple real
example, and [`htmlgen/gen`](../htmlgen/gen) for a somewhat real-world
program.


When generating HTML, CGI.pm's tag functions seem similar, what are
the differences?

 - PXML::XHTML chooses upper-case constructor names to reduce the
   chances for conflicts; for example using "tr" for <TR></TR>
   conflicts with the tr builtin Perl operator.

 - CGI.pm's creators return strings, whereas PXML::XHTML returns
   PXML objects. The former might have O(n^2) complexity with the
   size of documents (getting slower to concatenate big strings),
   while the latter should have constant overhead. Also, PXML can be
   inspected after creation, an option not possible with CGI.pm
   (without using an XML parser).

 - PXML::XHTML / PXML serialization always escape strings, hence
   is safe against XSS, while CGI.pm does/is not.

 - PXML::XHTML / PXML chose not to support dashes on attributes,
   like `{-href=> "foo"}`, as the author feels that this is unnecessary
   clutter both for the eyes and for the programmer wanting to access
   attributes from such hashes, and added complexity/runtime cost for
   the serializer.
