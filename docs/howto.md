(Check the [functional-perl website](http://functional-perl.org/) for
properly formatted versions of these documents.)

---

# How to write functional programs on Perl 5

Perl 5 was not designed to write programs in a functional style. Yes,
there are closures, and there are the `map` and `grep` builtins as
kind-of higher-order functions for the builtin 'lists', but that's
where it ends. Quite a bit (for example functional data structures
like linked lists) can be implemented as plain old Perl code
straightforwardly, or so it seems at first. But the somewhat bad news
is that some of the idioms of functional programming require special
attention on behalf of the programmer to get working reliably. The
good news is that, once you understand the shortcomings and
workarounds, it's possible, and after some practising it might become
part of the set of workarounds that become second nature. Still
perhaps it will be possible to change the perl interpreter or write
lowlevel modules to make some of the workarounds unnecessary.

Note that most programming language implementations which were not
designed for functional programming have some of the same problems;
sometimes they lead implementors of functional programming libraries
to avoid certain functional idioms, for example by building `map`
etc. on top of iterators (an imperative idiom). These may be good (and
will be performant) workarounds, but that also means that only these
higher levels are functional (and perhaps sometimes only appear to be
so and might be leaky abstractions?). For example, it might not be
possible to define streams in a functional ("Haskell style") way (like
in [`examples/fibs`](../examples/fibs)).  In Perl it's possible, and
perhaps it will even become easier in the future.

(Sequences functionality based on iterators is still something this
project could look into as well. But that should be understood as an
optimization. Alternative optimizations are possible, and may be
preferrable (e.g. the Haskell compiler applies various other
optimizations to achieve performance without manually written code
using iterators).)


<with_toc>

## Values, syntactical matters

### References and mutation, "variables" versus "bindings"

Pure functions never mutate their arguments, which is why it is never
necessary to create copies before passing things into such functions. Which
means, in Perl terms, it is fine (and more efficient) to always pass
references (this is what implementations for functional languages
generally do). It probably won't be (much of) a benefit to pass
references to elementary values such as strings and numbers, which is
why the functional-perl project generally doesn't do so; but it
generally assumes that arrays are passed as references. The reason for
this is also so that functions can be properly generic: all sorts of
values should be passed the same way, syntactically: regardless
whether an argument is a subroutine (other function), array, hash,
string, number, object, if it is always stored in a scalar (as a
reference in the case of arrays and hashes) then the type doesn't
matter. Genericism is important for reusability / composability.

Another thing to realize is that, in a purely functional (part of a)
program, variables are never mutated. Fresh instances of variables are
*bound* (re-initialized) to new values, but never mutated
afterwards. This means there's no use thinking of variables as
containers that can change; the same (instance of a) container always
only ever gets one value. This is why functional languages tend to use
the term "binding" instead of "variable": it's just giving a value a
name, i.e. binding a name to it. So, instead of this code:

    my @a;
    push @a, 1;
    push @a, 2;
    # ...

which treats the variable @a as a mutable container, a functional
program instead does:

    my $a= [];
    {
        my $a= [@$a, 1];
        {
            my $a= [@$a, 2];
            # ...
        }
    }

where no variable is ever mutated, but just new instances are created
(which will usually happen in a (recursive) function call instead of
the above written-out tree), and in fact not even the array itself is
being mutated, but a new one is created each time; the latter is not
efficient for big arrays (the larger they get, the longer it takes to
copy the old one into the new one), which is where linked lists come
in as an alternative (discussed in other places in this project).

But, realize that we're talking about two different places (levels)
where mutations can happen: the variable itself, and the array data
structure. In `@a` the variable as the container and the array data
structure are "the same", but we can also write:

    my $a= [];
    push @$a, 1;
    push @$a, 2;

In this case, we mutate the array data structure, but not the variable
(or binding) `$a`. In impure functional languages like Scheme or
ML/Ocaml, the above is allowed and a common way of doing things
imperatively: not the variables are mutated, but the object that they
denote (similar to how you're doing things on objects in Perl; this
just makes arrays and hashes treated the same way as other objects).
(ML/Ocaml also provides boxes, for the case where one wants to mutate
a variable; it separates the binding from the box; versus Perl where
every binding is a box at the same time. By separating those concerns,
ML/Ocaml is explicit when the box semantics are to be used. The type
checker in ML/Ocaml will also verify that only boxes are mutated, it
won't allow mutation on normal bindings. We don't have that checker in
Perl, but we can still restrain ourselves to only use the binding
functionality. Scheme does offer `set!` to mutate bindings,
i.e. conflates binding and boxing the same way Perl does, but using
`set!` is generally discouraged. One can search Scheme code for the
"!" character in identifiers and find the exceptional, dangerous,
places where they are used. Sadly in Perl "=" is used both for the
initial binding, as well as for subsequent mutations, but it's still
syntactically visible which one it is (missing `my` (or `our`)
keyword).)

It is advisable to use this latter approach when working with impure
sub-parts in code that's otherwise functional, as it still treats all
data types uniformly when it comes to passing them on, and hence can
profit from the reusability that generic functions provide.

### Identifier namespaces

Most functional programming languages (and newer programming languages
in general) have only one namespace for runtime identifiers (many have
another one for types, but that's out of scope for us as we don't have
a compile time type system (other than the syntactical one that knows
about `@`, `%`, and `&` or sigil-less and perhaps `*`)).  Which means
that variables (bindings) for functions are not syntactically
different from variables (bindings) for other kinds of values. Common
lisp has two name spaces, functions and other values; Scheme did away
with that and uses one for both. Perl has not only these, but also the
arrays and hashes etc. Usually, this kind of "compile time typing" by
way of syntactical identifier differences is called namespaces. Common
lisp is a Lisp-2, Scheme a Lisp-1. Ocaml, Haskell, Python, Ruby,
JavaScript are all using 1 namespace (XX what about methods?).

Using 1 namespace is especially nice when writing functional programs,
so that one can pass variables as arguments exactly the same,
regardless of type (basically this is all the same as already
discussed in the section above).

It would be possible to really only use one namespace in Perl, too
(scalars), and write functions like so, even when they are global
(`array_map` can be found in `FP::Array`):

    our $square= sub {
        my ($a)=@_;
        $a * $a
    };

    my $inputs= [ 1,2,3 ];

    my $results= array_map $square, $inputs;

This is nicely uniform, but perhaps a tad impractical. Perl
programmers have gotten used to defining local functions with `my
$foo= sub ..`, but are used to using Perl's subroutine (CODE)
namespace for global functions; we don't think pushing to a single
namespace would make enough sense.

But this means that the above becomes:

    sub square {
        my ($a)=@_;
        $a * $a
    }

    my $inputs= [ 1,2,3 ];

    my $results= array_map \&square, $inputs;

or

    my $results= array_map *square, $inputs;

or

    my @inputs= ( 1,2,3 );

    my $results= array_map \&square, \@inputs;

or then still

    my $results= array_map *square, \@inputs;


(Pick your favorite? Should we give a recommendation?)


## Memory handling

The second pain, or at least inconveniencing, point with regards to
functional programming on Perl is to get programs to handle memory
correctly. Functional programming languages usually use tracing
garbage collection, and have compilers that do live time analysis of
variables, and optimize tail calls by default (although some like
Clojure don't do the latter), the sum of which mostly does away with
concerning about memory. Perl offers none of these three features. It
still does provide all the features to handle these issues manually,
though.

// -- TODO^ vs -v ?

There are several potential challenges with memory when using Perl,
which are exacerbated by some kinds of functional programs.

### Reference cycles (and self-referential closures)

This is the classic issue with a system like Perl that uses reference
counting to determine when the last reference to a piece of data is
let go. Add a reference to the data structure to itself, and it will
never be freed. The leaked data structures are never reclaimed before
the exit of the process (or at least the perl interpreter) as they are
not reachable anymore (by normal programs).

The solution is to strategically weaken a reference in the cycle
(usually the cyclic reference that's put inside the structure itself),
using `Scalar::Utils`'s `weaken`. `FP::Weak` also has `Weakened` which
is often handy, and `Keep` to protect a reference from such weakening
attacks in case it's warranted.

The most frequent case using reference cycles in functional programs
are self-referential closures:

    sub foo {
        my ($start)=@_;
        my $x = calculate_x;
        my $rec; $rec= sub {
            my ($y)= @_;
            is_bar $y ? $y : cons $y, &$rec(barify_a_bit_with $y, $x)
        };
        &{Weakened $rec} ($start)
    }

Without the `Weakened` call, this would leak the closure at $rec.

Note that alternative, and often better, solutions for
self-referential closures exist: `FP::fix`, and `_SUB_` from `use
v5.16`. Also, sometimes (well, always when one is fine with passing
all the context explicitely) a local subroutine can be moved to the
toplevel and bound to normal subroutine package variables, which makes
it visible to itself by default.


### Variable life times

Lexical variables in the current implementation of the perl
interpreter live until the scope in which they are defined is
exited. Note explicitely that this means they may still reference
their data even at points of the code from which on they will never be
used anymore. Example:

    {
        my $s = ["Hello"];
        print $$s[0], "\n";
        main_event_loop(); # the array remains allocated till the event
                           # loop return, even though never (normally)
                           # accessible
    }

You may ask why you should care about a little data staying
around. The first answer is that the data might be big, but the more
important second answer in the context of functional programming is
that the data structure might be a hierarchical data structure like a
linked list that's passed on, and then appended to there (by way of
mutation, or in the case of lazy functional programming, by way of
mutation hidden in promises [XXX describe above]). The top (or head,
first, in case of linked lists) of the data structure might be
released by the called code as time goes on. But the variable in the
calling scope will still hold on to it, meaning, it will grow,
possibly without bounds. Example:

    {
        my $s= xfile_lines $path; # lazy linked list of lines
        print "# ".$s->first."\n";
        $s->for_each (sub { print "> ".$_[0]."\n" });
    }

Without further ado, this will retain all lines of the file at $path
in `$s` while the for_each forces in (and itself releases) line after
line.

This is a problem that many programming language implementations
have. Luckily in the case of Perl, it can be worked around, by
assigning `undef` or better weakening the variable from within the
called method:

    sub for_each ($ $ ) {
        my ($s, $proc)=@_;
        weaken $_[0];
        ...
    }

`weaken` is a bit more friendly than `$_[0] = undef;` in that it
leaves the variable set if there's still another reference to the head
around.

With this trick (which is used in all of the relevant
functions/methods in `FP::Stream`), the above example actually *does*
release the head of the stream in a timely manner.

Now there may be situations where you actually really want to keep
`$s` alive. In such a case, you can protect its value from being
clobbered by passing it through the `Keep` function from `FP::Weak`:

    {
        my $s= xfile_lines $path; # lazy linked list of lines
        print "# ".$s->first."\n";
        Keep($s)->for_each (sub { print "> ".$_[0]."\n" });
        $s->for_each (sub { print "again: > ".$_[0]."\n" });
    }

Of course this *will* keep the whole file in memory! So perhaps you'd
really want to do the following:

    {
        my $s= xfile_lines $path; # lazy linked list of lines
        print "# ".$s->first."\n";
        $s->for_each (sub { print "> ".$_[0]."\n" });
        $s= xfile_lines $path; # reopen the file from the start
        $s->for_each (sub { print "again: > ".$_[0]."\n" });
    }

Perhaps the interpreter could be changed (or a module written to
modify programs on the bytecode level) so that lexical variables are
automatically cleared upon their last access. The only argument
against this is inspection using debuggers or debugging functionality;
so it will have to be enabled explicitely in any case.


### Stack memory and tail calls

Another, closely related, place where the perl interpreter does not
release memory in a timely (enough for some programs) manner, are
subroutine calls in tail position. The tail position is the place of
the last expression or statement in a (subroutine) scope. There's no
need to remember the current context (other than, again, to aid
inspection for debugging), and hence the current context could be
released and the tail-called subroutine be made to return directly to
the parent context, but the interpreter doesn't do it.

    sub sum_map_to {
        my ($fn, $start, $end, $total)=@_;
        # this example only contains an expression in tail position
        # (ignoring the variable binding statement).
        $start < $end ?
            sum_map_to ($fn, $start + 1, $end, $total + &$fn($start))
          : $total
    }

This causes code using recursion to allocate stack memory proportional
to the number of recursive calls, even if the calls are all in tail
position. It keeps around a chain of return addresses, but also (due
to the issue described in the previous section) references to possibly
unused data.

See [`intro/tailcalls`](../intro/tailcalls) and
[`intro/more_tailcalls`](../intro/more_tailcalls) for solutions to
this problem.

(Perhaps a bytecode optimizer could be written that, given a pragma,
automatically turns calls in tail position into gotos.)

In simple cases like above, the code can also be changed to use Perl's
`while`, `for`, or `redo LABEL` constructs instead. The latter looks
closest to actual function calls, if that's something you'd like to
retain:

    sub sum_map_to {
    sum_map_to: {
        my ($fn, $start, $end, $total)=@_;
        # this example only contains an expression in tail position
        # (ignoring the variable binding statement).
        $start < $end ?
            do { @_= ($fn, $start + 1, $end, $total + &$fn($start));
                 redo sum_map_to }
          : $total
    }}

(Automatically turning such simple self tail calls into redo may
perhaps also be doable by way of a bytecode optimizer.)


### C stack memory and freeing of nested data structures

When Perl deallocates nested data structures, it uses space on the C
(not Perl language) stack for the recursion. When a structure to be
freed is nested deeply enough (like with long linked lists), this will
make the interpreter run out of stack space, which will be reported as
a segfault on most systems. There are two different possible remedies
for this:

    - increase system stack size by changing the corresponding
    resource limit (e.g. see `help ulimit` in Bash.)

    - being careful not to let go of a deeply nested structure at
    once. By using FP::Stream instead of FP::List for bigger lists and
    taking care that the head of the stream is not being retained,
    there will never be any long list in memory at any given time (it
    is being reclaimed piece after piece instead of all at once)


</with_toc>
