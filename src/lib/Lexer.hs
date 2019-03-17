
module Lexer where

import Utils
import Parser
import Tokenizer
import Exept
import ParserConfig

import Debug.Trace
import Data.List

data Identifier = Argument String | BindingTok String (Maybe Leaf)
	deriving (Show, Eq)

data Leaf =
	Lambda String [Leaf] |
	SubExpr [Leaf] |
	Variable Identifier
	deriving (Eq)

type Scope = [String]

lexString :: ParserConfig -> String -> Leaf
lexString cfg s = s |> tokenize cfg |> stripUseless |> lexGroup

lexGroup :: [Token] -> Leaf
lexGroup toks = toks |> makeTree [] |> fst |> lexTree []

lexTree :: Scope -> Tree -> Leaf
lexTree scope (Node t) =
	lexName scope (text t)
lexTree scope (Branch all) =
	case maybeArgIndex of
		Just argIndex ->
			getLambda scope all argIndex
		Nothing ->
			SubExpr $ map (lexTree scope) all
	where
		maybeArgIndex = findIndex isArg all

		isArg :: Tree -> Bool
		isArg (Branch b) =
			False
		isArg (Node t) =
			kind t == LambdaSymbol

getLambda :: Scope -> [Tree] -> Int -> Leaf
getLambda scope all argIndex =
	collectLambdas args
	where
		args :: [String]
		args = all |> take argIndex |> map castToName

		rest :: [Tree]
		rest = all |> drop (argIndex + 1)

		collectLambdas :: [String] -> Leaf
		collectLambdas [x] =
			Lambda x $ map (lexTree newscope) rest
		collectLambdas (x : xs) =
			Lambda x [collectLambdas xs]

		newscope :: Scope
		newscope = (reverse args) ++ scope

		castToName :: Tree -> String
		castToName (Branch bs) = error "Branch as a lambda argument"
		castToName (Node t)    = text t

	-- Lambda arg $ map (lexTree (arg : scope)) ts

lexName :: Scope -> String -> Leaf
lexName scope tex =
	if tex `elem` scope
	then Variable $ Argument tex
	else Variable $ BindingTok tex Nothing

data Tree =
	Branch [Tree] | Node Token
	deriving (Eq)

-- Tree and left-overs
makeTree :: [Tree] -> [Token] -> (Tree, [Token])
makeTree nodesBuff toks =
	if null toks
	then (close, [])
	else
		case kind t of
			CloseBracket ->
				(close, ts)
			OpenBracket  ->
				makeTree (childNode : nodesBuff) childRight
			_            ->
				makeTree (curNode : nodesBuff) ts

	where
		t  = head toks
		ts = tail toks

		curNode = Node t
		(childNode, childRight) = makeTree [] ts

		close :: Tree
		close =
			if null $ tail nodesBuff
			then head $ reverse nodesBuff
			else Branch $ reverse nodesBuff


-- UTILITY --

instance Show Tree where
	show t = showTree 0 t

showTree :: Int -> Tree -> String
showTree tabs (Node t)  = 
	'\n' : (take tabs $ repeat '\t')  ++ text t

showTree tabs (Branch []) = []
showTree tabs (Branch ((Node t) : ts)) =
	'\n' : (take tabs $ repeat '\t')  ++ text t ++ (showTree tabs $ Branch ts)
showTree tabs (Branch ((Branch ts) : tss)) =
	'\n' : (take tabs $ repeat '\t') ++ (showTree (tabs + 1) (Branch ts)) ++ (showTree tabs (Branch tss))

instance Show Leaf where
	show t = showLeaf 0 t

showLeaf :: Int -> Leaf -> String
showLeaf tabs (Variable t)  = 
	case t of
		Argument name ->
			prefixed name
		BindingTok name expr ->
			case expr of
				Just x  ->
					prefixed $ "{" ++ name ++ "}"
				Nothing ->
					prefixed $ "{" ++ name ++ " (?)}"
	where
		prefixed name = (take tabs $ repeat '\t') ++ name ++ "\n"

showLeaf tabs (SubExpr ts) =
	foldr (++) "" $ map (showLeaf (tabs + 1)) ts
	where
		prefixed name = (take tabs $ repeat '\t') ++ name ++ "\n"

showLeaf tabs (Lambda arg ts) =
	prefixed ("Lambda of [" ++ arg ++ "]:\n" ++ (foldr (++) "" $ map (showLeaf (tabs + 1)) ts))
	where
		prefixed name = (take tabs $ repeat '\t') ++ name

countVariables :: Leaf -> Int
countVariables (Variable _)     = 1
countVariables (Lambda _ leafs) = 1 + (sum $ map countVariables leafs)
countVariables (SubExpr leafs)  = sum $ map countVariables leafs
