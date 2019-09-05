
module Lexer where

import Utils
import Tokenizer
import Exept
import CompilerConfig

import Debug.Trace
import Data.List
import Data.Maybe

data Identifier = Argument String | BindingTok String (Maybe Leaf)
	deriving (Eq, Show, Read)

data Leaf =
	Abstraction Scope String [Leaf] |
	Application Scope [Leaf] |
	Variable Scope Identifier
	deriving (Eq, Show, Read)

type Scope = [String]

lexGroup :: [Token] -> Leaf
lexGroup toks = toks |> makeTree [] |> fst |> lexTree []

lexTree :: Scope -> Tree -> Leaf
lexTree scope (Node t) =
	lexName scope (text t)
lexTree scope (Branch all) =
	case maybeLambdaIndex of
		Just argIndex ->
			getAbstraction scope (reverse droped) (reverse taken)
			where (taken, droped) = splitAt argIndex reversed
		Nothing ->
			Application scope $ map (lexTree scope) all
	where
		maybeLambdaIndex = findIndex isLambdaTree reversed
		reversed = reverse all

getAbstraction :: Scope -> [Tree] -> [Tree] -> Leaf
getAbstraction scope argsLeafs rest =
	collectArguments args
	where
		args = argsLeafs |> map castToName |> catMaybes

		collectArguments :: [String] -> Leaf
		collectArguments [] = error "Zero arguments in lambda"
		collectArguments [x] =
			Abstraction scope x $ map (lexTree newscope) rest
		collectArguments (x : xs) =
			Abstraction scope x [collectArguments xs]

		newscope :: Scope
		newscope = (reverse args) ++ scope

		castToName :: Tree -> Maybe String
		castToName (Branch bs) = error "Branch as a lambda argument"
		castToName (Node t)    =
			case kind t of
				LambdaSymbol -> Nothing
				_            -> Just $ text t

lexName :: Scope -> String -> Leaf
lexName scope tex =
	if tex `elem` scope
	then Variable scope $ Argument tex
	else Variable scope $ BindingTok tex Nothing

data Tree =
	Branch [Tree] | Node Token
	deriving (Eq, Show, Read)

-- Tree and left-overs
makeTree :: [Tree] -> [Token] -> (Tree, [Token])
makeTree nodesBuff toks =
	case toks of
		[] -> (close, [])
		(t : ts) -> withTandTs t ts
	where
		withTandTs t ts = case kind t of
			CloseBracket ->
				(close, ts)
			OpenBracket  ->
				makeTree (childNode : nodesBuff) childRight
			_            ->
				makeTree (curNode : nodesBuff) ts
			where
			curNode = Node t
			(childNode, childRight) = makeTree [] ts

		close :: Tree
		close =
			if null nodesBuff
			then Branch []
			else
				if null $ tail nodesBuff
				then last nodesBuff
				else Branch $ reverse nodesBuff


-- UTILITY --

isLambdaTree :: Tree -> Bool
isLambdaTree (Branch b) =
	False
isLambdaTree (Node t) =
	kind t == LambdaSymbol

stringifyTree :: Tree -> String
stringifyTree = showTree 0

showTree :: Int -> Tree -> String
showTree tabs (Node t)  = 
	'\n' : (replicate tabs '\t')  ++ text t

showTree tabs (Branch []) = []
showTree tabs (Branch ((Node t) : ts)) =
	'\n' : (replicate tabs '\t')  ++ text t ++ (showTree tabs $ Branch ts)
showTree tabs (Branch ((Branch ts) : tss)) =
	'\n' : (replicate tabs '\t') ++ (showTree (tabs + 1) (Branch ts)) ++ (showTree tabs (Branch tss))

stringifyLeaf :: Leaf -> String
stringifyLeaf = showLeaf 0

showLeaf :: Int -> Leaf -> String
showLeaf tabs (Variable _ t)  = 
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
		prefixed name = (replicate tabs '\t') ++ name ++ "\n"

showLeaf tabs (Application _ ts) =
	concatMap (showLeaf (tabs + 1)) ts
	where
		prefixed name = (replicate tabs '\t') ++ name ++ "\n"

showLeaf tabs (Abstraction _ arg ts) =
	prefixed ("Abstraction of [" ++ arg ++ "]:\n" ++ (concatMap (showLeaf (tabs + 1)) ts))
	where
		prefixed name = (replicate tabs '\t') ++ name

countVariables :: Leaf -> Int
countVariables (Variable _ _)     = 1
countVariables (Abstraction _ _ leafs) = 1 + (sum $ map countVariables leafs)
countVariables (Application _ leafs)  = sum $ map countVariables leafs

foldLeaf :: (Leaf -> a -> a) -> a -> Leaf -> a
foldLeaf f acc v@(Variable scope id) = f v acc
foldLeaf f acc l@(Abstraction scope argname leafs) = foldr (foldLeafFlip f) (f l acc) leafs
foldLeaf f acc s@(Application scope leafs) = foldr (foldLeafFlip f) (f s acc) leafs

foldLeafFlip :: (Leaf -> a -> a) -> Leaf -> a -> a
foldLeafFlip f a b = foldLeaf f b a

leafIsArgument :: Leaf -> Bool
leafIsArgument (Variable scope id) =
	case id of
		(Argument name) -> True
		_ -> False
leafIsArgument _ = False

leafIsVariable :: Leaf -> Bool
leafIsVariable x =
	case x of
		(Variable scope id) -> True
		_                   -> False
