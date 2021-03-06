{-# LANGUAGE LambdaCase #-}
import           Nix.Expr
import           Nix.Parser

import qualified NixLight.FromHNix
import           Typer.Environ ()
import qualified Typer.Error as Error
import qualified Typer.Infer as Infer
import qualified Types
import qualified Types.Node as Node

import qualified Control.Monad.Writer as W
import           Data.Default (def)
import           System.Environment

nix :: FilePath -> IO ()
nix path = parseNixFileLoc path >>= printTypeAst

nixTypeString :: String -> IO ()
nixTypeString =
  printTypeAst . parseNixStringLoc

printTypeAst :: Result NExprLoc -> IO ()
printTypeAst = displayTypeResult . typeAst

typeAst :: Result NExprLoc -> W.Writer [Error.T] Types.T
typeAst = \case
  Failure e -> error $ "Parse failed: " ++ show e
  Success n ->
    let nlAst = NixLight.FromHNix.closedExpr n in
    Node.typ <$> (Infer.inferExpr def =<< nlAst)

displayTypeResult :: W.Writer [Error.T] Types.T -> IO ()
displayTypeResult res = do
  let (typ, errs) = W.runWriter res
  mapM_ print errs
  print typ

main :: IO ()
main = do
  let usageStr = "Parses a nix file and prints to stdout.\n\
                 \\n\
                 \Usage:\n\
                 \  ptyx --help\n\
                 \  ptyx <path>\n\
                 \  ptyx --expr <expr>\n"
  let argErr msg = error $ "Invalid arguments: " ++ msg ++ "\n" ++ usageStr
  getArgs >>= \case
    "--help":_ -> putStrLn usageStr
    "--expr":expr:_ -> nixTypeString expr
    "--expr":_ -> argErr "Provide an expression."
    ('-':_):_ -> argErr "Provide a path to a nix file."
    path:_ -> nix path
    _ -> argErr "Provide a path to a nix file."
