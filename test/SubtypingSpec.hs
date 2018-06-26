{-# LANGUAGE OverloadedStrings #-}

module SubtypingSpec (spec, parseType) where

import qualified Control.Monad.Writer as Writer
import           Data.Default (def)
import           Data.Functor.Identity (runIdentity)
import           Data.Text (Text)
import qualified NixLight.Annotations.Parser as AnnotParser
import qualified NixLight.FromHNix as FromHNix
import           Test.Hspec
import qualified Text.Trifecta as Trifecta
import qualified Text.Trifecta.Delta as TfDelta
import qualified Types
import qualified Types.Arrow as Arrow
import qualified Types.FromAnnot as FromAnnot
import qualified Types.Pair as Pair
import           Types.SetTheoretic
import qualified Types.Singletons as Singleton

parseType :: Text -> Types.Node
parseType typeStr =
  let
    (Trifecta.Success annot) =
      AnnotParser.typeAnnot
        (TfDelta.Directed "string" 0 0 0 0)
        typeStr
  in
  fst $
    runIdentity $
    Writer.runWriterT $
    FromHNix.runConvertMonad def 0 $
    FromAnnot.parseNode def annot

one = Singleton.int 1

spec :: Spec
spec = do
  describe "Same-kind subtyping" $ do
    describe "integer" $ do
      it "1<:Any" $ one <: Types.int full
      it "1/<:2" $ not $ one <: Singleton.int 2
    describe "boolean" $ do
      it "true<:Any" $ Singleton.bool True <: Types.bool full
      it "true/<:false" $ not $ Singleton.bool True <: Singleton.bool False
    describe "arrow" $ do
      it "a->b<:Any" $ Arrow.atom (full :: Types.T) empty <: full
      it "codmain-covariant" $
        Arrow.atom (full :: Types.T) empty <: Arrow.atom full full
      it "domain-contravariant" $
        Arrow.atom (full :: Types.T) empty <: Arrow.atom empty empty
    describe "pairs" $ do
      it "(1,1)<:(1,1)" $
        Pair.atomic one one <: Pair.atomic one one
      it "(1,1)<:(1,Int)" $
        Pair.atomic one one <: Pair.atomic one (Types.int full)
      it "(1,1)<:(Int,1)" $
        Pair.atomic one one <: Pair.atomic (Types.int full) one
      it "(Int, 1)</:(1, 1)" $ not $
        Pair.atomic (Types.int full) one <: Pair.atomic one one
  describe "Inter-kind" $ do
    it "Empty<:Any" $ (empty :: Types.T) <: full
    it "Any</:Empty" $ not $ (full :: Types.T) <: empty
    it "bool-int" $ not $ one <: Types.bool full
    it "int-bool" $ not $ Singleton.bool True <: Types.int full
    it "int-arrow" $ not $ one <: Types.arrow full
  describe "Recursive" $ do
    it "Infinite right" $ parseType "Int" <: parseType "X where X = Int | X -> Int"
    it "Infinite right" $ parseType "X where X = Int | X -> Int" <: parseType "Int | Empty -> Int"
    it "Self-smaller" $ parseType "X where X = Int | X -> X" <: parseType "X where X = Int | X -> X"
