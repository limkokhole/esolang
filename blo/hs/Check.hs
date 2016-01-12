module Check
    (Ast(..),AstType(..),AstFunc(..),AstFuncSig(..),AstStmt(..),AstExpr(..),
     astTypeName,astTypeSize,astTypeField,astTypeIsBit,
     astFuncName,astFuncParams,astFuncType,
     astVarName,astVarType,
     astExprType,
     check)
where

import Control.Applicative(Applicative(..))
import Control.Monad(foldM,foldM_,liftM,unless,when,zipWithM)
import Data.Map(Map,elems,empty,fromList,insert,member)
import qualified Data.Map as M

import Parse
    (Error(..),SourcePos,
     Identifier(..),Definition(..),
     FuncHeader(..),TypeField(..),Var(..),
     Stmt(..),Expr(..),
     stmtSourcePos,exprSourcePos)

check :: [Definition] -> Either Error Ast
check defs = let Check result = runCheck in result
  where
    runCheck = do
        checkDuplicateTypes defs
        checkDuplicateFuncs defs
        types <- checkTypes defs
        funcSigs <- checkFuncSigs defs types
        funcs <- checkFuncs defs types funcSigs
        return (Ast (flip M.lookup types) (flip M.lookup funcs))

data Check a = Check (Either Error a)
  deriving Show

instance Monad Check where
    (Check a) >>= f = either (Check . Left) f a
    return = Check . Right
    fail = error

instance Functor Check where
    fmap f (Check a) = Check (either Left (Right . f) a)

instance Applicative Check where
    pure = return
    f <*> a = f >>= ($ a) . fmap
    a *> b = a >> b
    a <* b = a >>= (b >>) . return

checkError :: SourcePos -> String -> Check a
checkError pos msg = (Check . Left . Error pos) msg

checkDuplicateTypes :: [Definition] -> Check ()
checkDuplicateTypes defs = checkDuplicates "type" (concatMap t defs)
  where
    t (TypeDef pos (Identifier _ name) _) = [(pos,name)]
    t (TypeImport pos (Identifier _ name) _) = [(pos,name)]
    t _ = []

checkDuplicateFuncs :: [Definition] -> Check ()
checkDuplicateFuncs defs = checkDuplicates "func" (concatMap f defs)
  where
    f (FuncDef pos (FuncHeader (Identifier _ name) _ _) _) = [(pos,name)]
    f (FuncImport pos (FuncHeader (Identifier _ name) _ _)) = [(pos,name)]
    f _ = []

checkDuplicates :: String -> [(SourcePos,String)] -> Check ()
checkDuplicates label items = foldM_ checkItem empty items
  where
    checkItem set (pos,name)
      | member name set =
            checkError pos ("Duplicate " ++ label ++ " '" ++ name ++ "'")
      | otherwise = return (insert name () set)

data Ast = Ast (String -> Maybe AstType) (String -> Maybe AstFunc)

data AstType =
     AstType SourcePos String Int (String -> Maybe (Int,AstType))
   | AstImportType SourcePos String Int (String -> Maybe (Int,AstType))
   | AstTypeBit
data AstFunc =
    AstFunc AstFuncSig AstStmt
  | AstImportFunc AstFuncSig
data AstFuncSig = AstFuncSig SourcePos String [AstVar] (Maybe AstType)
data AstVar = AstVar String AstType
data AstStmt = AstStmt
data AstExpr =
    AstExprVar String AstType
  | AstExprFunc AstFuncSig [AstExpr]
  | AstExprField Int AstType AstExpr

instance Eq AstType where
    t1 == t2 = astTypeName t1 == astTypeName t2

astTypeName :: AstType -> String
astTypeName (AstType _ name _ _) = name
astTypeName (AstImportType _ name _ _) = name
astTypeName AstTypeBit = ""

astTypeSize :: AstType -> Int
astTypeSize (AstType _ _ size _) = size
astTypeSize (AstImportType _ _ size _) = size
astTypeSize AstTypeBit = 1

astTypeField :: AstType -> String -> Maybe (Int,AstType)
astTypeField (AstType _ _ _ getField) = getField
astTypeField (AstImportType _ _ _ getField) = getField
astTypeField AstTypeBit = const Nothing

astTypeIsBit :: AstType -> Bool
astTypeIsBit AstTypeBit = True
astTypeIsBit _ = False

astFuncName :: AstFunc -> String
astFuncName (AstFunc (AstFuncSig _ name _ _) _) = name
astFuncName (AstImportFunc (AstFuncSig _ name _ _)) = name

astFuncParams :: AstFunc -> [AstType]
astFuncParams (AstFunc (AstFuncSig _ _ params _) _) =
    map (\ (AstVar _ astType) -> astType) params
astFuncParams (AstImportFunc (AstFuncSig _ _ params _)) =
    map (\ (AstVar _ astType) -> astType) params

astFuncType :: AstFunc -> Maybe AstType
astFuncType (AstFunc (AstFuncSig _ _ _ returnType) _) = returnType
astFuncType (AstImportFunc (AstFuncSig _ _ _ returnType)) = returnType

astVarName :: AstVar -> String
astVarName (AstVar name _) = name

astVarType :: AstVar -> AstType
astVarType (AstVar _ astType) = astType

astExprType :: AstExpr -> AstType
astExprType (AstExprVar _ astType) = astType
astExprType (AstExprFunc (AstFuncSig _ _ _ (Just astType)) _) = astType
astExprType (AstExprField _ astType _) = astType

astStmtFallsThru :: AstStmt -> Bool
astStmtFallsThru = undefined

checkTypes :: [Definition] -> Check (Map String AstType)
checkTypes defs = do
    foldM_ checkDuplicateFieldNames empty (elems uncheckedTypes)
    mapM_ (checkFieldTypes empty) (elems uncheckedTypes)
    return checkedTypes
  where
    uncheckedTypes = fromList (concatMap uncheckedDef defs)
    uncheckedDef (FuncDef _ _ _) = []
    uncheckedDef (FuncImport _ _) = []
    uncheckedDef (TypeDef pos (Identifier _ name) fields) =
        [(name,(AstType,pos,name,fields))]
    uncheckedDef (TypeImport pos (Identifier _ name) fields) =
        [(name,(AstImportType,pos,name,fields))]

    checkDuplicateFieldNames set (_,pos,name,_)
      | member name set =
            checkError pos ("Duplicate field name '" ++ name ++ "'")
      | otherwise = return (insert name () set)

    checkFieldTypes set (_,pos,name,fields)
      | member name set =
            checkError pos ("Recursively defined type '" ++ name ++ "'")
      | otherwise = mapM_ (checkField (insert name () set)) fields
      where
        checkField set (TypeField _ Nothing) = return ()
        checkField set (TypeField _ (Just (Identifier pos typeName))) =
            maybe (checkError pos ("Unknown type '" ++ typeName ++ "'"))
                  (checkFieldTypes set) (M.lookup typeName uncheckedTypes)

    checkedTypes = fromList (map checkType (elems uncheckedTypes))
    checkType (astType,pos,name,fields) = (name,astType pos name size getField)
      where
        checkedFieldTypes = map lookupFieldType fields
          where
            lookupFieldType (TypeField (Identifier _ fieldName) Nothing) =
                (fieldName,AstTypeBit)
            lookupFieldType (TypeField (Identifier _ fieldName) (Just (Identifier _ typeName))) =
                (fieldName,checkedTypes M.! typeName)
        size = sum (map (astTypeSize . snd) checkedFieldTypes)
        getField fieldName = M.lookup fieldName fieldMap
          where
            (_,fieldMap) = foldl addFieldOffset (0,empty) checkedFieldTypes
            addFieldOffset (offset,fieldMap) (fieldName,fieldType) =
                (offset + astTypeSize fieldType,insert fieldName (offset,fieldType) fieldMap)

checkFuncSigs :: [Definition] -> Map String AstType -> Check (Map String AstFuncSig)
checkFuncSigs defs types = foldM checkDef empty defs
  where
    checkDef funcSigs (FuncDef pos funcHeader _) = checkSig funcSigs pos funcHeader
    checkDef funcSigs (FuncImport pos funcHeader) = checkSig funcSigs pos funcHeader
    checkDef funcSigs _ = return funcSigs
    checkSig funcSigs pos (FuncHeader (Identifier _ name) params returnType) = do
        astFuncType <- maybe (return Nothing) (liftM Just . checkType) returnType
        foldM_ checkDuplicateVar empty params
        astParams <- mapM checkVar params
        return (insert name (AstFuncSig pos name astParams astFuncType) funcSigs)
    checkType (Identifier pos typeName) =
        maybe (checkError pos ("Unknown type '" ++ typeName ++ "'"))
              return (M.lookup typeName types)
    checkDuplicateVar set (Var (Identifier pos name) _)
      | member name set =
            checkError pos ("Duplicate parameter '" ++ name ++ "'")
      | otherwise = return (insert name () set)
    checkVar (Var (Identifier _ name) paramType) = do
        astParamType <- checkType paramType
        return (AstVar name astParamType)

checkFuncs :: [Definition] -> Map String AstType -> Map String AstFuncSig -> Check (Map String AstFunc)
checkFuncs defs types funcSigs = do
    funcs <- foldM checkDef empty defs
    undefined
  where
    checkDef funcs (FuncDef pos (FuncHeader (Identifier _ name) _ _) stmt) = do
        let funcSig = funcSigs M.! name
        checkedStmt <- checkFuncBody funcSig stmt
        undefined
        return (insert name undefined funcs)
    checkDef funcs (FuncImport pos (FuncHeader (Identifier _ name) _ _)) = do
        let funcSig = funcSigs M.! name
        undefined
        return (insert name undefined funcs)
    checkDef funcs _ = return funcs

    checkFuncBody (AstFuncSig _ _ vars maybeRetType) stmt = do
        -- check fallthru if maybeRetType /= Nothing
        undefined

checkExpr :: Map String AstFuncSig -> Map String AstType -> Maybe AstType -> Expr -> Check AstExpr
checkExpr funcSigs scope expectedType (ExprVar (Identifier pos name)) = do
    astType <- maybe (checkError pos ("Unknown var '" ++ name ++ "'"))
                     return (M.lookup name scope)
    let xType = maybe astType id expectedType
    unless (xType == astType)
           (checkError pos ("Var '" ++ name ++ "' has type '" ++
                            astTypeName astType ++ "', need type '" ++
                            astTypeName xType ++ "'"))
    return (AstExprVar name astType)
checkExpr funcSigs scope expectedType (ExprFunc (Identifier pos name) params) = do
    funcSig@(AstFuncSig _ _ vars maybeRetType) <-
        maybe (checkError pos ("Unknown func '" ++ name ++ "'"))
              return (M.lookup name funcSigs)
    retType <- maybe (checkError pos ("Func '" ++ name ++
                                      "' returns no value"))
                     return maybeRetType
    let xType = maybe retType id expectedType
    unless (xType == retType)
           (checkError pos ("Func '" ++ name ++ "' returns type '" ++
                            astTypeName retType ++ "', need type '" ++
                            astTypeName xType ++ "'"))
    unless (length params == length vars)
           (checkError pos ("Func '" ++ name ++ "' takes " ++
                            show (length vars) ++ " parameter(s), given " ++
                            show (length params)))
    checkedParams <- zipWithM (checkExpr funcSigs scope)
                              (map (Just . astVarType) vars)
                              params
    return (AstExprFunc funcSig checkedParams)
checkExpr funcSigs scope expectedType (ExprField expr (Identifier pos name)) = do
    checkedExpr <- checkExpr funcSigs scope Nothing expr
    (offset,astType) <- maybe
        (checkError pos ("Unknown field name '" ++ name ++ "'"))
        return (astTypeField (astExprType checkedExpr) name)
    let xType = maybe astType id expectedType
    unless (xType == astType)
           (checkError pos ("Field '" ++ name ++ "' has type '" ++
                            astTypeName astType ++ "', need type '" ++
                            astTypeName xType ++ "'"))
    return (AstExprField offset astType checkedExpr)

checkStmt :: Map String AstType -> Map String AstFuncSig -> Map String AstType -> Map String () -> Maybe AstType -> Stmt -> Check AstStmt
checkStmt types funcSigs scope forLabels retType (StmtBlock pos stmts) = do
    checkedStmts <- fmap (reverse . snd)
                         (foldM checkBlockStmt ((True,scope),[]) stmts)
    undefined
  where
    checkBlockStmt ((False,_),_) stmt =
        checkError (stmtSourcePos stmt) "Unreachable statement"
    checkBlockStmt ((_,stmtScope),checkedStmts) stmt = do
        checkedStmt <- checkStmt types funcSigs stmtScope forLabels retType stmt
        let newScope = case checkedStmt of
                           -- add if var stmt
                           _ -> stmtScope
        return ((astStmtFallsThru checkedStmt,newScope),checkedStmt:checkedStmts)
checkStmt types funcSigs scope forLabels retType (StmtVar _ (Var (Identifier varPos name) (Identifier typePos typeName)) maybeExpr) = do
    when (member name scope)
         (checkError varPos ("Duplicate var name '" ++ name ++ "'"))
    astType <- maybe (checkError typePos ("Unknown type '" ++ typeName ++ "'"))
                     return (M.lookup typeName types)
    maybeCheckedExpr <-
        maybe (return Nothing)
              (fmap Just . checkExpr funcSigs scope (Just astType)) maybeExpr
    undefined
checkStmt types funcSigs scope forLabels retType (StmtIf _ expr stmt elseStmt) = do
    checkedExpr <- checkExpr funcSigs scope (Just AstTypeBit) expr
    checkedStmt <- checkStmt types funcSigs scope forLabels retType stmt
    checkedElse <- maybe (return Nothing)
                         (fmap Just . checkStmt types funcSigs scope forLabels retType)
                         elseStmt
    undefined
checkStmt types funcSigs scope forLabels retType (StmtFor _ maybeLabel stmt) = do
    let labels = insert (maybe "" (\ (Identifier _ label) -> label) maybeLabel)
                        () forLabels
    checkedStmt <- checkStmt types funcSigs scope labels retType stmt
    undefined
checkStmt types funcSigs scope forLabels retType (StmtBreak pos Nothing) = do
    unless (member "" forLabels)
           (checkError pos "Break must be contained in for")
    undefined
checkStmt types funcSigs scope forLabels retType (StmtBreak pos (Just (Identifier _ label))) = do
    unless (member "" forLabels)
           (checkError pos ("Break must be contained in for with label '" ++
                            label ++ "'"))
    undefined
checkStmt types funcSigs scope forLabels retType (StmtReturn pos Nothing) = do
    maybe (return ())
          (checkError pos . ("Must return value of type '" ++) .
                            (++ "'") . astTypeName)
          retType
    undefined
checkStmt types funcSigs scope forLabels retType (StmtReturn pos (Just expr)) = do
    checkedExpr <- maybe (checkError pos "Cannot return value")
                         (flip (checkExpr funcSigs scope) expr . Just)
                         retType
    undefined
checkStmt types funcSigs scope forLabels retType (StmtSetClear pos bit expr) = do
    checkedExpr <- checkExpr funcSigs scope (Just AstTypeBit) expr
    undefined
checkStmt types funcSigs scope forLabels retType (StmtAssign pos lhs rhs) = do
    checkedLhs <- checkExpr funcSigs scope Nothing lhs
    checkedRhs <- checkExpr funcSigs scope (Just (astExprType checkedLhs)) rhs
    undefined
checkStmt types funcSigs scope forLabels retType (StmtExpr expr) = do
    checkedExpr <- checkExpr funcSigs scope Nothing expr
    undefined
