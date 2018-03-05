{-# LANGUAGE OverloadedStrings #-}

module Typer.Environ where

import           Data.Default (Default, def)
import           Data.Text (Text)
import qualified Typer.Environ.Gamma as Gamma
import qualified Types
import           Types.Intervals ()
import           Types.SetTheoretic (empty, full)

newtype T = T { gamma :: Gamma.T }

instance Default T where
  def = T { gamma = def }

mapGamma :: (Gamma.T -> Gamma.T) -> T -> T
mapGamma f t = t { gamma = f $ gamma t }

addVariable :: Text -> Types.T -> T -> T
addVariable name typ = mapGamma (Gamma.insert name typ)

lookupVariable :: Text -> T -> Maybe Types.T
lookupVariable name = Gamma.lookup name . gamma

getType :: T -> Text -> Maybe Types.T
getType _ name = -- FIXME: using hardcoded list of builtin types for now
  case name of
    "Int" -> pure $ Types.int full
    "Bool" -> pure $ Types.bool full
    "Any" -> pure full
    "Empty" -> pure empty
    _ -> Nothing
