{-# LANGUAGE PatternGuards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}

-- | Main entry point to hindent.
--
-- hindent

module Main where

import           HIndent

import           Control.Applicative
import           Data.List
import           Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy.Builder as T
import qualified Data.Text.Lazy.IO as T
import           Data.Version (showVersion)
import           Descriptive
import           Descriptive.Options
import           Language.Haskell.Exts.Annotated hiding (Style)
import           Paths_hindent (version)
import           System.Environment

-- | Main entry point.
main :: IO ()
main =
  do args <- getArgs
     case consume options (map T.pack args) of
       Left{} ->
         error (T.unpack (textDescription (describe options [])))
       Right result ->
         case result of
           Left{} ->
             putStrLn ("hindent " ++ showVersion version)
           Right (style,exts) ->
             T.interact
               (either error T.toLazyText .
                reformat style (Just exts))

-- | Program options.
options :: Consumer [Text] Option (Either Text (Style,[Extension]))
options =
  fmap Left (constant "--version") <|>
  (fmap Right ((,) <$> style <*> exts))
  where style =
          constant "--style" *>
          foldr1 (<|>)
                 (map (\style ->
                         fmap (const style)
                              (constant (styleName style)))
                      styles)
        exts =
          fmap getExtensions (many (prefix "X" "Language extension"))

--------------------------------------------------------------------------------
-- Extensions stuff stolen from hlint

-- | Consume an extensions list from arguments.
getExtensions :: [Text] -> [Extension]
getExtensions = foldl f defaultExtensions . map T.unpack
  where f _ "Haskell98" = []
        f a ('N':'o':x)
          | Just x' <- readExtension x =
            delete x' a
        f a x
          | Just x' <- readExtension x =
            x' :
            delete x' a
        f _ x = error $ "Unknown extension: " ++ x

-- | Parse an extension.
readExtension :: String -> Maybe Extension
readExtension x =
  case classifyExtension x of
    UnknownExtension _ -> Nothing
    x' -> Just x'

-- | Default extensions.
defaultExtensions :: [Extension]
defaultExtensions =
  [e | e@EnableExtension{} <- knownExtensions] \\
  map EnableExtension badExtensions

-- | Extensions which steal too much syntax.
badExtensions :: [KnownExtension]
badExtensions =
    [Arrows -- steals proc
    ,TransformListComp -- steals the group keyword
    ,XmlSyntax, RegularPatterns -- steals a-b
    ,UnboxedTuples -- breaks (#) lens operator
    ,QuasiQuotes -- breaks [x| ...], making whitespace free list comps break
    ]
