module Compiler(compile) where

import qualified Data.Map as Map

import Flattener(Expr(Arg,Quote,CarFn,CdrFn,ConsFn,If,Call))
import Reader(Value(Cons,Nil))

compile :: Map.Map Int (Value,Expr) -> Expr -> String
compile fns expr =
    let consts = constants fns expr
    in  unlines (map (compileConstant consts) (Map.assocs consts)
                 ++ concatMap (compileFn (Map.map fst fns) consts)
                              (Map.assocs fns)
                 ++ compileMain (Map.map fst fns) consts expr)

constants :: Map.Map Int (Value,Expr) -> Expr -> Map.Map Value Int
constants fns expr =
    Map.fold collectConstants
             (collectConstants expr (Map.insert Nil 0 Map.empty))
             (Map.map snd fns)
  where
    collectConstants :: Expr -> Map.Map Value Int -> Map.Map Value Int
    collectConstants Arg map = map
    collectConstants (Quote value) map = insertConstant map value
      where
        insertConstant map Nil = map
        insertConstant map value@(Cons head tail)
          | Map.member value map = map
          | otherwise =
                let map1 = insertConstant (insertConstant map head) tail
                in  Map.insert value (Map.size map1) map1
    collectConstants (CarFn expr) map = collectConstants expr map
    collectConstants (CdrFn expr) map = collectConstants expr map
    collectConstants (ConsFn expr1 expr2) map =
        collectConstants expr2 (collectConstants expr1 map)
    collectConstants (If expr1 expr2 expr3) map =
        collectConstants expr3
                         (collectConstants expr2 (collectConstants expr1 map))

compileConstant :: Map.Map Value Int -> (Value,Int) -> String
compileConstant consts (Nil,index) =
    "@C" ++ show index ++ " = global %val { i32 1, "
         ++ "%val* null, %val* null, %eval (i8*)* null, "
         ++ "void (i8*)* null, i8* null }"
compileConstant consts (Cons car cdr,index) =
    "@C" ++ show index ++ " = global %val { i32 1, "
         ++ "%val* @C" ++ show ((Map.!) consts car) ++ ", "
         ++ "%val* @C" ++ show ((Map.!) consts car) ++ ", "
         ++ "void (i8*)* null, i8* null }"

compileFn :: Map.Map Int Value -> Map.Map Value Int -> (Int,(Value,Expr))
                               -> [String]
compileFn names consts (index,(name,expr)) =
    compileFunc names consts ("@" ++ show index) expr

compileMain :: Map.Map Int Value -> Map.Map Value Int -> Expr -> [String]
compileMain names consts expr = compileFunc names consts "@(main)" expr

compileFunc :: Map.Map Int Value -> Map.Map Value Int -> String -> Expr
                                 -> [String]
compileFunc names consts name expr = undefined
