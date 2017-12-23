{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecursiveDo #-}

module CodeGen.Runtime(
    runtimeDefs,
    runtimeDecls,
    memset,memcpy,malloc,free,
    newNode,
    intConst,nullConst,
    eq
)
where

import Data.Word(Word32)

import LLVM.AST(Definition(GlobalDefinition),Module)
import LLVM.AST.Constant(Constant(Array,GlobalReference,Int,Null,Struct),constantType,memberValues,integerBits,integerValue,isPacked,structName,memberType,memberValues)
import LLVM.AST.Global(initializer,name,type',globalVariableDefaults)
import LLVM.AST.Instruction(Instruction(GetElementPtr),inBounds,address,indices,metadata)
import LLVM.AST.IntegerPredicate(IntegerPredicate(UGE))
import qualified LLVM.AST.IntegerPredicate
import LLVM.AST.Name(Name)
import LLVM.AST.Operand(Operand(ConstantOperand))
import LLVM.AST.Type(Type(FunctionType,StructureType),void,i1,i8,i32,elementTypes,ptr,resultType,argumentTypes,isVarArg)
import qualified LLVM.AST.Type
import LLVM.IRBuilder.Instruction(add,bitcast,br,call,condBr,gep,icmp,load,phi,ptrtoint,ret,retVoid,store,sub)
import LLVM.IRBuilder.Module(ModuleBuilder,ParameterName(NoParameterName),emitDefn,extern,function,buildModule)
import LLVM.IRBuilder.Monad(emitInstr,block)

import CodeGen.Types(
    nodeTypeName,nodeType,pNodeType,ppNodeType,pppNodeType,nodeTypedef,
    pageSize,newPageThreshold,
    pageTypeName,pageType,pPageType,pageTypedef,
    frameTypeName,frameType,pFrameType,frameTypedef,
    doEdgesIteratorTypeName,doEdgesIteratorType,pDoEdgesIteratorType,doEdgesIteratorTypedef)

eq :: LLVM.AST.IntegerPredicate.IntegerPredicate
eq = LLVM.AST.IntegerPredicate.EQ

newNodeName :: Name
newNodeName = "newNode"

newNodeDecl :: ModuleBuilder Operand
newNodeDecl = extern newNodeName [pFrameType] nodeType

newNode :: Operand
newNode = ConstantOperand (GlobalReference (ptr (FunctionType {
    resultType = pNodeType,
    argumentTypes = [pFrameType],
    isVarArg = False
    })) newNodeName)

newNodeImpl :: ModuleBuilder Operand
newNodeImpl = function newNodeName [(pFrameType,NoParameterName)] pNodeType (\ [topFrame] -> mdo
    -- look for dead entries in the tables
    -- if none, garbage collect, then if last page is more than X% full,
    -- allocate a new last page
    -- then retry looking for dead entries
    br retryNewNode

    retryNewNode <- block
    initialPage <- gep globalState [intConst 32 0, intConst 32 1]
    br newNodePageLoop

    -- iterate over pages, for each page
    --   iterate over page.nodes, for each node
    --     if node.alive is 0
    --        set node.alive = 1
    --        return &node
    newNodePageLoop <- block
    newNodePage <- phi [
        (initialPage,retryNewNode),
        (newNodePage,newNodePageLoopNextIndex),
        (newNodeNextPage,newNodePageLoopNextPage)
        ]
    newNodeIndex <- phi [
        (intConst 32 0,retryNewNode),
        (newNodeNextIndex,newNodePageLoopNextIndex),
        (intConst 32 0,newNodePageLoopNextPage)
        ]
    newNodeAlivePtr <- gep newNodePage [intConst 32 0, intConst 32 1, newNodeIndex, intConst 32 1]
    newNodeAlive <- load newNodeAlivePtr 0
    condBr newNodeAlive newNodePageLoopNextIndex returnNewNode

    -- found free node
    returnNewNode <- block
    store newNodeAlivePtr 0 (intConst 1 1)
    newNodePtr <- gep newNodePage [intConst 32 0, intConst 32 1, newNodeIndex]
    ret newNodePtr

    -- iterate to next node in page
    newNodePageLoopNextIndex <- block
    newNodeNextIndex <- add newNodeIndex (intConst 32 1)
    newNodeIndexRangeCheck <- icmp UGE newNodeNextIndex (intConst 32 pageSize)
    condBr newNodeIndexRangeCheck newNodePageLoopNextPage newNodePageLoop

    -- iterate to next page
    newNodePageLoopNextPage <- block
    newNodeNextPagePtr <- gep newNodePage [intConst 32 0, intConst 32 0]
    newNodeNextPage <- load newNodeNextPagePtr 0
    newNodePageNullCheck <- icmp eq newNodeNextPage (nullConst pPageType)
    condBr newNodePageNullCheck startGCMark newNodePageLoop

    -- mark
    -- iterate over frames, for each frame
    --   iterate over vars, for each var
    --     call gcMark
    --   iterate over doEdgesIterators, for each doEdgesIterator
    --     iterate from iterator index to size of allocated array of edges
    --       call gcMark
    startGCMark <- block
    gcMarkPtr <- gep globalState [intConst 32 0, intConst 32 0]
    oldGcMark <- load gcMarkPtr 0
    newGcMark <- add oldGcMark (intConst 8 1)
    store gcMarkPtr 0 newGcMark
    br markFrameLoop

    -- iterate over frames
    markFrameLoop <- block
    frame <- phi [
        (topFrame,startGCMark),
        (markNextFrame,markDoEdgesIteratorsLoop)
        ]
    frameCheck <- icmp eq frame (nullConst pFrameType)
    condBr frameCheck startGCSweep markFrameLoopBody

    markFrameLoopBody <- block
    markNextFramePtr <- gep frame [intConst 32 0, intConst 32 0]
    markNextFrame <- load markNextFramePtr 0
    markVarArraySizePtr <- gep frame [intConst 32 0, intConst 32 1]
    markVarArraySize <- load markVarArraySizePtr 0
    markVarArrayPtr <- gep frame [intConst 32 0, intConst 32 2]
    markVarArray <- load markVarArrayPtr 0
    markDoEdgesIteratorsSizePtr <- gep frame [intConst 32 0, intConst 32 3]
    markDoEdgesIteratorsSize <- load markDoEdgesIteratorsSizePtr 0
    markDoEdgesIteratorsArrayPtr <- gep frame [intConst 32 0, intConst 32 4]
    markDoEdgesIteratorsArray <- load markDoEdgesIteratorsArrayPtr 0
    br markVarLoop

    -- iterate over vars in frame
    markVarLoop <- block
    markVarIndex <- phi [
        (intConst 32 0,markFrameLoop),
        (markVarNextIndex,markVarLoopBody)
        ]
    markVarNextIndex <- add markVarIndex (intConst 32 1)
    markVarIndexCheck <- icmp UGE markVarIndex markVarArraySize
    condBr markVarIndexCheck markDoEdgesIteratorsLoop markVarLoopBody

    -- mark var
    markVarLoopBody <- block
    markVarNodePtr <- gep markVarArray [markVarIndex]
    markVarNode <- load markVarNodePtr 0
    call gcMarkNode [(newGcMark,[]),(markVarNode,[])]
    br markVarLoop

    -- iterate over doEdgeIterators in frame
    markDoEdgesIteratorsLoop <- block
    markDoEdgesIteratorsIndex <- phi [
        (intConst 32 0,markVarLoop),
        (markDoEdgesIteratorsNextIndex,markIteratorEdgesLoop)
        ]
    markDoEdgesIteratorsNextIndex <- add markDoEdgesIteratorsIndex (intConst 32 1)
    markDoEdgesIteratorsIndexCheck <- icmp UGE markDoEdgesIteratorsIndex markDoEdgesIteratorsSize
    condBr markDoEdgesIteratorsIndexCheck markFrameLoop markDoEdgesIteratorLoopBody

    -- set up current doEdgeIterator
    markDoEdgesIteratorLoopBody <- block
    markIteratorEdgesInitialIndexPtr <- gep markDoEdgesIteratorsArray [markDoEdgesIteratorsIndex, intConst 32 0]
    -- workaround for
    -- *** Exception: gep: Can't index into a NamedTypeReference (Name "frame")
    -- caused by
    -- markIteratorEdgesInitialIndex <- load markIteratorEdgesInitialIndexPtr 0
    markIteratorEdgesInitialIndex_workaround <- load markIteratorEdgesInitialIndexPtr 0
    markIteratorEdgesInitialIndex <- bitcast markIteratorEdgesInitialIndex_workaround i32
    markIteratorEdgesSizePtr <- gep markDoEdgesIteratorsArray [markDoEdgesIteratorsIndex, intConst 32 1]
    markIteratorEdgesSize <- load markIteratorEdgesSizePtr 0
    markIteratorEdgesArrayPtr <- gep markDoEdgesIteratorsArray [markDoEdgesIteratorsIndex, intConst 32 2]
    markIteratorEdgesArray <- load markIteratorEdgesArrayPtr 0
    br markIteratorEdgesLoop

    -- iterate over edges in current doEdgeIterator
    markIteratorEdgesLoop <- block
    markIteratorEdgesIndex <- phi [
        (markIteratorEdgesInitialIndex,markDoEdgesIteratorLoopBody),
        (markIteratorEdgesNextIndex,markIteratorEdgesLoopBody)
        ]
    markIteratorEdgesNextIndex <- add markIteratorEdgesIndex (intConst 32 1)
    markIteratorEdgesIndexCheck <- icmp UGE markIteratorEdgesIndex markIteratorEdgesSize
    condBr markIteratorEdgesIndexCheck markDoEdgesIteratorsLoop markIteratorEdgesLoopBody

    -- mark edge
    markIteratorEdgesLoopBody <- block
    iteratorEdgePtr <- gep markIteratorEdgesArray [markIteratorEdgesIndex]
    iteratorEdge <- load iteratorEdgePtr 0
    call gcMarkNode [(newGcMark,[]),(iteratorEdge,[])]
    br markIteratorEdgesLoop

    -- sweep
    -- iterate over pages, for each page
    --   reset pageLiveCount to 0
    --   iterate over page.nodes, for each node
    --     if node.alive is 1
    --       if node.gcMark is not newGcMark
    --         set node.alive to 0
    --         if node.edgeArraySize > 0
    --           clear node.edgeArray
    --       else
    --         increment pageLiveCount
    -- if on last page,
    --   if pageLiveCount >= newPageThreshold,
    --     lastPage.nextPage = allocate and clear new page
    startGCSweep <- block
    br sweepPageLoop

    sweepPageLoop <- block
    sweepPage <- phi [
        (initialPage,startGCSweep),
        (sweepPage,sweepPageLoopNextIndex),
        (sweepNextPage,sweepPageLoopNextPage)
        ]
    sweepIndex <- phi [
        (intConst 32 0,startGCSweep),
        (sweepNextIndex,sweepPageLoopNextIndex),
        (intConst 32 0,sweepPageLoopNextPage)
        ]
    sweepPageLiveCount <- phi [
        (intConst 32 0,startGCSweep),
        (sweepNextPageLiveCount,sweepPageLoopNextIndex),
        (intConst 32 0,sweepPageLoopNextPage)
        ]
    sweepNodeAlivePtr <- gep sweepPage [intConst 32 0, intConst 32 1, sweepIndex, intConst 32 1]
    sweepNodeAlive <- load sweepNodeAlivePtr 0
    condBr sweepNodeAlive sweepCheckNode sweepPageLoopNextIndex

    sweepCheckNode <- block
    sweepGcMarkPtr <- gep sweepPage [intConst 32 0, intConst 32 1, sweepIndex, intConst 32 0]
    sweepGcMark <- load sweepGcMarkPtr 0
    sweepGcMarkCheck <- icmp eq newGcMark sweepGcMark
    incrementedPageLiveCount <- add sweepPageLiveCount (intConst 32 1)
    condBr sweepGcMarkCheck sweepPageLoopNextIndex sweepCollectNode

    sweepCollectNode <- block
    store sweepNodeAlivePtr 0 (intConst 1 0)
    sweepNodeEdgesSizePtr <- gep sweepPage [intConst 32 0, intConst 32 1, sweepIndex, intConst 32 2]
    sweepNodeEdgesSize <- load sweepNodeEdgesSizePtr 0
    sweepNodeEdgesSizeCheck <- icmp eq sweepNodeEdgesSize (intConst 32 0)
    condBr sweepNodeEdgesSizeCheck sweepPageLoopNextIndex sweepCollectNodeClearEdges

    sweepCollectNodeClearEdges <- block
    sweepNodeEdgesArrayPtr <- gep sweepPage [intConst 32 0, intConst 32 1, sweepIndex, intConst 32 3]
    sweepNodeEdgesArray <- load sweepNodeEdgesArrayPtr 0
    sweepNodeEdgesRawPtr <- bitcast sweepNodeEdgesArray (ptr i8)
    sweepNodeEdgesSizeofPtr <- gep (nullConst pNodeType) [sweepNodeEdgesSize]
    sweepNodeEdgesSizeof <- ptrtoint sweepNodeEdgesSizeofPtr i32
    call memset [
        (sweepNodeEdgesRawPtr,[]),
        (intConst 8 0,[]),
        (sweepNodeEdgesSizeof,[]),
        (intConst 32 0,[]),
        (intConst 1 0,[])
        ]
    br sweepPageLoopNextIndex

    sweepPageLoopNextIndex <- block
    sweepNextPageLiveCount <- phi [
        (sweepPageLiveCount,sweepPageLoop),
        (incrementedPageLiveCount,sweepPageLoop),
        (sweepPageLiveCount,sweepCollectNode),
        (sweepPageLiveCount,sweepCollectNodeClearEdges)
        ]
    sweepNextIndex <- add sweepIndex (intConst 32 1)
    sweepIndexRangeCheck <- icmp UGE sweepNextIndex (intConst 32 pageSize)
    condBr sweepIndexRangeCheck sweepPageLoopNextPage sweepPageLoop

    sweepPageLoopNextPage <- block
    sweepNextPagePtr <- gep sweepPage [intConst 32 0, intConst 32 0]
    sweepNextPage <- load sweepNextPagePtr 0
    sweepPageNullCheck <- icmp eq sweepNextPage (nullConst pPageType)
    condBr newNodePageNullCheck checkForNewPage sweepPageLoop

    checkForNewPage <- block
    newPageCheck <- icmp UGE sweepNextPageLiveCount (intConst 32 newPageThreshold)
    condBr newPageCheck newPage retryNewNode

    newPage <- block
    newPageSizeofPtr <- gep (nullConst pPageType) [intConst 32 1]
    newPageSizeof <- ptrtoint newPageSizeofPtr i32
    newPageRawPtr <- call malloc [(newPageSizeof,[])]
    call memset [
        (newPageRawPtr,[]),
        (intConst 8 0,[]),
        (newPageSizeof,[]),
        (intConst 32 0,[]),
        (intConst 1 0,[])
        ]
    newPagePtr <- bitcast newPageRawPtr pPageType
    store sweepNextPagePtr 0 newPagePtr
    br retryNewNode
    )

globalStateName :: Name
globalStateName = "globalState"

globalStateType :: Type
globalStateType = StructureType {
    LLVM.AST.Type.isPacked = False,
    elementTypes = [
        i8, -- gc mark
        pageType -- root page
        ]
    }

globalState :: Operand
globalState =
    ConstantOperand (GlobalReference (ptr globalStateType) globalStateName)

globalStateDef :: ModuleBuilder ()
globalStateDef = do
    emitDefn (GlobalDefinition globalVariableDefaults {
        name = globalStateName,
        type' = globalStateType,
        initializer = Just (Struct { -- zeroinitializer would have been nice
            structName = Nothing,
            isPacked = False,
            memberValues = [
                Int { integerBits = 8, integerValue = 0 },
                Struct {
                    structName = Just pageTypeName,
                    isPacked = False,
                    memberValues = [
                        Null { constantType = pPageType },
                        Array {
                            memberType = nodeType,
                            memberValues = replicate pageSize Struct {
                                structName = Just nodeTypeName,
                                isPacked = False,
                                memberValues = [
                                    Int { integerBits = 8, integerValue = 0 },
                                    Int { integerBits = 1, integerValue = 0 },
                                    Int { integerBits = 64, integerValue = 0 },
                                    Null { constantType = ppNodeType }
                                    ]
                                }
                            }
                        ]
                    }
                ]
            })
        })

gcMarkNodeName :: Name
gcMarkNodeName = "gcMarkNode"

gcMarkNode :: Operand
gcMarkNode = ConstantOperand (GlobalReference (ptr (FunctionType {
    resultType = void,
    argumentTypes = [i8,pNodeType],
    isVarArg = False
    })) gcMarkNodeName)

gcMarkNodeImpl :: ModuleBuilder Operand
gcMarkNodeImpl = do
    function gcMarkNodeName [(i8,NoParameterName),(pNodeType,NoParameterName)] void $ \ [gcMark,pNode] -> mdo
        -- if node is null, return
        nullCheck <- icmp eq pNode (nullConst pNodeType)
        condBr nullCheck done checkAlive

        -- if not node.alive, return
        checkAlive <- block
        alivePtr <- gep pNode [intConst 32 0, intConst 32 1]
        aliveCheck <- load alivePtr 0
        condBr aliveCheck checkGcMark done

        -- if node.gcMark = gcMark, return
        checkGcMark <- block
        nodeGcMarkPtr <- gep pNode [intConst 32 0, intConst 32 0]
        nodeGcMark <- load nodeGcMarkPtr 0
        nodeGcMarkCheck <- icmp eq gcMark nodeGcMark
        condBr nodeGcMarkCheck done checkEdgesInit

        checkEdgesInit <- block
        store nodeGcMarkPtr 0 gcMark
        nodeEdgesArraySizePtr <- gep pNode [intConst 32 0, intConst 32 2]
        nodeEdgesArraySize <- load nodeEdgesArraySizePtr 0
        nodeEdgesArrayPtr <- gep pNode [intConst 32 0, intConst 32 3]
        nodeEdgesArray <- load nodeEdgesArrayPtr 0
        br checkEdgesLoop

        checkEdgesLoop <- block
        edgeIndex <- phi [
            (intConst 32 0,checkEdgesInit),
            (nextEdgeIndex,checkEdgesLoopBody)
            ]
        -- if edgeIndex >= node.edgeArraySize, return
        edgeIndexCheck <- icmp UGE edgeIndex nodeEdgesArraySize
        condBr edgeIndexCheck done checkEdgesLoopBody
        
        checkEdgesLoopBody <- block
        edgeElementPtr <- gep nodeEdgesArray [edgeIndex]
        edgeElement <- load edgeElementPtr 0
        call gcMarkNode [(gcMark,[]),(edgeElement,[])]
        nextEdgeIndex <- add edgeIndex (intConst 32 1)
        br checkEdgesLoop

        done <- block
        retVoid

memsetName :: Name
memsetName = "llvm.memset.p0i8.i32"

memset :: Operand
memset = ConstantOperand (GlobalReference (ptr (FunctionType {
    resultType = void,
    argumentTypes = [ptr i8, i8, i32, i32, i1],
    isVarArg = False
    })) memsetName)

memsetDecl :: ModuleBuilder Operand
memsetDecl = extern memsetName [ptr i8,i8,i32,i32,i1] void

memcpyName :: Name
memcpyName = "llvm.memcpy.p0i8.i32"

memcpy :: Operand
memcpy = ConstantOperand (GlobalReference (ptr (FunctionType {
    resultType = void,
    argumentTypes = [ptr i8, ptr i8, i32, i32, i1],
    isVarArg = False
    })) memsetName)

memcpyDecl :: ModuleBuilder Operand
memcpyDecl = extern memcpyName [ptr i8,ptr i8,i32,i32,i1] void

mallocName :: Name
mallocName = "malloc"

malloc :: Operand
malloc = ConstantOperand (GlobalReference (ptr (FunctionType {
    resultType = ptr i8,
    argumentTypes = [i32],
    isVarArg = False
    })) mallocName)

mallocDecl :: ModuleBuilder Operand
mallocDecl = extern mallocName [i32] (ptr i8)

freeName :: Name
freeName = "free"

free :: Operand
free = ConstantOperand (GlobalReference (ptr (FunctionType {
    resultType = void,
    argumentTypes = [ptr i8],
    isVarArg = False
    })) freeName)

freeDecl :: ModuleBuilder Operand
freeDecl = extern freeName [ptr i8] void

intConst :: Word32 -> Integer -> Operand
intConst bits value =
    ConstantOperand (Int { integerBits = bits, integerValue = value })

nullConst :: Type -> Operand
nullConst t = ConstantOperand (Null { constantType = t })

runtimeDefs :: ModuleBuilder ()
runtimeDefs = do
    runtimeDecls
    globalStateDef
    gcMarkNodeImpl
    newNodeImpl
    return ()

runtimeDecls :: ModuleBuilder ()
runtimeDecls = do
    memsetDecl
    memcpyDecl
    mallocDecl
    freeDecl
    nodeTypedef
    pageTypedef
    frameTypedef
    doEdgesIteratorTypedef
    newNodeDecl
    return ()
