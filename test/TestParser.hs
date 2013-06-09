{-# LANGUAGE OverloadedStrings, FlexibleContexts #-}
import           Data.Functor.Identity (Identity)
import qualified Test.HUnit                           as HU
import           Test.Framework
import           Test.Framework.Providers.HUnit
import           Language.Slice.Syntax.Parser
import           Language.Slice.Syntax.AST

import qualified Text.Parsec as P
import qualified Text.Parsec.Error as PE

instance Eq PE.ParseError where
  e1 == e2 = PE.errorPos e1 == PE.errorPos e2 && PE.errorMessages e1 == PE.errorMessages e2
  
testParse :: P.Stream s Data.Functor.Identity.Identity t =>
             P.Parsec s () a -> s -> Either PE.ParseError a  
testParse p = parse p "String"

testCases :: HU.Test
testCases = HU.TestList
  [ " type 1"          HU.~: Right (STUserDefinedPrx (NsQualIdent "MyType" [])) HU.@=? (testParse parseType "MyType*")
  , " field 1"         HU.~: Right (FieldDecl (STUserDefinedPrx (NsQualIdent "MyType" [])) (Ident "MyIdentifier") Nothing) HU.@=? testParse parseSemTermField "MyType* MyIdentifier;"
  , " const 1"         HU.~: Right (ConstDecl STBool (Ident "MyBool") (SliceBool True)) HU.@=? testParse parseConst "const bool MyBool = true;"
  , " include quotes"  HU.~: Right [IncludeDecl Quotes "some/relative/path.ice"] HU.@=? testParse parseSlices "#include \"some/relative/path.ice\""
  , " include backets" HU.~: Right [IncludeDecl AngleBrackets "some/relative/path.ice"] HU.@=? testParse parseSlices "#include <some/relative/path.ice>"
  , " enum 1"          HU.~: Right [EnumDecl (Ident "plain") []] HU.@=? testParse parseSlices "enum plain {};"
  , " enum 2"          HU.~: Right [EnumDecl (Ident "plain") [Ident "MyVal"]] HU.@=? testParse parseSlices "enum plain { MyVal };"
  , " enum 3"          HU.~: Right [EnumDecl (Ident "MyEnumWith_Underscores") [Ident "Val_1", Ident "Val_2"]] HU.@=? testParse parseSlices "enum MyEnumWith_Underscores \n{\n\tVal_1,\n\tVal_2\n};"
  , " enum 4"          HU.~: Right [EnumDecl (Ident "MyEnumWith_Underscores") [Ident "Val_1", Ident "Val_2"]] HU.@=? testParse parseSlices "enum MyEnumWith_Underscores \n{\n\tVal_1,\n\tVal_2\n};;"
  , " struct 1"        HU.~: Right [StructDecl (Ident "plain") []] HU.@=? testParse parseSlices "struct plain {};"
  , " struct 2"        HU.~: Right [StructDecl (Ident "plain") [FieldDecl STBool (Ident "myBool") Nothing]] HU.@=? testParse parseSlices "struct plain { bool myBool; };"
  , " struct 3"        HU.~: Right [StructDecl (Ident "plain") [FieldDecl STBool (Ident "myBool") (Just (SliceBool True))]] HU.@=? testParse parseSlices "struct plain { bool myBool = true; };"
  , " struct 4"        HU.~: Right [StructDecl (Ident "plain") [FieldDecl (STUserDefined (NsQualIdent "MyType" [])) (Ident "status") (Just (SliceIdentifier (NsQualIdent "MyIdentifier" [])))]] HU.@=? testParse parseSlices "struct plain { MyType status = MyIdentifier; };"
  , " struct 5"        HU.~: Right [StructDecl (Ident "plain") [FieldDecl (STUserDefinedPrx (NsQualIdent "MyType" [])) (Ident "status") Nothing]] HU.@=? testParse parseSlices "struct plain { MyType* status; };"
  , " plain module"    HU.~: Right [ModuleDecl (Ident "plain") []] HU.@=? testParse parseSlices "module plain {};"
  , " nested module"   HU.~: Right [ModuleDecl (Ident "nested") [ModuleDecl (Ident "nested2") []]] HU.@=? testParse parseSlices "module nested { module nested2 {}; };"
  , " method 1"        HU.~: Right (MethodDecl STVoid (Ident "myMethod") [] [] Nothing) HU.@=? testParse parseMethod "void myMethod();"
  , " method 2"        HU.~: Right (MethodDecl STVoid (Ident "myMethod") [] [NsQualIdent "MyException"[]] Nothing) HU.@=? testParse parseMethod "void myMethod() throws MyException;"
  , " method 3"        HU.~: Right (MethodDecl STVoid (Ident "myMethod") [FieldDecl STBool (Ident "myBool") Nothing] [] Nothing) HU.@=? testParse parseMethod "void myMethod(bool myBool);"
  , " method 4"        HU.~: Right (MethodDecl STString (Ident "myMethod") [FieldDecl STBool (Ident "myBool") Nothing, FieldDecl STDouble (Ident "My_Double") Nothing] [NsQualIdent "MyException1" [] , NsQualIdent "my_exception_1" []] Nothing) HU.@=? testParse parseMethod "string myMethod(bool myBool , double My_Double) throws MyException1, my_exception_1;"
  , " method 5"        HU.~: Right (MethodDecl STVoid (Ident "myMethod") [] [] (Just Idempotent)) HU.@=? testParse parseMethod "idempotent void myMethod();"
  -- , " method list 1"   HU.~: Right [] HU.@=? testParse (parseList parseMethod) ""
  -- , " method list 2"   HU.~: Right [MethodDecl STString "myMethod" [] [] Nothing, MethodDecl STString "myMethod" [] [] Nothing] HU.@=? testParse (parseList parseMethod) "string myMethod(); string myMethod();"
  , " interface 1"     HU.~: Right [InterfaceDecl (Ident "MyInterface") [] []] HU.@=? testParse parseSlices "interface MyInterface {};"
  , " interface 2"     HU.~: Right [InterfaceDecl (Ident "MyInterface") [NsQualIdent "Interface1" []] []] HU.@=? testParse parseSlices "interface MyInterface extends Interface1 {};"
  , " interface 3"     HU.~: Right [InterfaceDecl (Ident "MyInterface") [NsQualIdent "Interface1" []] [MethodDecl STVoid (Ident "method1") [] [] Nothing]] HU.@=? testParse parseSlices "interface MyInterface extends Interface1 { void method1(); };"
  , " interface 4"     
    HU.~:  Right [InterfaceDecl (Ident "MyInterface") [NsQualIdent "Interface1" [] , NsQualIdent "Interface_2" []] [MethodDecl STVoid (Ident "method1") [] [] Nothing, MethodDecl STBool (Ident "method2") [FieldDecl (STUserDefined (NsQualIdent "MyType" [])) (Ident "myParam") Nothing] [] Nothing]] 
    HU.@=? testParse parseSlices "interface MyInterface extends Interface1, Interface_2\n{\n\tvoid method1();\tbool method2(MyType myParam);\n};"
  , " interface 5"
    HU.~:  Right [InterfaceDecl (Ident "MyInterface") [NsQualIdent "Interface1" [], NsQualIdent "Interface_2" []] [MethodDecl STVoid (Ident "method1") [] [] Nothing, MethodDecl STBool (Ident "method2") [FieldDecl (STUserDefined (NsQualIdent "MyType" [])) (Ident "myParam") Nothing] [NsQualIdent "MyException" [], NsQualIdent "MyOtherException" []] Nothing]] 
    HU.@=? testParse parseSlices "interface MyInterface extends Interface1, Interface_2\n{\n\tvoid method1();\n\tbool method2(MyType myParam) throws MyException, MyOtherException;\n};"
  , " interface 6"
    HU.~:  Right [InterfaceDecl (Ident "MyInterface") [NsQualIdent "Interface1" [], NsQualIdent "Interface_2" []] [MethodDecl STVoid (Ident "method1") [] [] Nothing, MethodDecl STBool (Ident "method2") [FieldDecl (STUserDefined (NsQualIdent "MyType" [])) (Ident "myParam") Nothing] [NsQualIdent "MyException" [], NsQualIdent "MyOtherException" []] Nothing]]
    HU.@=? testParse parseSlices "interface MyInterface extends Interface1, Interface_2\n{\n\tvoid method1();;\n\tbool method2(MyType myParam) throws MyException, MyOtherException;\n};"
  , " module list"     HU.~: Right [ModuleDecl (Ident "plain") [], ModuleDecl (Ident "plain") []] HU.@=? testParse parseSlices "module plain {};\nmodule plain {};"
  , " ifndef 1"        HU.~: Right [ModuleDecl (Ident "plain") []] HU.@=? testParse parseSlices "#ifndef GUARD_1\n#define GUARD_1\n\nmodule plain {};\n#endif"
  ]

fileTestData :: [(String,String)]
fileTestData = [("test/testSlice01.ice","test/testSlice01.ast")
               ,("test/testSlice02.ice","test/testSlice02.ast")
               ]

tests :: [Test]
tests = [testGroup "Basic declaration parsing" $ hUnitTestToTests testCases]

main :: IO ()
main = do
  astData <- mapM (readFile . snd) fileTestData
  parseResults <- mapM (parseFile . fst) fileTestData
  let fileTests = [testGroup "File tests" $ hUnitTestToTests $ HU.TestList $ 
                   zipWith3 (\(nm,_) ast result -> nm HU.~: Right (read ast :: [SliceDecl]) HU.@=? result) fileTestData  astData parseResults]
      allTests  = tests ++ fileTests
  defaultMain allTests