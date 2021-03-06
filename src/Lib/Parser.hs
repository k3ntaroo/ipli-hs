module Lib.Parser (
  Result(..),
  ParserT(..),
  Parser,
  runParser,
  parser,
  failParser,
  failParse,
  ) where

import           Lib.Result (Result(..))

import           Control.Applicative
import           Control.Monad
import           Control.Monad.Trans.Class
import           Data.Functor.Identity

data ParserT s m o = ParserT { runParserT :: s -> m (Result o, s) }

type Parser s o = ParserT s Identity o

runParser :: Parser s o -> s -> (Result o, s)
runParser p st = runIdentity $ runParserT p st

parser :: (s -> (Result o, s)) -> Parser s o
parser f = ParserT (Identity . f)

failParser :: (Monad m) => ParserT s m o
failParser = ParserT $ \st -> return (Fail "failParser", st)

instance Monad m => Functor (ParserT s m) where
  {-# INLINE fmap #-}
  fmap f p = ParserT $ \st -> do
    res <- runParserT p st
    return $ case res of
               (OK o, st') -> (OK (f o), st')
               (Fail msg, _) -> (Fail msg, st)

instance Monad m => Applicative (ParserT s m) where
  {-# INLINE pure #-}
  pure x = ParserT $ \st -> return (OK x, st)

  {-# INLINE (<*>) #-}
  x <*> y = ParserT $ \st -> do
    (v, st') <- runParserT x st
    case v of
      Fail msg -> return (Fail msg, st)
      OK f -> runParserT (f <$> y) st'

instance Monad m => Alternative (ParserT s m) where
  empty = failParser

  {-# INLINE (<|>) #-}
  p <|> q = ParserT $ \st -> do
    (v, st') <- runParserT p st
    case v of
      Fail _ -> runParserT q st
      _      -> return (v, st')

  {-# INLINE many #-}
  many p = ParserT $ \st -> do
    (v, st') <- runParserT p st
    case v of
      Fail _ -> return (OK [], st)
      OK w   -> runParserT ((w:) <$> many p) st'

  {-# INLINE some #-}
  some p = (:) <$> p <*> many p

instance Monad m => Monad (ParserT s m) where
  {-# INLINE return #-}
  return = pure

  {-# INLINE (>>=) #-}
  x >>= f = ParserT $ \st -> do
    (y, st') <- runParserT x st
    case y of
      Fail msg -> return (Fail msg, st)
      OK v     -> runParserT (f v) st'

instance Monad m => MonadPlus (ParserT s m) where
  mzero = empty
  mplus = (<|>)

-- data ParserT s m o = ParserT { runParserT :: s -> m (Result o, s) }

instance MonadTrans (ParserT s) where
  -- lift :: (Monad m) => m a -> ParserT s m a
  lift m = ParserT $ \st -> do
    v <- m
    return (OK v, st)

failParse :: Monad m => String -> ParserT s m a
failParse msg = ParserT $ \st -> return (Fail msg, st)
