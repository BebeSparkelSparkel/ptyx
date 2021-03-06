{-|
Description: Arrow types
-}

{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Types.Arrow (
  T(..), Arrow(..),
  domain, codomain, atom,
  getApplication,
  compDomain,
  get,
  decompose
  )
where

import qualified Types.Node as Node
import           Types.SetTheoretic

import           Control.Monad (foldM)
import           Data.Semigroup ((<>))
import qualified Data.Set as Set
import qualified Text.ShowM as ShowM
import qualified Types.Bdd as Bdd

-- | Atomic arrow type
data Arrow t = Arrow t t deriving (Eq, Ord)

instance ShowM.ShowM m t => ShowM.ShowM m (Arrow t) where
  showM (Arrow t1 t2) = do
    prettyT1 <- ShowM.showM t1
    prettyT2 <- ShowM.showM t2
    pure $ "(" <> prettyT1 <> ") -> " <> prettyT2

-- | Arrow type
newtype T t = T (Bdd.T (Arrow t)) deriving (Eq, Ord, SetTheoretic_)

instance ShowM.ShowM m t => ShowM.ShowM m (T t) where
  showM (T x) = do
    prettyX <- ShowM.showM x
    case prettyX of
      "⊥" -> pure "⊥"
      tt -> pure $ "(" <> tt <> ") & (⊥ -> ⊤)"

-- | Returns the domain of an atomic arrow type
domain :: Arrow t -> t
domain (Arrow d _) = d

-- | Returns the codomain of an atomic arrow type
codomain :: Arrow t -> t
codomain (Arrow _ c) = c

-- | Builds an atomic arrow type
atom :: t -> t -> T t
atom dom codom = T (Bdd.atom $ Arrow dom codom)

-- | Monadic version of 'all'
allM :: (Monad m, Foldable t) => (a -> m Bool) -> t a -> m Bool
allM f = foldM (\acc elt -> if acc then f elt else pure False) True

anyM :: (Monad m, Foldable t) => (a -> m Bool) -> t a -> m Bool
anyM f = fmap not . allM (\x -> not <$> f x)

isEmptyA :: (SetTheoretic c t, c m, Monad m) => T t -> m Bool
isEmptyA (T a)
  | Bdd.isTriviallyEmpty a = pure True
  | Bdd.isTriviallyFull a = pure False
  | otherwise =
    let arrow = Bdd.toDNF a in
    allM emptyIntersect arrow

    where
      emptyIntersect (posAtom, negAtom) =
        anyM (sub' posAtom) negAtom

      sub' p (Arrow t1 t2) =
        subCupDomains t1 p <&&>
        superCapCodomains t2 p <&&>
        forallStrictSubset
          (\subset comp -> subCupDomains t1 subset <||> superCapCodomains t1 comp)
          p

      subCupDomains t p =
        t `sub` cupN (Set.map domain p)

      superCapCodomains t p =
        capN (Set.map codomain p) `sub` t

      forallStrictSubset f =
        foldStrictSubsets
          (pure True)
          (\accu elt compl -> accu <&&> f elt compl)
          Set.empty

instance SetTheoretic Node.MemoMonad t => SetTheoretic Node.MemoMonad (T t) where
  isEmpty = isEmptyA

-- | @getApplication arr s@ returns the biggest type @t@ such
-- that @s -> t <: arr@
getApplication :: forall t c m.
  (SetTheoretic c t, c m, Monad m) => Bdd.DNF (Arrow t) -> t -> m t
getApplication arr s =
  cupN <$> mapM elemApp (Set.toList arr)
  where
    elemApp :: (Set.Set (Arrow t), Set.Set (Arrow t)) -> m t
    elemApp (pos, _) =
      foldStrictSubsets (pure empty) addElemApp pos Set.empty
    addElemApp :: m t -> Set.Set (Arrow t) -> Set.Set (Arrow t) -> m t
    addElemApp accM subset compl = do
      acc <- accM
      isInDomains <- s `sub` cupN (Set.map domain subset)
      pure $
        if isInDomains
        then acc
        else acc `cup` capN (Set.map codomain compl)

foldStrictSubsets ::
     Ord a
  => b
  -> (b -> Set.Set a -> Set.Set a -> b)
  -> Set.Set a
  -> Set.Set a
  -> b
foldStrictSubsets foldInit f elts removedElts =
    let
      directsubsets =
                    [ (Set.delete x elts, Set.insert x removedElts)
                    | x <- Set.toList elts ]
    in
    foldl
      (\accu (subset, compl) ->
        f
          (foldStrictSubsets accu f subset compl)
          subset
          compl)
      foldInit
      directsubsets

-- | Get the domain of a composed arrow
compDomain :: forall t. SetTheoretic_ t => Bdd.DNF (Arrow t) -> t
compDomain = capN . Set.map (cupN . Set.map domain . fst)

-- This is used for the checking of lambdas
decompose :: forall t. SetTheoretic_ t => Bdd.DNF (Arrow t) -> Set.Set (Arrow t)
decompose = foldl (\accu (pos, _) -> squareUnion accu pos) (Set.singleton (Arrow full empty))
  where
    squareUnion :: Set.Set (Arrow t) -> Set.Set (Arrow t) -> Set.Set (Arrow t)
    squareUnion iSet jSet =
      foldr mappend mempty $ Set.map
        (\(Arrow si ti) -> Set.map
          (\(Arrow sj tj) -> Arrow (si `cap` sj) (ti `cup` tj))
          jSet)
        iSet

get :: Ord t => T t -> Bdd.DNF (Arrow t)
get (T bdd) = Bdd.toDNF bdd
