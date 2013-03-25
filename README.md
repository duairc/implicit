# Implicit parameters

There are certain types of applications which are configurable where it makes
sense to model this configurability as a global or semi-global set of
configuration values that some or all parts of the program can "implicitly"
access. These configuration values are called "implicit parameters".

## `ImplicitParams` in Haskell

Haskell already has support for implicit parameters via the `ImplicitParams`
[extension][ImplicitParams]. However, `ImplicitParams` has several flaws and
is barely used at all in modern Haskell code. Many Haskellers consider its
(ab)use of `let`/`where` bindings to pass implicit parameters to be ugly.
Also, it's questionable how "implicit" the implicit parameters of
`ImplicitParams` actually are, as they show up in the context of the type
signature of any function which uses them. There's also no way you can call a
function taking an implicit parameter without passing it that parameter if it
isn't already in context: i.e., there is no way to specify a "default" value
for an implicit parameter if none is passed.

## Motivating example

`implicit-params` solves some of these problems and introduces new problems of
its own. However, there is one particular use case which motivated me to
develop `implicit-params` that isn't supported by the existing
`ImplicitParams` extension. Imagine you have the following code:

    app :: Config -> IO ()
    defaultConfig :: Config

Which is used by a program as follows:

    main = app defaultConfig

There are two problems with this code. One is that `app` has to manually plumb
the `Config` value it was given around everywhere. One solution here would be
for `app` to use a [Reader][Reader] monad internally, but that can complicate
the code in some ways and it seems like overkill. If it used the
`ImplicitParams` extension, the above code would look like this:

    app :: (?config :: Config) => IO ()
    defaultConfig :: Config

    main = let ?config = defaultConfig in app

You can see why `ImplicitParams` isn't very highly regarded: all it did was
make the code longer, in *two* different places, but at least the internals
of `app` will be a bit nicer now that the `Config` value won't have to be
plumbed around everywhere manually.

## `data-default`

The [`data-default`][data-default] package provides a type class `Default`
which represents the class of types which have a \"default\" value. It has a
single operation `def` which returns the default value for a given type (the
type is given by type inference). Using `Default` the above code could be made
a little nicer:

    app :: (?config :: Config) => IO ()
    instance Default Config where def = defaultConfig

    main = let ?config = def in app

However, the above code is still so *ugly* considering what we're trying to
do: all we want to do is run `app` with the defaults. This should be as simple
as typing `app`, and only if we're overriding the defaults should the code
need to be any longer than this. This is exactly what `implicit-params` does.
If an implicit parameter is not explicitly given to a function which requires
it, its value is given by `def` for the `Default` instance for the type of the
parameter. And if the type does not have a `Default` instance, then it is a
type error to call that function without explicitly setting the implicit
parameter (but it will work fine if you do set it). This is how the above code
looks using `implicit-params`:

    app :: Implicit_ Config => IO ()
    instance Default Config where def = defaultConfig

    main = app

Perfect! What if we want to pass a non-default config to `app`? That's easy
too:

    main = setParam_ (def {option = 1}) app

(Bonus points for not abusing `let`/`where` bindings.)

`setParam_` even has an infix synonym `$~` which makes the above code even
nicer:

    main = app $~ def {option = 1}

### Named implicit parameters

The above code uses unnamed implicit parameters, which will suffice for most
code. Sometimes you might want to pass more than one implicit parameter of the
same type to a single function, and for this you need some way of selecting
the particular implicit parameter on which to operate. `implicit-params` uses
type level [symbols][Symbols] for this, which require the `DataKinds`
[extension][DataKinds].

`Implicit_` denotes an unnamed implicit parameter; `Implicit "foo"` can be
used to denote a named implicit parameter named `"foo"` Named implicit
parameters are slightly more awkward to use because they require passing
[`Proxy`][Proxy] parameters to the `param` and `setParam` functions to specify
the names of the implicit parameters on which they are to operate. See the
Haddock documentation of the `Data.Implicit` module for more details.

[ImplicitParams]: http://www.haskell.org/ghc/docs/latest/html/users_guide/other-type-extensions.html#implicit-parameters
[Reader]: http://hackage.haskell.org/packages/archive/mtl/latest/doc/html/Control-Monad-Reader-Class.html
[data-default]: http://hackage.haskell.org/package/data-default
[Symbols]: http://www.haskell.org/ghc/docs/latest/html/libraries/base/GHC-TypeLits.html#t:Symbol
[DataKinds]: http://www.haskell.org/ghc/docs/7.4.1/html/users_guide/kind-polymorphism-and-promotion.html
[Proxy]: http://hackage.haskell.org/packages/archive/tagged/latest/doc/html/Data-Proxy.html