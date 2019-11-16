module dtl.jobsystem;

// import core.stdc.stdint;
// import core.stdc.stdio;
// import core.stdc.stdlib;
// import dtl.commands;
// import dtl.threading;
// import neobc.assertion;
// static import neobc;

// /*
//   [ GlCommand [enum], DATA ..., GlCommand [enum], DATA .... ]
// */

// struct CommandBufferAllocator {
//   neobc.LinearAllocator commandBuffer;

//   Mutex allocationMutex;

//   static immutable ByteSize = 1024 * 128;

//   static CommandBufferAllocator Create() {
//     CommandBufferAllocator allocator;
//     allocator.commandBuffer = neobc.LinearAllocator.Create(ByteSize);
//     return allocator;
//   }

//   T* Allocate(T)() {
//     auto lock = LockMutex(allocationMutex);
//     GlCommand* glCmd = commandBuffer.Allocate!GlCommand.ptr;
//     *glCmd = T.glCommand;
//     return commandBuffer.Allocate!T.ptr;
//   }

//   void Clear() {
//     commandBuffer.Clear;
//   }

//   CommandBufferAllocatorAsRange AsRange() {
//     return CommandBufferAllocatorAsRange.Create(this);
//   }
// }

// struct CommandBufferAllocatorAsRange {
//   private CommandBufferAllocator* allocator;
//   private size_t allocatorIter;

//   static CommandBufferAllocatorAsRange Create(ref CommandBufferAllocator cba) {
//     CommandBufferAllocatorAsRange self;
//     self.allocator = &cba;
//     self.allocatorIter = 0;
//     return self;
//   }

//   CommandInfo front() {
//     auto glCmd = cast(GlCommand*)(allocator.commandBuffer.ptr + allocatorIter);
//     void* data = allocator.commandBuffer.ptr + allocatorIter + GlCommand.sizeof;
//     return CommandInfo(*glCmd, data);
//   }

//   void popFront() {
//     auto glCmd = cast(GlCommand*)(allocator.commandBuffer.ptr + allocatorIter);
//     allocatorIter += GlCommand.sizeof;
//     allocatorIter += GlCommandByteSize[cast(size_t)(*glCmd)];
//   }

//   bool empty() {
//     return
//        allocator.commandBuffer.ptr + allocatorIter
//     == allocator.commandBuffer.end;
//   }

//   size_t AllocatorIter() { return allocatorIter; }
// }

// struct ThreadResultInfo {
//   CommandBufferAllocator commandBuffers;
//   neobc.Array!(uint64_t) threadNsTime;
//   neobc.Array!(bool) threadFinished;
//   bool done = false;

//   static ThreadResultInfo Create(size_t threadCount) {
//     ThreadResultInfo self;
//     self.commandBuffers = CommandBufferAllocator.Create;
//     self.threadNsTime.Resize(threadCount);
//     self.threadFinished.Resize(threadCount);

//     foreach (threadItr; 0 .. threadCount) {
//       self.threadNsTime[threadItr] = 0;
//       self.threadFinished[threadItr] = true;
//     }

//     return self;
//   }
// };

// struct JobSystem {
//   neobc.Array!Job jobs;
//   neobc.Array!Thread threads;
//   neobc.Array!ThreadResultInfo threadResultBuffers;
//   ThreadResultInfo* threadResultBufferFront;
//   ThreadResultInfo* threadResultBufferBack;
//   ThreadResultInfo* threadResultBufferWriting;
//   Mutex threadSwapMutex;

//   bool shouldCloseJobSystem = false;
//   bool pauseRendering = false;

//   ~this() {
//     Destroy(this);
//   }
// };

// void ExecuteSingleThreaded(ref JobSystem self) {
//   import core.thread : getpid;
//   self.threadResultBufferFront.commandBuffers.Clear;
//   foreach (ref job; self.jobs.AsRange) {
//     job.fn(getpid, self.threadResultBufferFront.commandBuffers, job.userData);
//   }

//   // -- sort goes here in future i assume

//   foreach (ref cmd; self.threadResultBufferFront.commandBuffers.AsRange) {
//     ExecuteCommandInfo(cmd);
//   }
// }

// void SwapBackBuffers(ref JobSystem self) {
//   MutexRaiiLock mutexLock = LockMutex(self.threadSwapMutex);
//   // -- swap out back and writing
//   neobc.Swap(self.threadResultBufferBack, self.threadResultBufferWriting);
// }

// void SwapFrontBuffers(ref JobSystem self) {
//   MutexRaiiLock mutexLock = LockMutex(self.threadSwapMutex);
//   // -- swap out back and front
//   neobc.Swap(self.threadResultBufferBack, self.threadResultBufferFront);
// }

// // rendering thread entry point to activate multi threaded rendering
// bool ExecuteMultiThreaded(ref JobSystem self) {
//   self.SwapBackBuffers;

//   // while (true) {
//   //   bool allThreadsFinished = true;
//   //   foreach (size_t threadIt; 0 .. self.threadStatus.length) {
//   //     allThreadsFinished = allThreadsFinished && self.threadStatus[threadIt];
//   //   }

//   //   if (allThreadsFinished) break;

//   //   { // -- sleep
//   //     import core.sys.posix.time;

//   //     timespec requested, remainder;
//   //     requested.tv_nsec = 1;
//   //     requested.tv_sec = 0;

//   //     nanosleep(&requested, &remainder);
//   //   }
//   // }

//   // -- if the back is ready to be swapped, swap & execute
//   if (self.threadResultBufferBack.done) {
//     // self.SwapFrontBuffers;
//     // foreach (ref results; self.threadResultBufferFront.jobReturnInfo.AsRange)
//     //   foreach (ref jobReturnInfo; results.AsRange)
//     //     foreach (ref cmd; jobReturnInfo.commands.AsRange)
//     //       ExecuteCommandInfo(cmd);
//     return true;
//   }
//   return false;
// }

// void Destroy(ref JobSystem jobSystem) {
//   import core.sys.posix.pthread;
//   jobSystem.shouldCloseJobSystem = true;

//   foreach (ref thread; jobSystem.threads.AsRange) {
//     pthread_join(thread.threadId, null);
//   }

//   jobSystem.jobs.Clear;
//   jobSystem.threads.Clear;
//   jobSystem.threadResultBuffers.Clear;
//   jobSystem.threadResultBufferFront   = null;
//   jobSystem.threadResultBufferBack    = null;
//   jobSystem.threadResultBufferWriting = null;
// }

// void CreateJobSystem(JobSystem* self, size_t threads) {
//   self.shouldCloseJobSystem = false;
//   self.pauseRendering = true;

//   // -- single threaded
//   if (threads == 0) {
//     self.threadResultBuffers.Resize(1);
//     self.threadResultBufferFront = self.threadResultBuffers.ptr;
//     *self.threadResultBufferFront = ThreadResultInfo.Create(1);
//     return;
//   }

//   // -- allocate thread result buffers
//   self.threadResultBuffers.Resize(3);
//   foreach (ref buffer; self.threadResultBuffers.AsRange) {
//     buffer = ThreadResultInfo.Create(threads);
//   }

//   self.threadResultBufferFront   = self.threadResultBuffers.ptr + 0;
//   self.threadResultBufferBack    = self.threadResultBuffers.ptr + 1;
//   self.threadResultBufferWriting = self.threadResultBuffers.ptr + 2;

//   foreach (threadItr; 0 .. threads) {
//     // -- generate threads
//     auto data = neobc.Allocate!MultiThreadedJobSystemInsertionData;
//     data.jobSystem = self;
//     data.threadIndex = threadItr;
//     self.threads ~= CreateThread(&MultiThreadedJobSystemInsertion, data);
//   }
// }

// size_t JobsPerThread(ref JobSystem jobSystem) {
//   return jobSystem.jobs.length / jobSystem.threads.length;
// }

// neobc.ArrayRange!Job GrabJobs(ref JobSystem jobSystem, size_t threadIndex) {
//   const size_t jobAmt = jobSystem.JobsPerThread;
//   const size_t jobStart = threadIndex * jobAmt;
//   size_t jobEnd   = jobStart + jobAmt - 1;

//   if (jobEnd >= jobSystem.jobs.length)
//     jobEnd = jobSystem.jobs.length-1;

//   neobc.ArrayRange!Job jobRange;
//   jobRange =
//     neobc.ArrayRange!Job.Create(
//       jobSystem.jobs.ptr + jobStart
//     , jobSystem.jobs.ptr + jobEnd
//     );
//   return jobRange;
// }

// struct MultiThreadedJobSystemInsertionData {
//   JobSystem* jobSystem;
//   size_t threadIndex;
// };

// extern(C) void* MultiThreadedJobSystemInsertion(void* dataAsVoidPtr) {
//   // import core.sys.posix.unistd : getpid;

//   // auto data = cast(MultiThreadedJobSystemInsertionData*)dataAsVoidPtr;
//   // auto jobSystem = data.jobSystem;
//   // auto threadPid = getpid;

//   // ThreadResultInfo* buffer = jobSystem.threadResultBufferWriting;

//   // while (!jobSystem.shouldCloseJobSystem) {
//   //   if (jobSystem.pauseRendering) {
//   //     neobc.Sleep();
//   //     continue;
//   //   }

//   //   // -- if we're the first thread, we're the one in charge of swapping back
//   //   //    buffers
//   //   if (data.threadIndex == 0) {
//   //     bool threadsFinished = true;
//   //     foreach (ref threadFinished; buffer.threadFinished.AsRange)
//   //       threadsFinished &= threadFinished;

//   //     // -- if finished, mark this buffer as done, swap the back buffers
//   //     //    then clear it out
//   //     if (threadsFinished) {
//   //       buffer.done = true;
//   //       (*data.jobSystem).SwapBackBuffers;
//   //       foreach (i; 0 .. buffer.jobReturnInfo.length) {
//   //         buffer.jobReturnInfo[i].Clear;
//   //         buffer.threadFinished[i] = false;
//   //       }
//   //       buffer.done = false;
//   //     }
//   //   }

//   //   // -- if we're not active yet, check if it's time to render this thread
//   //   if (buffer.done || buffer.threadFinished[data.threadIndex]) {
//   //     neobc.Sleep;

//   //     continue;
//   //   }

//   //   // -- get buffer ready to render
//   //   buffer = jobSystem.threadResultBufferWriting;
//   //   auto startNsTime = neobc.GetNsTime;

//   //   foreach (ref job; (*jobSystem).GrabJobs(data.threadIndex)) {
//   //     if (job.fn == null) {
//   //       printf("next job fn is null???\n");
//   //       continue;
//   //     }

//   //     buffer.jobReturnInfo[data.threadIndex] ~= job.fn(threadPid, job.userData);
//   //   }

//   //   // -- record time
//   //   buffer.threadNsTime[data.threadIndex] = neobc.GetNsTime - startNsTime;
//   //   buffer.threadFinished[data.threadIndex] = true;
//   // }

//   // free(data);
//   // return null;
//   return null;
// }
