module Parser where

import Data.List
import Utils
import Exept
import ParserConfig

import Debug.Trace

findFirstChar :: String -> [Char] -> Maybe Int
findFirstChar s stops = findFirstCharR s 0
	where
		findFirstCharR :: String -> Int -> Maybe Int
		findFirstCharR []     _     = Nothing
		findFirstCharR (x:xs) index =
			if x `elem` stops
			then Just index
			else findFirstCharR xs (succ index)

findFirstSub :: String -> [String] -> Maybe Int
findFirstSub s subs = findFirstSubR s 0
	where
		findFirstSubR :: String -> Int -> Maybe Int
		findFirstSubR []       _     = Nothing
		findFirstSubR s@(x:xs) index =
			if any (`isPrefixOf` s) subs
			then Just index
			else findFirstSubR xs (succ index)

findNextBracket :: String -> Either Int Int
findNextBracket s = findNextBracketR s 0 0
	where
		findNextBracketR :: String -> Int -> Int -> Either Int Int
		findNextBracketR []         _     count =
			Left (-count)

		findNextBracketR ('(' : xs) index count =
			findNextBracketR xs (succ index) (succ count)
		findNextBracketR (')' : xs) index 0 =
			Left 1
		findNextBracketR (')' : xs) index 1 =
			Right index
		findNextBracketR (')' : xs) index count =
			findNextBracketR xs (succ index) (pred count)

		findNextBracketR (x:xs) index count =
			findNextBracketR xs (succ index) count


data BranchType = 
	LambdaBranch | 
	TokenBranch | -- A binding or constant expression
	ArgBranch |
	LeafBranch
	deriving (Show, Eq)

data Branch = Branch String [Branch] BranchType
	deriving (Show, Eq)

branchParse :: ParserConfig -> String -> ParseResult Branch
branchParse cfg sraw = do
	guard (null s) (SyntaxError "Empty branch")

	guard (isLambda && lambdaArgRaw == tail s) (SyntaxError "Lambda does not start")
	guard (isLambda && null lambdaBody) (SyntaxError "Lambda has empty body")

	-- return $ branchLoop afterLambdaArgs
	return $ Branch ("After = " ++ afterLambdaArgs) [] TokenBranch

	where
		isLambda = (lambdaDecl cfg) `isPrefixOf` s
		s = trim sraw

		lambdaArgRaw =
			case findFirstSub t [lambdaSymbol cfg] of
				Just i  -> take i t
				Nothing -> t
			where
				t = tail s
		lambdaArg = trim lambdaArgRaw

		lambdaBodyRaw = drop (1 + length lambdaArgRaw + length (lambdaSymbol cfg)) s
		lambdaBody = trim lambdaBodyRaw

		argumentBranches =
			if isLambda
			then [Branch lambdaArg [] ArgBranch]
			else []

		afterLambdaArgs =
			if isLambda
			then lambdaBody
			else s
