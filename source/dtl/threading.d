module dtl.threading;

// import core.stdc.stdint;
// import core.stdc.stdio;
// import core.stdc.stdlib;
// import core.sys.posix.pthread;
// import core.thread;
// import dtl.commands;
// import dtl.jobsystem;
// import neobc.assertion;
// static import neobc;

// struct JobReturnInfo {
//   neobc.Array!CommandInfo commands;
// };

// struct Job {
//   void function(
//     ThreadID threadId
//   , ref CommandBufferAllocator allocator
//   , void* userData
//   ) fn;
//   void* userData;
// };

// struct Thread {
//   import core.sys.posix.pthread;

//   pthread_t threadId;
// };

// alias ThreadFuncPtr = extern(C) void* function(void*);

// Thread CreateThread(ThreadFuncPtr initFn, void* initFnParam) {

//   Thread thread;

//   EnforceAssert(
//     pthread_create(&thread.threadId, null, initFn, initFnParam) == 0
//   , "Could not create thread"
//   );

//   return thread;
// }

// struct Mutex {
//   import core.sys.posix.pthread;

//   pthread_mutex_t mutexLock = PTHREAD_MUTEX_INITIALIZER;
// };

// struct MutexRaiiLock {
//   Mutex* mutex;

//   this(Mutex* mutex_) {
//     import core.sys.posix.pthread;
//     mutex = mutex_;
//     if (pthread_mutex_lock(&mutex.mutexLock) != 0) {
//       printf("COULD NOT LOCK MUTEX!\n");
//     }
//   }

//   ~this() {
//     import core.sys.posix.pthread;
//     if (pthread_mutex_unlock(&mutex.mutexLock) != 0) {
//       printf("COULD NOT UNLOCK MUTEX!\n");
//     }
//   }
// };

// MutexRaiiLock LockMutex(ref Mutex mutex) {
//   return MutexRaiiLock(&mutex);
// }
