/*
    Defines profile/logging in PETSc.
*/

import petsc.c.error;
import petsc.c.viewer;
public import petsc.c.types;
import mpi.mpi;

alias int    PetscLogEvent;
alias int    PetscLogStage;
alias double PetscLogDouble;

immutable PETSC_EVENT = 1311311;

///////////////////////////////////////////////////////////////
// Global variables
//

extern(C) {
  extern __gshared PetscLogEvent PETSC_LARGEST_EVENT;
  
  // Global flop counter
  extern __gshared PetscLogDouble  _TotalFlops;
  extern __gshared PetscLogDouble petsc_tmp_flops;
}

///////////////////////////////////////////////////////////////
// External functions
//

extern(C) {
  // Initialization functions
  PetscErrorCode  PetscLogBegin();
  PetscErrorCode  PetscLogAllBegin();
  //PetscErrorCode  PetscLogTraceBegin(FILE *);
  PetscErrorCode  PetscLogActions(PetscBool);
  PetscErrorCode  PetscLogObjects(PetscBool);
  //General functions
  PetscErrorCode  PetscLogGetRGBColor(const char**);
  PetscErrorCode  PetscLogDestroy();
  /*
  PetscErrorCode  PetscLogSet(PetscErrorCode (*)(int, int, PetscObject, PetscObject, PetscObject, PetscObject),
                              PetscErrorCode (*)(int, int, PetscObject, PetscObject, PetscObject, PetscObject));
  */
  //PetscErrorCode  PetscLogObjectState(PetscObject, const char[], ...);
  // Output functions
  PetscErrorCode  PetscLogView(PetscViewer);
  PetscErrorCode  PetscLogViewPython(PetscViewer);
  PetscErrorCode  PetscLogPrintDetailed(MPI_Comm, const char*);
  PetscErrorCode  PetscLogDump(const char*);

  PetscErrorCode  PetscGetFlops(PetscLogDouble *);

  PetscErrorCode  PetscLogStageRegister(const char*,PetscLogStage*);
  PetscErrorCode  PetscLogStagePush(PetscLogStage);
  PetscErrorCode  PetscLogStagePop();
  PetscErrorCode  PetscLogStageSetActive(PetscLogStage, PetscBool );
  PetscErrorCode  PetscLogStageGetActive(PetscLogStage, PetscBool  *);
  PetscErrorCode  PetscLogStageSetVisible(PetscLogStage, PetscBool );
  PetscErrorCode  PetscLogStageGetVisible(PetscLogStage, PetscBool  *);
  PetscErrorCode  PetscLogStageGetId(const char*, PetscLogStage *);
  // Event functions
  PetscErrorCode  PetscLogEventRegister(const char*, PetscClassId,PetscLogEvent*);
  PetscErrorCode  PetscLogEventActivate(PetscLogEvent);
  PetscErrorCode  PetscLogEventDeactivate(PetscLogEvent);
  PetscErrorCode  PetscLogEventSetActiveAll(PetscLogEvent, PetscBool );
  PetscErrorCode  PetscLogEventActivateClass(PetscClassId);
  PetscErrorCode  PetscLogEventDeactivateClass(PetscClassId);
}

///////////////////////////////////////////////////////////////
// Data structures 
//

struct PetscEventPerfInfo {
  int            id;            /* The integer identifying this event */
  PetscBool      active;        /* The flag to activate logging */
  PetscBool      visible;       /* The flag to print info in summary */
  int            depth;         /* The nesting depth of the event call */
  int            count;         /* The number of times this event was executed */
  PetscLogDouble flops;         /* The flops used in this event */
  PetscLogDouble time;          /* The time taken for this event */
  PetscLogDouble numMessages;   /* The number of messages in this event */
  PetscLogDouble messageLength; /* The total message lengths in this event */
  PetscLogDouble numReductions; /* The number of reductions in this event */
}

struct _n_PetscEventPerfLog {
  int                numEvents;  /* The number of logging events */
  int                maxEvents;  /* The maximum number of events */
  PetscEventPerfInfo *eventInfo; /* The performance information for each event */
}

alias _n_PetscEventPerfLog *PetscEventPerfLog;

alias void* PetscClassPerfLog;

struct PetscStageInfo {
  char               *name;     // The stage name
  PetscBool          used;      // The stage was pushed on this processor
  PetscEventPerfInfo perfInfo;  // The stage performance information
  PetscEventPerfLog  eventLog;  // The event information for this stage
  PetscClassPerfLog  classLog;  // The class information for this stage
}

alias void* PetscIntStack;

struct PetscEventRegInfo {
  char         *name;         /* The name of this event */
  PetscClassId classid;       /* The class the event is associated with */
  int          mpe_id_begin; /* MPE IDs that define the event */
  int          mpe_id_end;
}

struct _n_PetscEventRegLog {
  int               numEvents;  /* The number of registered events */
  int               maxEvents;  /* The maximum number of events */
  PetscEventRegInfo *eventInfo; /* The registration information for each event */
};

alias _n_PetscEventRegLog* PetscEventRegLog;
alias void* PetscClassRegLog;

struct _n_PetscStageLog {
  int              numStages;   /* The number of registered stages */
  int              maxStages;   /* The maximum number of stages */
  PetscIntStack    stack;       /* The stack for active stages */
  int              curStage;    /* The current stage (only used in macros so we don't call PetscIntStackTop) */
  PetscStageInfo*  stageInfo;   /* The information for each stage */
  PetscEventRegLog eventLog;    /* The registered events */
  PetscClassRegLog classLog;    /* The registered classes */
};

alias _n_PetscStageLog* PetscStageLog;

extern(C) {
  extern __gshared PetscStageLog _stageLog;
  
  extern __gshared PetscErrorCode function(PetscLogEvent,int,PetscObject,PetscObject,PetscObject,PetscObject) _PetscLogPLB;
  extern __gshared PetscErrorCode function(PetscLogEvent,int,PetscObject,PetscObject,PetscObject,PetscObject) _PetscLogPLE;
  extern __gshared PetscErrorCode function(PetscObject) _PetscLogPHC;
  extern __gshared PetscErrorCode function(PetscObject) _PetscLogPHD;
}

// Functions to replace PETSc macros

PetscErrorCode PetscLogEventBegin(PetscLogEvent e, PetscObject o1=null, PetscObject o2=null,
                                  PetscObject o3=null, PetscObject o4=null) {
  PetscErrorCode ierr = 0;
  if(_PetscLogPLB && 
     _stageLog.stageInfo[_stageLog.curStage].perfInfo.active && 
     _stageLog.stageInfo[_stageLog.curStage].eventLog.eventInfo[e].active) {
    ierr = _PetscLogPLB(e,0,o1,o2,o3,o4);
  }
  return ierr;
}

immutable PETSC_FLOPS_PER_OP = 1.0;

PetscErrorCode PetscLogFlops(PetscLogDouble f) {
  _TotalFlops += PETSC_FLOPS_PER_OP*f;
  return 0;
}

PetscErrorCode PetscLogEventEnd(PetscLogEvent e, PetscObject o1=null, PetscObject o2=null,
                                PetscObject o3=null, PetscObject o4=null) {
  if(_PetscLogPLE && 
     _stageLog.stageInfo[_stageLog.curStage].perfInfo.active &&
     _stageLog.stageInfo[_stageLog.curStage].eventLog.eventInfo[e].active) {
    _PetscLogPLE(e,0,o1,o2,o3,o4);
  }
  return 0;
}

/*
PetscErrorCode  PetscStageLogGetEventPerfLog(PetscStageLog stageLog, int stage, PetscEventPerfLog *eventLog)
{
  PetscFunctionBegin;
  PetscValidPointer(eventLog,3);
  if ((stage < 0) || (stage >= stageLog->numStages)) {
    SETERRQ2(PETSC_COMM_SELF,PETSC_ERR_ARG_OUTOFRANGE, "Invalid stage %d should be in [0,%d)", stage, stageLog->numStages);
  }
  *eventLog = stageLog->stageInfo[stage].eventLog;
  PetscFunctionReturn(0);
}
*/

 /*
#define PetscPreLoadBegin(flag,name) \
do {\
  PetscBool      PetscPreLoading = flag;\
  int            PetscPreLoadMax,PetscPreLoadIt;\
  PetscLogStage  _stageNum;\
  PetscErrorCode _3_ierr;	\
  _3_ierr = PetscOptionsGetBool(PETSC_NULL,"-preload",&PetscPreLoading,PETSC_NULL);CHKERRQ(_3_ierr);\
  PetscPreLoadMax = (int)(PetscPreLoading);\
  PetscPreLoadingUsed = PetscPreLoading ? PETSC_TRUE : PetscPreLoadingUsed;\
  for (PetscPreLoadIt=0; PetscPreLoadIt<=PetscPreLoadMax; PetscPreLoadIt++) {\
    PetscPreLoadingOn = PetscPreLoading;\
    _3_ierr = PetscBarrier(PETSC_NULL);CHKERRQ(_3_ierr);\
    if (PetscPreLoadIt>0) {\
      _3_ierr = PetscLogStageGetId(name,&_stageNum);CHKERRQ(_3_ierr);\
    } else {\
      _3_ierr = PetscLogStageRegister(name,&_stageNum);CHKERRQ(_3_ierr); \
    }\
    _3_ierr = PetscLogStageSetActive(_stageNum,(PetscBool)(!PetscPreLoadMax || PetscPreLoadIt));\
    _3_ierr = PetscLogStagePush(_stageNum);CHKERRQ(_3_ierr);

#define PetscPreLoadEnd() \
    _3_ierr = PetscLogStagePop();CHKERRQ(_3_ierr);\
    PetscPreLoading = PETSC_FALSE;\
  }\
} while (0)

 */
