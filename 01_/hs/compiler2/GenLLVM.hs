{-# LANGUAGE FlexibleContexts #-}
module GenLLVM
    (GenLLVM,Local,Label,genLLVM,
     writeCode,writeLocal,writeLabel,writeLabelRef,
     newLocal,newLabel,writeNewLocal,writeNewLabel,writeNewLabelBack,
     forwardRefLabel,writeForwardRefLabel,writeBranch,forwardRefPhi,writePhi)
where

import Generate(Gen(..),Generate,ForwardGen,forwardRef,generate,putState)

type GenLLVM a = Generate FwdLLVM StLLVM String a

newtype Local = Local Int
newtype Label = Label Int

data FwdLLVM =
    FwdLabel Label
  | FwdPhi Local Label

data StLLVM = StLLVM Local Label

genLLVM :: GenLLVM () -> String
genLLVM gen = concat (generate gen (StLLVM (Local 0) (Label 0)))

writeCode :: Gen gen state String => String -> gen state String ()
writeCode code = gen code

writeLocal :: Gen gen state String => Local -> String -> gen state String ()
writeLocal (Local l) code = gen ("%" ++ show l ++ code)

writeLabel :: Gen gen state String => Label -> gen state String ()
writeLabel (Label l) = gen (" l" ++ show l ++ ":")

writeLabelRef :: Gen gen state String => Label -> String -> gen state String ()
writeLabelRef (Label l) code = gen ("%" ++ show l ++ code)

newLocal :: GenLLVM Local
newLocal = do
    StLLVM local@(Local l) label <- getState
    putState (StLLVM (Local (l+1)) label)
    return local

newLabel :: GenLLVM Label
newLabel = do
    StLLVM local label@(Label l) <- getState
    putState (StLLVM local (Label (l+1)))
    return label

writeNewLocal :: String -> GenLLVM Local
writeNewLocal code = do
    writeCode " "
    local <- newLocal
    writeLocal local (" = " ++ code)
    return local

writeNewLabel :: GenLLVM Label
writeNewLabel = do
    label <- newLabel
    writeLabel label
    return label

writeNewLabelBack :: [Label -> GenLLVM ()] -> GenLLVM Label
writeNewLabelBack forwardRefs = do
    label <- writeNewLabel
    mapM_ ($ label) forwardRefs
    return label

forwardRefLabel :: (Label -> ForwardGen StLLVM String ())
                -> GenLLVM (Label -> GenLLVM ())
forwardRefLabel useLabel = do
    fwdRef <- forwardRef (\ [FwdLabel label] -> useLabel label)
    return (\ label -> fwdRef (FwdLabel label))

writeForwardRefLabel :: GenLLVM (Label -> GenLLVM ())
writeForwardRefLabel = forwardRefLabel (flip writeLabelRef "")

writeBranch :: Local -> GenLLVM (Label -> GenLLVM (),Label -> GenLLVM())
writeBranch local = do
    writeCode " br i1 "
    writeLocal local ",label "
    trueLabelRef <- writeForwardRefLabel
    writeCode ",label "
    falseLabelRef <- writeForwardRefLabel
    return (trueLabelRef,falseLabelRef)

forwardRefPhi :: ([(Local,Label)] -> ForwardGen StLLVM String ())
              -> GenLLVM (Local -> Label -> GenLLVM())
forwardRefPhi usePhi = do
    fwdRef <- forwardRef (\ fwds -> usePhi (map (\ (FwdPhi local label) ->
                                                          (local,label))
                                                fwds))
    return (\ local label -> fwdRef (FwdPhi local label))

writePhi :: GenLLVM () -> Either String Local -> Label
         -> GenLLVM (Local,Local -> Label -> GenLLVM())
writePhi writeType value label = do
    local <- writeNewLocal "phi "
    writeType
    writeCode " ["
    either writeCode (flip writeLocal "") value
    writeCode ","
    writeLabelRef label "]"
    phiRef <- forwardRefPhi (mapM_ writePhiArg)
    return (local,phiRef)
  where
    writePhiArg (local,label) = do
        writeCode ",["
        writeLocal local ","
        writeLabelRef label "]"
