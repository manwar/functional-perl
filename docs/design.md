(Check the [functional-perl website](http://functional-perl.org/) for
properly formatted versions of these documents.)

---

# The design principles used in the functional-perl library

<!--What guiding principles were followed in creating the functional-perl
modules?-->

### Be properly functional first.

As already mentioned in the introduction on the [[howto]] page, the
modules are built using the functional paradigm from the ground up (as
much as makes sense; e.g. iterations in simple functions are often
written as loops instead of tail
recursion<small><sup>1</sup></small>). A sequences API to build
alternative implementations (like iterator based, or optimizing away
intermediate results) might be added in the future.

<small><sup>1</sup> But this is mainly done just because it's
(currently) faster, and since currently Perl does not offer
first-class continuations.  Avoiding loop syntax and using function
calls everwhere makes it possible to suspend and resume execution
arbitrarily in a language like Scheme, without mutation getting in the
way; but this doesn't apply to current Perl 5.</small>

### Try to limit dependencies if sensible.

E.g. avoiding the use of `Sub::Call::Tail`, `Method::Signatures`,
`MooseX::MultiMethods` or `autobox` in the core modules. (Some
tests, examples and `htmlgen` use them.)

### Generally provide functionality both as functions and methods.

The sequence processing functions use the argument order conventions
from functional programming languages (Scheme, Ocaml, Haskell). The
methods move the sequence argument to the object position.

For example, both

    list_map *inc, list (1,3,4)

and

    list (1,3,4)->map (*inc)

result in the same choice of algorithm. The shorter method name is
possible thanks to the dispatch on the type of the object. Compare to:

    stream_map *inc, array2stream ([1,3,4])

or the corresponding

    array2stream ([1,3,4])->map (*inc)

which shows that there's no need to specify the kind of sequence
when using method syntax.

This actually needed an implementation trick: streams are just
lazily computed linked lists, hence the object on which the `map`
method is being called is just a generic promise. The promise could
return anything upon evaluation, not just a list pair. Thus it can't
be known what `map` implementation to call without evaluating the
promise. After evaluation, it's just a pair, though, at which point
it can't be known whether to call the `list_map` or `stream_map`
implementation. So how it works is that promises have a catch-all
(AUTOLOAD), which forces evaluation, and then looks for a method
with a `stream_` prefix first (which will find the `stream_map`
method in this example). If that fails, it will call the original
method name on the forced value.

So the way to make it work both for lazily and eagerly computed pairs
is to put both a `map` and a `stream_map` method into the
`FP::List::List` namespace (which is the parent class of
`FP::List::Pair` and `FP::List::Null`). When the pair was provided
lazily, the above implementation will dispatch to `stream_map`, which
normally makes sense since the user will want a lazy result from a
lazy input.

Note that this dispatch mechanism is only run for the first pair of
the list; afterwards, the code stays in either `list_map` or
`stream_map`. This means that prepending a value to a stream makes
the non-lazy map implementation be used:

    cons (0, array2stream [1,3,4])->map (*inc)

returns an eagerly evaluated list, not a stream. If that's not
what you want, you can still prefix the method name with `stream_`
yourself to force the lazy variant:

    cons (0, array2stream [1,3,4])->stream_map (*inc)

returns a stream.

(Idea: use `Class::Multimethods` or `Class::Multimethods::Pure` or
`MooseX::MultiMethods` to provide multimethods as alternative to
methods; this would allow to retain the traditional argument positions
and still use short names. Perhaps look at Clojure as an example?)

### Use of `*foo` vs `\&foo`

Both work for passing a subroutine as a value. A benchmark did not
reveal a significant difference in performance. For its simplicity in
writing and looks, the first option is preferred in documentation and
examples; but it should not be forgotten that this really passes a
glob, which can contain values of all the identifier namespaces that
perl has (subroutines, IO handles, scalars, arrays, hashes). Also, the
values are retrieved on demand in this case, which means that when a
subroutine is redefined between the taking of the glob and calling it,
the new definition will be used, whereas with `\&` there is no such
indirection and thus the redefinition of the subroutine is not
reflected in the reference. Also, explicit checks for CODE refs will
fail wenn passing a glob; we could make `is_procedure` more lenient by
accepting globs if they contain a value in the CODE slot (todo?), but
builtin perl checks would still be wrong (e.g. passing `*foo` where an
array reference is expected will silently access the `@foo` package
variable, even if it was never declared (empty in this case)).

Worse: globs fail when called using `goto`. (Todo: same with `tail`?)

For these reasons, the core modules never use globs (but they don't
usually type check in the array case either!).

(Todo: should we create a module that turns `*foo` into `\&foo`?)

### Naming conventions

* Function names *start* with the data type that they are made for;
  for example `array_map` versus `list_map`. (This follows the
  conventions in Scheme (and some other functional languages?).)
  Of course method (and multimethod) names don't need to, and
  shouldn't, carry the name of the data type. (The `stream_` prefix in
  method names already mentioned above is an exception: it's to
  explicitely choose, and also not really a type choice but an
  evaluation strategy choice.)

* Predicates (functions that check whether a value fulfills a type or
  other requirement (or in general return a boolean?)) start with
  `is_`; but if they only work for a particular data type, the put the
  `is` after the type name (something like `array_is_pure`).

* Data conversion functions are currently named with `2`,
  e.g. `array2list` (todo: change to `_to_`, or drop entirely,
  e.g. `array_list`?). This follows the convention in Scheme (except
  `->` is used there instead of the `2`), but not
  that of Ocaml, where such functions are called
  e.g. `list_of_array`. Method names for the same omit both the
  source type name and the `2` (e.g. `->array`).

* The `maybe_` prefix is used for variables and functions which
  bind or return `undef` as indication for the absence of a value. The
  `perhaps_` prefix is used for functions which return `()` as
  indication for the absense of a value.

* Functional setters (those which leave their arguments unmodified,
  i.e. for persistent data structures) *end* with `_set` instead of
  starting with `set_` as is common in the imperative world. (This is
  consistent with the Scheme naming conventions (first the type, then
  the field name, then the operation), and hints that it's not
  imperative code.)


## Purity

Perl does not have a compile time type checker to guarantee
(sub-)programs to be purely functional like e.g. Haskell does, but
programs could still enforce checks at run time.

The `FP` libraries do not currently enforce purity anywhere, it just
does not offer mutators (except for array or hash assignment to the
object fields). It helps the user writing pure programs, but does not
enforce it. This works well for projects written by single developers
or perhaps also small teams, where you know which subroutines and
methos are pure by way of remembering or naming convention, or where
checking is quick. But in bigger teams it might be useful to be able
to get guarantees by machine instead of just by trust. Thus it is an
aim of this project to try to provide for optional runtime enforcement
of purity (in the future).

### Use `FP::Pure` as base class for (in principle) immutable objects

And let `is_pure` from `FP::Predicates` return true for all immutable
data types (even if they are not blessed references)? (Todo, in flux.)

The idea is to be able to assert easily that an algorithm can rely on
some piece of data not changing.

(Currently) the rule is that a data structure is considered immutable
if it doesn't provide an exported function, method, or tie interface
to mutate it. For example mistreating list pairs by mutating them by
way of relying on their implementation as arrays with two elements and
mutating the array slots does not make them a(n officially) mutable
object.

The libraries inheriting from `FP::Pure` *should* try to disable such
mutations from Perl code; they might be useful in some situations for
debugging, though, so leaving open a back door that still allows for
mutation (like using a mutator that issues a warning when run, or a
global that allows to turn off mutability protection) may be a good
idea. In general, mutations that are purely debugging aids (like
attaching descriptive names to objects or similar) are excluded from
the rule.

Algorithms that want to use mutation, even if rarely (like creating a
circular linked list without going through a promise, or copying a
list without using stack space or reversing twice (but copying a pure
list doesn't make sense!)) must rely on mutable objects instead (like
mutable pairs (todo)).

Closures can't be treated as immutable in general since their
environment (lexicals visible to them) can be mutated. (Todo: provide
syntax (e.g. 'purefun' keyword) that blesses closures (if manually
deemed pure)? Note that should this ever be implemented, purity checks
shouldn't be added too often, as e.g. passing an impure function to
`map` is ok if the user knows what he is doing. But offering a
guaranteed pure variant of `map` that *does* restrict its function
argument to be pure might be useful. Instead of creating a mess of
variants, something smarter like a pragma should be implemented
though.)

<!-- ev?

Function::Parameters vs. Method::Signatures

stream_mixed_flatten

autobox.pm, Moose::Util::TypeConstraints, MooseX::MultiMethods, or just, now,
Class::Multimethods (Class::Multimethods::Pure?)

-->