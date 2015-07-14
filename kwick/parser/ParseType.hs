module ParseType
	(parseType
	,parseArgDefInterface)
where

import Control.Applicative ((<$>), (<*>))
import Data.Maybe (fromMaybe)

import Syntax
import Parse
import ParseIdent
import ParseSpace

parseOpaqueType :: Parse Char [Type]
parseOpaqueType = greedy $ do
	name <- parseUnresolvedIdent
	return [OpaqueType name]

parseTemplateParameterType :: Parse Char [Type]
parseTemplateParameterType = greedy $ do
	lit '$'
	name <- parseLocalIdent
	return [TemplateParameterType name]

parseParenthesizedTypes :: Parse Char [Type]
parseParenthesizedTypes = kparenthesized parseType

parseArgDefInterface :: Parse Char ArgumentDefInterface
parseArgDefInterface = do
	staticMode <- parseEither
		(lits "static" >> kspace >> return StaticArg)
		(return RuntimeArg)
	maybeName <- optional $ do
		lit '#'
		optional kspace
		name <- parseLocalIdent
		optional kspace
		lit ':'
		optional kspace
		return name
	t <- parseType
	return $ ArgumentDefInterface staticMode maybeName t

parseFunctionTypeArgs :: Parse Char [ArgumentDefInterface]
parseFunctionTypeArgs = kparenthesized parseArgDefInterface

parseFunctionType :: Parse Char [Type]
parseFunctionType = do
	lits "func"
	optional kspace
	args <- parseFunctionTypeArgs
	optional kspace
	lits "->"
	optional kspace
	rets <- parseParenthesizedTypes
	return [FunctionType args rets]

parseAtomicType :: Parse Char [Type]
parseAtomicType = choice
	[parseOpaqueType
	,parseTemplateParameterType
	,parseParenthesizedTypes
	,parseFunctionType]

parseTemplateType :: [Type] -> Parse Char [Type]
parseTemplateType types = do
	optional kspace
	name <- parseUnresolvedIdent
	return [TemplateType name types]

unaryKindParser :: (Type -> Type) -> Char -> [Type] -> Parse Char [Type]
unaryKindParser f char [t] = do
	optional kspace
	lit char
	return [f t]
unaryKindParser _ _ _ = parseFailure

parseType :: Parse Char Type
parseType = do
	types <- chainNest parseAtomicType
		[parseTemplateType
		,unaryKindParser ReferenceType '!'
		,unaryKindParser NullableType '?'
		,unaryKindParser PointerType '&']
	case types of
		[t] -> return t
		_ -> parseFailure
