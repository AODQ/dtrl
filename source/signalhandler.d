module signalhandler;

import core.stdc.signal;
import dtl;

private static bool shouldProgramTerminate = false;

bool ShouldProgramTerminate() { return shouldProgramTerminate; }
void ForceProgramTerminate() { shouldProgramTerminate = true; }

extern(C) private void SignalInterruptHandler(int sigNum) nothrow@nogc@system {
  import core.stdc.stdio;

  // -- on a first request, allow the program to terminate by itself. On a
  //    second request, force an exit
  if (shouldProgramTerminate) {
    import core.stdc.stdlib;
    exit(-1);
  }
  shouldProgramTerminate = true;
}

void SetupSignalHandling() {
  signal(SIGINT, &SignalInterruptHandler);
  signal(SIGTERM, &SignalInterruptHandler);
  signal(SIGTERM, &SignalInterruptHandler);
}
