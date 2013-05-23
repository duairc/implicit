{-# LANGUAGE CPP #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE UndecidableInstances #-}
#ifdef LANGUAGE_ConstraintKinds
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverlappingInstances #-}
{-# LANGUAGE PolyKinds #-}
#if __GLASGOW_HASKELL__ >= 707
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators #-}
#else
{-# LANGUAGE ImplicitParams #-}
#endif
#endif

{-|

"Data.Implicit" provides both named and unnamed implicit parameters that
support default values (given by the 'Default' class from the @data-default@
package). It makes no use of the @ImplicitParams@ extension and instead
everything is done using type classes.

Here is an example of unnamed implicit parameters:

@
{\-\# LANGUAGE FlexibleContexts #-\}
import "Data.Implicit"

putParam :: 'Implicit_' String => IO ()
putParam = putStrLn $ \"Param was: \" ++ show ('param_' :: String)
@

We define @putParam@, which is a simple function which takes an implicit
parameter of type @String@, and prints it to the screen. The 'param_' function
is used to retrieve the unnamed implicit parameter of type @String@ from
@putParam@'s context. The type signature is necessary to force 'param_' to
return a @String@, as this cannot be inferred due to the polymorphism of
@show@.

>>> putParam
Param was ""

This is how we call @putParam@ without specifying its implicit parameters. If
an implicit parameter is left unspecified, its value is defaulted to 'def',
assuming that its type has a 'Default' instance. If not, then it is a type
error not to specify the value of an implicit parameter.

>>> putParam $~ "hello, world"
Param was "hello, world"

The operator '$~' takes a function @f@ and a value to which to set the
homotypic implicit parameter on @f@. It applies the implicit parameter to @f@
and returns the result. There is also a prefix version of @$~@ whose arguments
are flipped called 'setParam_'.

Here is an example of named implicit parameters:

@
{\-\# LANGUAGE DataKinds, FlexibleContexts, RankNTypes #-\}
import "Data.Implicit"
import "Data.Proxy"

putFooBar :: ('Implicit' \"foo\" String, 'Implicit' \"bar\" String) => IO ()
putFooBar = do
    putStrLn $ \"foo was: \" ++ show foo
    putStrLn $ \"bar was: \" ++ show bar

foo :: 'Implicit' \"foo\" String => String
foo = 'param' (Proxy :: Proxy \"foo\")

bar :: 'Implicit' \"bar\" String => String
bar = 'param' (Proxy :: Proxy \"bar\")

setFoo :: String -> ('Implicit' \"foo\" String => a) -> a
setFoo = 'setParam' (Proxy :: Proxy \"foo\")

setBar :: String -> ('Implicit' \"bar\" String => a) -> a
setBar = 'setParam' (Proxy :: Proxy \"bar\")
@

The 'Implicit' constraint is the named equivalent of 'Implicit_'. It takes an
additional argument of kind 'Symbol' (which requires the @DataKinds@
extension; see the "GHC.TypeLits" module) to specify the name of the implicit
parameter. 'param' and 'setParam' work like their unnamed counterparts
'param_' and 'setParam_', but they also take a proxy argument to specify the
name of the implicit parameter. The code above defines the wrappers @foo@ and
@bar@ and @setFoo@ and @setBar@ around @param@ and @setParam@ respectively,
which hide all the (slightly ugly) proxy stuff.

>>> putFooBar
foo was: ""
bar was: ""

Once again, the defaults of unspecified implicit parameters are given by the
'Default' class.

>>> setFoo "hello, world" putFooBar
foo was: "hello, world"
bar was: ""

>>> setBar "goodbye" $ setFoo "hello, world" putFooBar
foo was: "hello, world"
bar was: "goodbye"

An infix version of @setParam@ is also provided, '$$~'. Using @$$~@, the above
example would be:

>>> putFooBar $$~ (Proxy :: Proxy "foo", "hello, world") $$~ (Proxy :: Proxy "bar", "goodbye")
foo was: "hello, world"
bar was: "goodbye

-}

module Data.Implicit
    ( Implicit
    , param
    , setParam
    , (~$)

    , Implicit_
    , param_
    , setParam_
    , ($~)
    )
where

import           Data.Default.Class (Default, def)
#ifdef LANGUAGE_ConstraintKinds
import           Unsafe.Coerce (unsafeCoerce)
#endif


------------------------------------------------------------------------------
-- | The constraint @'Implicit' \"foo\" String@ on a function @f@ indicates
-- that an implicit parameter named @\"foo\"@ of type @String@ is passed to
-- @f@.
--
-- The name @\"foo\"@ is a type of kind 'Symbol' (from the "GHC.TypeLits"
-- module). The @DataKinds@ extension is required to refer to 'Symbol'-kinded
-- types.
#ifdef LANGUAGE_ConstraintKinds
class Implicit s a where
#else
class Default a => Implicit s a where
#endif
#if __GLASGOW_HASKELL__ >= 707
    _param :: proxy s -> proxy' a -> a
#else
    _param :: proxy s -> a
#endif


------------------------------------------------------------------------------
instance Default a => Implicit s a where
#if __GLASGOW_HASKELL__ >= 707
    _param _ _ = def
#else
    _param _ = def
#endif


------------------------------------------------------------------------------
-- | 'param' retrieves the implicit parameter named @s@ of type @a@ from the
-- context @'Implicit' s a@. The name @s@ is specified by a proxy argument
-- passed to @param@.
param :: Implicit s a => proxy s -> a
#if __GLASGOW_HASKELL__ >= 707
param p = _param p Proxy
#else
param = _param
#endif


------------------------------------------------------------------------------
-- | 'setParam' supplies a value for an implicit parameter named @s@ to a
-- function which takes a homotypic and homonymous implicit parameter. The
-- name @s@ is specified by a proxy argument passed to @setParam@.
#ifdef LANGUAGE_ConstraintKinds
setParam :: proxy s -> a -> (Implicit s a => b) -> b
#else
setParam :: Default a => proxy s -> a -> (Implicit s a => b) -> b
#endif
setParam = using


------------------------------------------------------------------------------
-- | An infix version of 'setParam' with flipped arguments.
#ifdef LANGUAGE_ConstraintKinds
(~$) :: (Implicit s a => b) -> proxy s -> a -> b
#else
(~$) :: Default a => (Implicit s a => b) -> proxy s -> a -> b
#endif
(~$) f proxy a = using proxy a f


------------------------------------------------------------------------------
-- | The constraint @'Implicit_' String@ on a function @f@ indicates that an
-- unnamed implicit parameter of type @String@ is passed to @f@.
#ifdef LANGUAGE_ConstraintKinds
class Implicit_ a where
#else
class Default a => Implicit_ a where
#endif
#if __GLASGOW_HASKELL__ >= 707
    _param_ :: proxy' a -> a
#else
    _param_ :: a
#endif


------------------------------------------------------------------------------
instance Default a => Implicit_ a where
#if __GLASGOW_HASKELL__ >= 707
    _param_ _ = def
#else
    _param_ = def
#endif


------------------------------------------------------------------------------
-- | 'param_' retrieves the unnamed implicit parameter of type @a@ from the
-- context @'Implicit_' a@.
param_ :: Implicit_ a => a
#if __GLASGOW_HASKELL__ >= 707
param_ = _param_ Proxy
#else
param_ = _param_
#endif


------------------------------------------------------------------------------
-- | 'setParam_' supplies a value for an unnamed implicit parameter to a
-- function which takes a homotypic implicit parameter.
#ifdef LANGUAGE_ConstraintKinds
setParam_ :: a -> (Implicit_ a => b) -> b
#else
setParam_ :: Default a => a -> (Implicit_ a => b) -> b
#endif
setParam_ = using_


------------------------------------------------------------------------------
-- | An infix version of 'setParam_' with flipped arguments.
#ifdef LANGUAGE_ConstraintKinds
($~) :: (Implicit_ a => b) -> a -> b
#else
($~) :: Default a => (Implicit_ a => b) -> a -> b
#endif
infixr 1 $~
f $~ a = using_ a f


#ifdef LANGUAGE_ConstraintKinds
------------------------------------------------------------------------------
data Dict c where
    Dict :: c => Dict c


#if __GLASGOW_HASKELL__ >= 707
------------------------------------------------------------------------------
data Proxy (a :: *) = Proxy


------------------------------------------------------------------------------
newtype Lift s a t = Lift a


------------------------------------------------------------------------------
newtype Lift_ a t = Lift_ a


------------------------------------------------------------------------------
using :: proxy s -> a -> (Implicit s a => b) -> b
using (_ :: proxy s) d m = reify d $ \(_ :: Proxy t) -> m \\ trans
    (unsafeCoerceConstraint :: (Implicit s (Lift s a t) :- Implicit s a))
    reifiedInstance
  where
    reifiedInstance :: Reifies t a :- Implicit s (Lift s a t)
    reifiedInstance = Sub Dict


------------------------------------------------------------------------------
using_ :: a -> (Implicit_ a => b) -> b
using_ d m = reify d $ \(_ :: Proxy t) -> m \\ trans
    (unsafeCoerceConstraint :: (Implicit_ (Lift_ a t) :- Implicit_ a))
    reifiedInstance
  where
    reifiedInstance :: Reifies t a :- Implicit_ (Lift_ a t)
    reifiedInstance = Sub Dict


------------------------------------------------------------------------------
newtype a :- b = Sub (a => Dict b)
infixr 9 :-


------------------------------------------------------------------------------
(\\) :: a => (b => r) -> (a :- b) -> r
r \\ Sub Dict = r
infixl 1 \\ --


------------------------------------------------------------------------------
trans :: (b :- c) -> (a :- b) -> a :- c
trans f g = Sub $ Dict \\ f \\ g


------------------------------------------------------------------------------
unsafeCoerceConstraint :: a :- b
unsafeCoerceConstraint = unsafeCoerce (Sub Dict :: a :- a)


------------------------------------------------------------------------------
class Reifies t a | t -> a where
    reflect :: proxy t -> a


------------------------------------------------------------------------------
newtype Magic a r = Magic (forall t. Reifies t a => Proxy t -> r)


------------------------------------------------------------------------------
reify :: forall a r. a -> (forall t. Reifies t a => Proxy t -> r) -> r
reify a k = unsafeCoerce (Magic k :: Magic a r) (const a) Proxy


------------------------------------------------------------------------------
instance Reifies t a => Implicit s (Lift s a t) where
    _param _ a = Lift $ reflect (peek a)
      where
        peek :: proxy b -> b
        peek _ = undefined


------------------------------------------------------------------------------
instance Reifies t a => Implicit_ (Lift_ a t) where
    _param_ a = Lift_ $ reflect (peek a)
      where
        peek :: proxy b -> b
        peek _ = undefined
#else
------------------------------------------------------------------------------
newtype Tagged s a = Tagged a


------------------------------------------------------------------------------
newtype Identity a = Identity a


------------------------------------------------------------------------------
using :: proxy s -> a -> (Implicit s a => b) -> b
using p a = with (unlift (dict p a))
  where
    with :: Dict c -> (c => b) -> b
    with Dict b = b

    unlift :: Dict (c (lift p)) -> Dict (c p)
    unlift = unsafeCoerce

    dict :: proxy s -> a -> Dict (Implicit s (Tagged s a))
    dict _ a' = let ?param = Tagged a' in Dict


------------------------------------------------------------------------------
using_ :: a -> (Implicit_ a => b) -> b
using_ a = with (unlift (dict a))
  where
    with :: Dict c -> (c => b) -> b
    with Dict b = b

    unlift :: Dict (c (lift p)) -> Dict (c p)
    unlift = unsafeCoerce

    dict :: a -> Dict (Implicit_ (Identity a))
    dict a' = let ?param = Identity a' in Dict


------------------------------------------------------------------------------
instance (?param :: Tagged s a) => Implicit s (Tagged s a) where
    _param _ = ?param


------------------------------------------------------------------------------
instance (?param :: Identity a) => Implicit_ (Identity a) where
    _param_ = ?param
#endif
#else
using :: Implicit s a => proxy s -> a -> (Implicit s a => b) -> b
using _ _ b = b


------------------------------------------------------------------------------
using_ :: Implicit_ a => a -> (Implicit_ a => b) -> b
using_ _ b = b
#endif
