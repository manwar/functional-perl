## Functional programming in Perl 5 for Schemers

(Note: although I do use Scheme as a paragon, the principles are
mostly the same in other strict functional languages like Ocaml; but
not so much in functional-programming-on-Javascript or C# and similar
frameworks, which is why I mention and compare to Scheme explicitely
here. But this page also describes the difficulties in Perl, and this
part should be split into its own "how to" page instead. (Todo: rework
me.))

I feel that the Scheme language approaches functional programming
very nicely. Like Perl, Scheme is not a purely functional language,
and like Perl it is not lazy by default. Both languages have lexical
scoping by default (and dynamic scoping on request, Scheme's
`make-parameter` and `parameterize` corresponding to Perl's `our` and
`local`), and both are providing closures. Thanks to this, translating
the principles used in Scheme to Perl is quite straight-forward,
except that Perl's syntax poses some overheads, and Perl's interpreter
requires some hand-holding to free memory correctly in some
situations.

These are the real differences between Perl and Scheme that concern
functional programs:

- Sigils: Perl has separate namespaces (syntactically distinguished)
for functions, scalars, arrays, hashes. Scheme only has one
namespace. Using only one namespace has the benefit of uniformity;
passing values the same way regardless of their kind is necessary for
generic functions, and references need to be taken in Perl in these
cases. Thus, functional programs will either use reference-taking
syntax like `\@foo`, `\&bar` etc. often, or store references in
scalars from the start (like `my $foo= []`).

- Tail-calls: Scheme guarantees tail-call optimization. This means
that Scheme functions can call other functions in tail position
endlessly whereas Perl will run out of memory due to increasing stack
space used.  But Perl has the `goto \&func` construct which calls func
without allocating a new stack frame; parameters need to be passed by
assigning them to `@_`. With that, tail call optimization is possible,
but instead of the system doing it automatically, it has to be
specified explicitely. Admittedly the syntax for this is ugly; but
thankfully there's already a module that improves on this:
`Sub::Call::Tail`; see
[intro/more_tailcalls](intro/more_tailcalls) for
examples.

- Leak potential: Scheme implementations are usually written with
functional programs in mind and hence take care that they work
transparently in all (usual) cases; Perl not so much. Perl assumes a
style of programming where local scopes are exited quickly and hence
doesn't care to free memory that can't be accessed further down in the
scope anymore. (Retaining it can also be useful for debugging, and
since Perl programs can inspect the stack, they actually *can*
arbitrarily access those values, even if normal programs don't do
that.) This poses a problem with the idiom of lazily generated deeply
nested data structures (like lazily computed linked lists aka
"functional streams"). In those cases, the Perl program has to
explicitely set unused references that remain in the scope to undef or
use WeakRef on the same. In the case of arguments passed to functions,
the called function has to get rid of that reference if necessary by
deleting it from the outer call frame through `@_` (like `undef
$_[1];`) Note that on older versions of Perl deleting references
through `@_` doesn't always work (v5.14.2 is fine, v5.10.1 is not).

    Note: weaken'ed references to closures that return closures
    (e.g. through `lazy`) won't be retained; `my $f=$f;` needs to be
    used before the `lazy` form.

- C stack when freeing: When Perl deallocates nested data structures,
it uses space on the C (not Perl language) stack for the
recursion. When a structure to be freed is nested deeply enough (like
with long linked lists), this will make the interpreter run out of
stack space, which will be reported as a segfault on most
systems. There are two different remedies for this:

    - increase system stack size by changing the corresponding
    resource limit (e.g. see `help ulimit` in Bash.)

    - don't let go of a deeply nested structure at once. Again, this
    is done by letting go of the outer layers (like the head of the
    list) in a timely manner, thus the same solutions as discussed on
    "Leak potential" apply.
