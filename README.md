# NAME

Hustle::Table - Pattern dispatch to code with optional optimisation

# SYNOPSIS

```perl
 use Hustle::Table;

 #1. Create a new object
 my $table=Hustle::Table->new;

 #2. Add entries which contain:
 # matcher:            required. The matcher  (ie regex, string, number) to test with
 # sub:                required. The sub to call when matcher is 'true' when testing input
 # label:              optional. For identification
 # count:              optional. Used as priority when adding (larger number=> higher priority)
 # Can either be a array ref or hash ref

 $table->add(
       #entry as a hash ref
       { matcher => qr/regex (match)/, sub => sub{ #can access regex capture }}, 

       #entry as array ref, with label, priority values and context set
       [qr/another/, sub{}, "my label", 10,{}],                        
       
       #undef matcher is default match all. Must be array ref format
       [undef,sub {},"default",undef,undef]                            
 );

 #3. Prepare a dispatcher:
 # A dispatcher is sub reference, which is called directly with input to match

 my $dispatch = $table->prepare_dispatcher(
       type => "online",               #either "online" (default="online") or "offline" 
       cache => {},            #the hash to use as a cache
       reorder => 1,           #reorder (default=1) table before building dispatcher   
       reset => 0              #Reset (default=undef) entry counts
);


 #4. Dispatch input
 $dispatch->("thing to match", "optional", "arguments");       
 #The dispatched sub is called with the match entry and then all argument from the second onwards


 #5. Offline optimisation is also possible
 
```

# DESCRIPTION

This module provides a small class to constructs a dispatch table and builds a
dispatcher for it. All interactions are done via the object/class methods so no
exports are defined.

It supports straightforward optimisation of the dispatch table and  an optional
cache to squeeze even more performance out.

Notable features include:

- Captures in regex are available in dispatched subs
- Arguments supplied to dispatcher (except first) are available to executed
vector sub
- Cached pre-matching (optional)
- Basic hit count and optimising (optional)
- Fall through/catch all matching

The dispatch table is essentially a list of at least one entry which maps a
matcher to a subroutine which is called on a successful match of the input.

Conceptually the list is looped over, applying the matchers sequentially to the
input until a match is found. In practice it isn't a loop, but generated code
reference with potentially optimised ordering of the entries.

In the case of no successful match, a default catch all dispatch vector is
called.

Matching performance is optionally boosted by using a hash as a cache. Hash
lookup is much quicker than repeated conditional testing. Controlling which
inputs are removed from the cached is dictated by the return value of the
dispatch vector/sub

# VERSION DIFFERENCES

**Version 0.4.0 and later**
`given`/`when` and thus the use of smart matching is removed. This gives a
nice performance improvement of up to 20% over previous versions, however does
mean the features of smart matching (i.e.  allowing string equality test ) is
no longer supported. To match an exact string you will need to make a regex
matcher like `^exact$`.

**Version 0.3.0 and later**
The input string (the first arg to the dispatcher) is removed and replaced with
the matching table entry when calling a dispatched sub. In Previous versions,
all arguments would be passed to the dispatched sub unchanged.

If you need the input string that was being tested, pass it a second time to the dispatcher:

```
            #From v0.3.0 Onwards
                    $dispatcher->($input, $input, $another, $arg. ..._)
```

# CREATING A TABLE

Simply calling the class constructor returns a new Table. There are no
arguments required for the constructor:

```perl
    my $table=Hustle::Table->new;
```

In this case, a default catch all entry (an empty sub) is added automatically.

Alternatively, a `sub` and `ctx` argument can be provided:

```perl
    my $table=Hustle::Table->new(sub{}, $ctx);
```

This will overwrite the default entry in the table

The table is a blessed array reference and can be manipulated as such. It's not
recommended to access the table directly other than dumping the contents to
storage.

# ENTRIES MANAGEMENT

## STRUCTURE

An entry contains the following fields

- matcher

    `matcher` can be anything that smart-matching can handle. However the focus on
    this module is on strings and regular expressions

    ```
    "match exaclty this stirng"
    qr|match and capture (this|that)|
    ```

    When `matcher` is a regex, any capturing is accessible in the target `sub`
    via the dynamically scoped numbered capture group variables (i.e. `$1` et al.)

- sub

    The `sub` has access to any capture groups used in the matcher (if
    applicable). It is also passed the arguments supplied to call the dispatcher,
    except for the first.  The first is replaced with the matching entry in the
    table, to allow tracing.

    ```perl
    $dispatcher->("my input","optional", "arguments", "to", "dispatched", "sub");
    ```

    The return value of the sub indicates if the input matched is to be
    removed from the cache. 

- label

    `label` is a user defined item to allow identification of the entry. This is
    useful for saving/loading from configuration files etc.

- count

    `count` This is a dual purpose attributes. When adding entries to the list, it
    is used as a priority. Higher numeric values are a higher priority. The list is
    sorted in descending order of priority, meaning the highest priority is the
    first element in the list.

    During running of the dispatch, this is a tally recording how many times,the
    entry has been matched. This information can be then used as a priority later
    to reorder the list.

- ctx

    `ctx` Represents a user context which is applicable to the matcher. It would
    usually be a weak reference but can be any scalar.

    The dispatched subroutine has access to this value via the matcher entry, which
    is  the first argument to the called subroutine

## ADDING

Entries are added in anonymous hash, anonymous array or flattened format, using
the `add` method.

Array entries must contain four elements, in the order of:

```perl
    $table->add([$matcher, $sub, $label, $count, $ctx]);
```

Hashes ref format only need to specify the matcher and sub pairs

```perl
    $table->add({matcher=>$matcher, sub=>$sub, label=>$label, count=>$count, ctx=>$ctx});
```

Single flattened format takes a list directly. It must contain 4 elements

```perl
    $table->add(matcher=>$matcher, sub => $sub);
```

Single simple format takes two elements

```perl
    $table->add(qr{some matcher}=>sub { say "run me" })
```

Or add multiple at once using mixed formats together

```perl
    $table->add(
            [$matcher, $sub, $label, $count, $ctx],
            {matcher=> $matcher, sub=>$sub},
            matcher=>$matcher, sub=>$sub
    );
```

In any case,`$matcher` and `$sub` are the only items which must be defined.
`$sub` must also be a CODE reference. 

If a label is not specified, one will be generated automatically. All the
labels used in a call to `add` are returned in the same order as the input
arguments.

Auto generated labels are only unique in the lifetime of a single
table. If permanent/globally unique labels are need, the user will need to
generate them.

## REMOVING

Removal of entries is via the `remove` method. It takes a list of labels to remove

```
    $table->remove("label1", "funky-name");
```

It returns a list of all entries removed.

## DUMPING 

The table contents be accessed can like a normal array reference

```
    $table->@*;
    @$table;
```

It is not recommended to manipulate the entires directly

## THE DEFAULT MATCHER

Each list has a default matcher that will unconditionally match the input. This
entry is specified by using `undef` as the matcher when adding an entry. When
set this way only the array format can be used.

To make it more explicit, the it can also be changed via the `set_default`
method. 

The default subroutine of the 'default' entry does nothing.

# PREPARING A DISPATCHER

Once all the entries required are added to the table, the dispatcher can be
constructed by calling `prepare_dispatcher`:

```perl
    my $dispatcher=$table->prepare_dispatcher(%args);
```

Arguments to this method include:

- type

    The type of dispatcher. Either "online" or "offline". If not specified, or an
    invalid value is supplied, an "online" dispatcher is created

    - online

        Dispatcher which calls the dispatch vector, increases count statistics. This is
        what you normally would want to use in your code. Online mode.

    - offline

        Dispatcher which only updates the count statistics. DOES NOT call dispatch
        vector. Useful for running a input data set through to obtain priority levels.
        Offline training mode.

- cache

    The hash ref to use as the dispatchers cache

- reorder

    Flag indicating the table should be reordered/optimised before building the
    dispatcher.

- reset

    Flag specifying if counter statistics should be reset before building a
    dispatcher

If no arguments are provided, the dispatcher will be created with the following
defaults:

```perl
    my $dispatcher=$table->prepare_dispatcher(type=>"online", cache=>undef, reset=>undef, reorder=>1);
```

# USING A DISPATCHER

The dispatcher is simply a sub. Any arguments passed to it are passed to the
dispatch vector as is.

```
    $dispatcher->("input", "argument1",2);
```

# PERFORMANCE

## CACHING AND CACHE CONTROL

The return code of the dispatched sub is used to control if a successful match
should be removed from the cache, or not be  removed;

Any 'true' value returned will means the input, as a key to the cache, is to be
removed from the cache.

Any 'false' value indicates the input is to remain in the cache or be added if
it doesn't exist.

```perl
    {matcher => qr/r(.)gexp/, sub => sub { return }};       #Returns undef so not removed from cache.
    {matcher => qr/re(.)gxp/, sub => sub { return 1}};      #Returns 'true' so removed from cache
    {matcher => qr/reg(.)xp/, sub => sub { say $1;}};       #Returns true. Last statement is say and returns 1 
```

## OPTIMISATION

The concept is to perform less searching to find the dispatch vector. However
the type of input does play an important role in determining the best way
perform the search.

For example a uniformly distributed input will not gain benefits from
reordering the entries in the list.

On the other hand when the distributing becomes 'centred', the reordering of
the table can greatly improve the search time.

On my laptop, the simple benchmark script, (with 6 dispatch entries) (regex and
string) shows around 1.4M dispatches/s for non cached and over 2M dispatches/s
for cached dispatcher. Your results may vary.

# COMPARISON TO OTHER MODULES

There a couple of other dispatching modules on CPAN.  Notably
[Smart::Dispatch](https://metacpan.org/pod/Smart%3A%3ADispatch) has a nice syntax, probably more flexibility and the ability
to return values instead of just executing a sub.

This module is smaller/(much)faster in my basic tests and also supports direct
access to the regex capture groups and dispatch arguments.

# BUGS

Probably.

Please report via github

# TODO

- Write tests for removing entries
- Write tests for offline dispatcher
- Override array STORE and FETCH interface to ensure default is preserved
- Add a more concrete performance discussion
- Document how to run offline dispatcher for optimising

# AUTHOR

Ruben Westerberg, <drclaw@mac.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2021 by Ruben Westerberg

Licensed under MIT and GNU

# DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE.
