module LLVMCodeGen
    (codeGen)
where

import Control.Monad(foldM,unless,zipWithM_)
import qualified Data.Set as Set
import Data.Map(Map)
import qualified Data.Map as Map

import LLVMGen
    (CodeGen,Label,Temp,
     newTemp,newLabel,forwardRef,forwardRefTemp,forwardRefLabel,
     writeNewTemp,writeNewLabel,writeCode,writeRefCountType,writeOffsetType,
     writeTemp,writeLabel,writeLabelRef,writeName,writeBranch,
     gen)
import LLVMRuntime(LLVMRuntimeType(..),LLVMRuntimeFunc(..))
import LowLevel
    (Type(..),Func(..),FuncSig(..),Stmt(..),Expr(..),StmtKey,
     funcMaxAliases,stmtLeavingScope,stmtNext,stmtKey)

codeGen :: ([(String,Type LLVMRuntimeType)],
            [(String,Func LLVMRuntimeType LLVMRuntimeFunc)]) -> String
codeGen (types,funcs) =
    uniq (concatMap (map genCode . typeDecls . snd) types
            ++ concatMap (map genCode . funcDecls . snd) funcs
            ++ map genCode builtinDecls)
        ++ concatMap genCode (builtinDefns maxAliases)
        ++ concatMap (genCode . codeGenFunc) funcs
  where
    uniq = concat . Set.toList . Set.fromList
    maxOffset = maximum (map (\ (_,Type bitSize _) -> bitSize) types)
    maxAliases = maximum (map (funcMaxAliases . snd) funcs)
    genCode = gen maxAliases maxOffset

    typeDecls (Type _ rtt) = concatMap rttTypeDecls rtt
    rttTypeDecls (LLVMRuntimeType decls) = decls
    funcDecls (ImportFunc _ (LLVMRuntimeFunc decls _)) = decls
    funcDecls _ = []

builtinDecls :: [CodeGen ()]
builtinDecls = [
    (do writeCode "declare void @llvm.memset.p0i8."
        writeOffsetType
        writeCode "(i8*,i8,"
        writeOffsetType
        writeCode ",i32,i1)")
    ]

builtinDefns :: Int -> [CodeGen ()]
builtinDefns maxAliases = [
    writeBuiltinCopy
    ] ++ map writeBuiltinAlloc [2..maxAliases]

codeGenFunc :: (String,Func LLVMRuntimeType LLVMRuntimeFunc) -> CodeGen ()
codeGenFunc (_,ImportFunc _ (LLVMRuntimeFunc _ importFunc)) = importFunc
codeGenFunc (name,Func funcSig stmt) = writeFunc name funcSig stmt

writeRetType :: Maybe (Type LLVMRuntimeType) -> CodeGen ()
writeRetType Nothing = writeCode "void"
writeRetType (Just (Type _ rtt)) = do
    writeCode "{{"
    writeRefCountType
    writeCode ",[0 x i1]}*,"
    writeOffsetType
    unless (null rtt) (writeCode (",[" ++ show (length rtt) ++ " x i8*]"))
    writeCode "}"

writeFunc :: String -> FuncSig LLVMRuntimeType LLVMRuntimeFunc
                    -> Stmt LLVMRuntimeType LLVMRuntimeFunc
                    -> CodeGen ()
writeFunc name (FuncSig params retType) stmt = do
    writeCode "define "
    writeRetType retType
    writeCode " @"
    writeName name
    let paramScope =
            zipWith (\ index param -> fmap ((,) index) param) [0..] params
    writeCode "("
    zipWithM_ writeParam ("":repeat ",") paramScope
    maybe (return ()) (writeRetParam (if null params then "" else ",")) retType
    writeCode ") {"
    entry <- writeNewLabel

    let varParams = varMaxAliasesAndSizes stmt
    varAllocSizes <- foldM (\ sizes size -> do
        bitPtr <- writeNewBitPtr (Right "null") (Right (show size))
        sizeVar <- writeNewTemp
        writeCode "ptrtoint i1* "
        writeTemp bitPtr
        writeCode " to "
        writeOffsetType
        return (Map.insert size sizeVar sizes))
        Map.empty ((Set.toList . Set.fromList . map (snd . snd)) varParams)
    varAllocsList <- mapM (\ (varKey,(aliases,size)) -> do
        allocItems <- (sequence . take aliases . repeat) (do
            rawPtr <- writeNewTemp
            writeCode "alloca "
            writeOffsetType
            writeCode ","
            writeOffsetType
            writeCode " "
            writeTemp (varAllocSizes Map.! size)
            allocPtr <- writeNewTemp
            writeCode "bitcast i8* "
            writeTemp rawPtr
            writeCode " to "
            writeValueType
            writeCode "*"
            return (allocPtr,do -- clear alloca
                writeCode " call void @llvm.memset.p0i8."
                writeOffsetType
                writeCode "(i8* "
                writeTemp rawPtr
                writeCode ",i8 0,"
                writeOffsetType
                writeCode " "
                writeTemp (varAllocSizes Map.! size)
                writeCode ",i32 0,i1 0)"))
        return (varKey,allocItems))
        varParams
    varAllocs <- foldM (\ allocs (varKey,items) -> do
        sequence_ (map snd items) -- clear allocas
        return (Map.insert varKey (map fst items) allocs))
        Map.empty varAllocsList

    scope <- foldM (\ vars (name,(index,varType@(Type _ rtt))) -> do
        value <- writeNewTemp
        writeCode "select i1 1,"
        writeValueType
        writeCode ("* %value" ++ show index ++ ",")
        writeValueType
        writeCode "* null"
        offset <- writeNewTemp
        writeCode "select i1 1,"
        writeOffsetType
        writeCode (" %offset" ++ show index ++ ",")
        writeOffsetType
        writeCode " 0"
        imp <- if null rtt
            then return Nothing
            else do
                imp <- writeNewTemp
                writeCode ("select i1 1, [" ++ show (length rtt)
                                            ++ " x i8*] %import" ++ show index)
                return (Just imp)
        writeAddRef (value,offset,imp,varType)
        return (Map.insert name (value,offset,imp,varType) vars))
        Map.empty paramScope

    writeStmt varAllocs scope Map.empty
    writeCode " }"

writeValueType :: CodeGen ()
writeValueType = do
    writeCode "{"
    writeRefCountType
    writeCode ",[0 x i1]}"

writeParam :: String -> (String,(Int,Type LLVMRuntimeType)) -> CodeGen ()
writeParam comma (_,(index,Type _ rtt)) = do
    writeCode comma
    writeValueType
    writeCode ("* %value" ++ show index ++ ",")
    writeOffsetType
    writeCode (" %offset" ++ show index)
    unless (null rtt)
        (writeCode (",[" ++ show (length rtt) ++ " x i8*] %import"
                         ++ show index))

writeRetParam :: String -> Type LLVMRuntimeType -> CodeGen ()
writeRetParam comma retType = do
    writeCode comma
    writeValueType
    writeCode "* %retval"

writeNewBitPtr :: Either Temp String -> Either Temp String -> CodeGen Temp
writeNewBitPtr value index = do
    bitPtr <- writeNewTemp
    writeCode "getelementptr "
    writeValueType
    writeCode ","
    writeValueType
    writeCode "* "
    either writeTemp writeCode value
    writeCode ",i32 0,i32 1,"
    writeOffsetType
    writeCode " "
    either writeTemp writeCode index
    return bitPtr

writeAddRef :: (Temp,Temp,Maybe Temp,Type LLVMRuntimeType) -> CodeGen ()
writeAddRef (value,_,imp,Type _ rtt) = do
    refCountPtr <- writeNewTemp
    writeCode "getelementptr "
    writeValueType
    writeCode ","
    writeValueType
    writeCode "* "
    writeTemp value
    writeCode ",i32 0,i32 0"
    oldRefCount <- writeNewTemp
    writeCode "load "
    writeRefCountType
    writeCode ","
    writeRefCountType
    writeCode "* "
    writeTemp refCountPtr
    newRefCount <- writeNewTemp
    writeCode "add "
    writeRefCountType
    writeCode " 1,"
    writeTemp oldRefCount
    writeCode " store "
    writeRefCountType
    writeCode " "
    writeTemp newRefCount
    writeCode ","
    writeRefCountType
    writeCode "* "
    writeTemp refCountPtr
    -- undefined: rtt addRef

writeStmt :: Map StmtKey [Temp] -> Map String (Temp,Temp,Maybe Temp,
                                               Type LLVMRuntimeType)
                                -> Map StmtKey () -- as yet undefined
                                -> CodeGen ()
writeStmt varAllocs scope something_undefined_for_forward_refs = do
    writeCode " ret void" -- undefined

writeBuiltinCopy :: CodeGen ()
writeBuiltinCopy = do
    writeCode "define void @copy("
    writeValueType
    writeCode "* %srcval,"
    writeOffsetType
    writeCode " %srcoffset,"
    writeValueType
    writeCode "* %destval,"
    writeOffsetType
    writeCode " %destoffset,"
    writeOffsetType
    writeCode " %bitsize) {"
    entry <- writeNewLabel
    writeCode " br label "
    loopRef <- forwardRefLabel writeLabelRef
    loop <- writeNewLabel
    loopRef loop
    index <- writeNewTemp
    writeCode "phi "
    writeOffsetType
    writeCode "[0,"
    writeLabelRef entry
    writeCode "],"
    iterateRef <- forwardRef (\ ((newIndex,newLabel):_) -> do
        writeCode "["
        writeTemp newIndex
        writeCode ","
        writeLabelRef newLabel
        writeCode "]")
    cmp <- writeNewTemp
    writeCode "icmp ult "
    writeOffsetType
    writeCode " "
    writeTemp index
    writeCode ",%bitsize"
    (continueLabelRef,retLabelRef) <- writeBranch cmp
    continueLabel <- writeNewLabel
    continueLabelRef continueLabel
    srcIndex <- writeNewTemp
    writeCode "add "
    writeOffsetType
    writeCode " %srcoffset,"
    writeTemp index
    srcPtr <- writeNewTemp
    writeCode "getelementptr "
    writeValueType
    writeCode ","
    writeValueType
    writeCode "* %srcval,i32 0,i32 1,"
    writeOffsetType
    writeCode " "
    writeTemp srcIndex
    srcBit <- writeNewTemp
    writeCode "load i1,i1* "
    writeTemp srcPtr
    destIndex <- writeNewTemp
    writeCode "add "
    writeOffsetType
    writeCode " %destoffset,"
    writeTemp index
    destPtr <- writeNewTemp
    writeCode "getelementptr "
    writeValueType
    writeCode ","
    writeValueType
    writeCode "* %destval,i32 0,i32 1,"
    writeOffsetType
    writeCode " "
    writeTemp destIndex
    writeCode " store i1 "
    writeTemp srcBit
    writeCode ",i1* "
    writeTemp destPtr
    newIndex <- writeNewTemp
    iterateRef (newIndex,continueLabel)
    writeCode "add "
    writeOffsetType
    writeCode " 1,"
    writeTemp index
    writeCode " br label "
    writeLabelRef loop
    retLabel <- writeNewLabel
    retLabelRef retLabel
    writeCode " ret void }"

writeBuiltinAlloc :: Int -> CodeGen ()
writeBuiltinAlloc n = do
    writeCode "define "
    writeValueType
    writeCode ("* @alloc" ++ show n ++ "(")
    zipWithM_ param ("":repeat ",") [0..n-1]
    writeCode ") {"
    writeNewLabel
    labelRef <- foldM writeAlloc (const (return ())) [0..n-1]
    label <- writeNewLabel
    labelRef label
    writeCode " ret "
    writeValueType
    writeCode "* null }"
  where
    param comma i = do
        writeCode comma
        writeValueType
        writeCode ("* %a" ++ show i)
    writeAlloc labelRef i = do
        label <- writeNewLabel
        labelRef label
        ptr <- writeNewTemp
        writeCode "getelementptr "
        writeValueType
        writeCode ","
        writeValueType
        writeCode ("* %a" ++ show i ++ ",i32 0,i32 0")
        refCount <- writeNewTemp
        writeCode "load "
        writeRefCountType
        writeCode "* "
        writeTemp ptr
        cmp <- writeNewTemp
        writeCode "icmp eq "
        writeRefCountType
        writeCode " 0,"
        writeTemp refCount
        (trueLabelRef,falseLabelRef) <- writeBranch cmp
        trueLabel <- writeNewLabel
        trueLabelRef trueLabel
        writeCode " ret "
        writeValueType
        writeCode "* "
        writeTemp ptr
        return falseLabelRef

varMaxAliasesAndSizes :: Stmt LLVMRuntimeType LLVMRuntimeFunc
                         -> [(StmtKey,(Int,Int))]
varMaxAliasesAndSizes (StmtBlock _ stmts) =
    concatMap varMaxAliasesAndSizes stmts
varMaxAliasesAndSizes stmt@(StmtVar _ _ (Type bitSize _) maxAliases _) =
    [(stmtKey stmt,(maxAliases,bitSize))]
varMaxAliasesAndSizes (StmtIf _ _ ifBlock elseBlock) =
    varMaxAliasesAndSizes ifBlock ++ (maybe [] varMaxAliasesAndSizes elseBlock)
varMaxAliasesAndSizes (StmtFor _ stmt) = varMaxAliasesAndSizes stmt
varMaxAliasesAndSizes _ = []
