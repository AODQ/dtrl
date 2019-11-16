module unittest_;

// import core.stdc.stdio;
// import core.stdc.stdlib, core.stdc.string;
// import dtoavkbindings.cimgui;
// import dtrl.commands;

// import dtrl.jobsystem;
// static import neobc;

// private string Test(
//   string leftCondition
// , string rightCondition
// , string FP = __FILE_FULL_PATH__
// , int    LC = __LINE__
// )() {
//   string mem =
//     `{`
//   ~ ` testResults.length(testResults.length + 1);`
//   ~ ` UnitTestResult* result = &testResults[$-1];`
//   ~ ` result.passed = `  ~ leftCondition ~ " == " ~ rightCondition ~ `;`
//   ~ ` result.loc    = 0;`
//   ~ ` result.leftAsString = neobc.ToString(` ~ leftCondition ~ `) ;`
//   ~ ` result.rightAsString = neobc.ToString(` ~ rightCondition ~ `) ;`
//   ~ ` result.leftAsLabel  = "` ~ leftCondition ~ `";`
//   ~ ` result.rightAsLabel = "` ~ rightCondition ~ `";`
//   ~ `}`
//   ;

//   return mem;
// }

// struct UnitTestResult {
//   string leftAsLabel;
//   string rightAsLabel;
//   neobc.String leftAsString;
//   neobc.String rightAsString;
//   int loc;
//   bool passed;
// }

// void WriteUnitTestToConsole() {
//   import core.stdc.stdio;

//   neobc.Array!UnitTestResult unitTestResults = UnitTest();
//   foreach (ref res; unitTestResults.AsRange) {
//     printf(
//       "%s (%s) %s %s (%s)\n"
//     , res.leftAsLabel.ptr, res.leftAsString.ptr
//     , res.passed ? "==".ptr : "!=".ptr
//     , res.rightAsLabel.ptr, res.rightAsString.ptr
//     );
//   }
// }

// void DisplayUnitTestResults() {
//   static neobc.Array!UnitTestResult unitTestResults;
//   static bool firstInit = false;
//   if (!firstInit) {
//     unitTestResults = UnitTest();
//     firstInit = true;
//   }

//   static bool shouldOpen = true;
//   static bool showOnlyFailedTests = true;

//   igBegin("unit test results", &shouldOpen, 0);
//   if (igButton("Test", ImVec2(0, 0)))
//      unitTestResults = UnitTest();
//   igCheckbox("Show only failed tests", &showOnlyFailedTests);
//   foreach (ref res; unitTestResults.AsRange) {
//     if (res.passed && showOnlyFailedTests) continue;

//     ImVec4 color
//       = res.passed
//       ? ImVec4(0.5f, 1.0f, 0.5f, 1.0f)
//       : ImVec4(1.0f, 0.5f, 0.5f, 1.0f);

//     igTextColored(
//       color
//     , "%s (%s) %s %s (%s)\n"
//     , res.leftAsLabel.ptr, res.leftAsString.ptr
//     , res.passed ? "==".ptr : "!=".ptr
//     , res.rightAsLabel.ptr, res.rightAsString.ptr
//     );
//   }
//   igEnd;
// }

// neobc.Array!UnitTestResult UnitTest() {
//   neobc.Array!UnitTestResult testResults;

//   { // -- linear allocator
//     neobc.LinearAllocator linearAllocator
//       = neobc.LinearAllocator.Create(float.sizeof * 4);
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{float.sizeof * 4}));

//     neobc.ArrayRange!float myData = linearAllocator.Allocate!float(3);
//     mixin(Test!(q{myData[0]}, q{0.0f}));
//     mixin(Test!(q{myData[1]}, q{0.0f}));
//     mixin(Test!(q{myData[2]}, q{0.0f}));
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{float.sizeof * 1}));

//     myData[0] = 1.0f;
//     myData[1] = 2.0f;
//     myData[2] = 3.0f;
//     mixin(Test!(q{myData[0]}, q{1.0f}));
//     mixin(Test!(q{myData[1]}, q{2.0f}));
//     mixin(Test!(q{myData[2]}, q{3.0f}));
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{float.sizeof * 1}));

//     neobc.ArrayRange!float moreData = linearAllocator.Allocate!float;
//     moreData[0] = 6.0f;
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{0}));
//     mixin(Test!(q{myData[0]}, q{1.0f}));
//     mixin(Test!(q{myData[1]}, q{2.0f}));
//     mixin(Test!(q{myData[2]}, q{3.0f}));
//     mixin(Test!(q{moreData[0]}, q{6.0f}));

//     moreData[0] = 4.0f;
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{0}));
//     mixin(Test!(q{myData[0]}, q{1.0f}));
//     mixin(Test!(q{myData[1]}, q{2.0f}));
//     mixin(Test!(q{myData[2]}, q{3.0f}));
//     mixin(Test!(q{moreData[0]}, q{4.0f}));

//     linearAllocator.Clear;
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{float.sizeof * 4}));

//     neobc.ArrayRange!float moremoreData = linearAllocator.Allocate!float(4);
//     mixin(Test!(q{linearAllocator.BytesLeft}, q{float.sizeof * 0}));
//     mixin(Test!(q{myData[0]}, q{1.0f}));
//     mixin(Test!(q{myData[1]}, q{2.0f}));
//     mixin(Test!(q{myData[2]}, q{3.0f}));
//   }

//   { // -- command buffer
//     import bindbc.opengl;

//     CommandBufferAllocator alloc = CommandBufferAllocator.Create;
//     DrawArrayInfo* arrayInfo = alloc.Allocate!DrawArrayInfo;
//     arrayInfo.mode = GL_TRIANGLES;
//     arrayInfo.first = 10;
//     arrayInfo.count = 32;
//     mixin(Test!(
//       q{alloc.commandBuffer.BytesLeft}
//     , q{CommandBufferAllocator.ByteSize
//       - DrawArrayInfo.sizeof - GlCommand.sizeof}
//     ));

//     Uniform1iInfo* unifInfo = alloc.Allocate!Uniform1iInfo;
//     unifInfo.layoutLocation = 5;
//     unifInfo.value = 32;

//     mixin(Test!(
//       q{alloc.commandBuffer.BytesLeft}
//     , q{CommandBufferAllocator.ByteSize
//       - DrawArrayInfo.sizeof - GlCommand.sizeof*2 - Uniform1iInfo.sizeof}
//     ));

//     DrawElementInfo* elemInfo = alloc.Allocate!DrawElementInfo;

//     mixin(Test!(q{arrayInfo.mode},  q{GL_TRIANGLES}));
//     mixin(Test!(q{arrayInfo.first}, q{10}));

//     CommandBufferAllocatorAsRange asRange = alloc.AsRange;
//     CommandInfo arrayCmdInfo = asRange.front;
//     mixin(Test!(q{asRange.AllocatorIter}, q{0}));
//     mixin(Test!(q{arrayCmdInfo.glCommand}, q{GlCommand.DrawArrays}));
//     auto arrayInfoPtr = cast(DrawArrayInfo*)arrayCmdInfo.data;
//     mixin(Test!(q{cast(void*)arrayInfoPtr}, q{cast(void*)arrayInfo}));
//     bool IsEqual = cast(void*)arrayInfoPtr == cast(void*)arrayInfo;

//     asRange.popFront;
//     mixin(Test!(
//       q{asRange.AllocatorIter},
//       q{GlCommand.sizeof + DrawArrayInfo.sizeof}
//     ));

//     CommandInfo unifCmdInfo = asRange.front;
//     mixin(Test!(q{unifCmdInfo.glCommand}, q{GlCommand.Uniform1i}));
//     auto unifInfoPtr = cast(Uniform1iInfo*)unifCmdInfo.data;
//     mixin(Test!(q{cast(void*)unifInfoPtr}, q{cast(void*)unifInfo}));

//     mixin(Test!(q{arrayInfoPtr.mode},  q{GL_TRIANGLES}));
//     mixin(Test!(q{arrayInfoPtr.first}, q{10}));
//     mixin(Test!(q{unifInfoPtr.layoutLocation},  q{5}));
//     mixin(Test!(q{unifInfoPtr.value}, q{32}));

//     asRange.popFront;
//     mixin(Test!(
//       q{asRange.AllocatorIter},
//       q{GlCommand.sizeof*2 + DrawArrayInfo.sizeof + Uniform1iInfo.sizeof}
//     ));

//     CommandInfo elemCmdInfo = asRange.front;
//     mixin(Test!(q{elemCmdInfo.glCommand}, q{GlCommand.DrawElements}));
//     mixin(Test!(q{cast(void*)elemCmdInfo.data}, q{cast(void*)elemInfo}));

//     asRange.popFront;
//     mixin(Test!(q{asRange.empty}, q{true}));

//     alloc.Clear;
//     DrawArrayInfo* arrayInfo2 = alloc.Allocate!DrawArrayInfo;
//     mixin(Test!(q{arrayInfo2}, q{arrayInfo}));
//   }

//   return testResults;
// }

