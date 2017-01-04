*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Initialize_SpareTable
* Written by : Tom Stepleton
* Date       : XX January 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues Initialize_SpareTable command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Initialize_SpareTable code ======================

    ; CMD_Initialize_SpareTable -- Attempt Initialize_SpareTable command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   Re-runs WIDGETINFO, so has all of WIDGETINFO's side-effects.
CMD_Initialize_SpareTable:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- INITIALISE SPARE TABLE ---'>

    ; Set form bounds based on drive information
    CLR.L   D0                       ; Assemble format offset bound in D0
    MOVE.B  zSectors,D0              ; This parameter can't exceed the number...
    SUBQ.B  #1,D0                    ; ...of sectors minus 1
    MOVE.L  D0,z_CIntStbBounds       ; Copy to bounds array
    MOVE.B  #$6,D0                   ; Meanwhile, interleave set can't exceed 6
    MOVE.L  D0,(4+z_CIntStbBounds)   ; Copy to bounds array
   
    ; Set form initial values based on drive information
    MOVE.B  zFmtOffset,D0            ; Format offset bounces off D0...
    MOVE.L  D0,z_CIntStbInitialVals  ; ...and into the initial values array
    MOVE.B  zFmtIntrl,D0             ; Format interleave set bounces off D0...
    MOVE.L  D0,(4+z_CIntStbInitialVals)  ; ...and into the initial values array

    ; Query user for initialisation parameters
    LEA     s_CIntStbForm,A0         ; Prepare FORM args: address of template...
    LEA     s_CIntStbPrompts,A1      ; ...address of prompt pointer array...
    LEA     z_CIntStbInitialVals,A2  ; ...address of initial values array...
    LEA     z_CIntStbBounds,A3       ; ...address of value bounds array
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel

    ; Copy parameters into the command and get confirmation
.bc MOVE.B  (3+zFieldValues),(2+zInitSptbCmd)  ; Copy format offset into command
    MOVE.B  (7+zFieldValues),(3+zInitSptbCmd)  ; Copy interleave set into cmd.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'RAW COMMAND'>
    LEA     zInitSptbCmd,A0          ; Get ready to dump the command
    mDump.B kCrtRow,kCrtCol,#kFirstCol,A0,#8,endl  ; Dump it
    LEA     s_CIntStbConfForm,A0     ; Prepare FORM args: address of template...
    LEA     s_CIntStbConfPrompts,A1  ; ...address of prompt pointer array...
    SUBA.L  A2,A2                    ; ...no custom initial values...
    SUBA.L  A3,A3                    ; ...no custom value bounds
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel by typing 'Q'?
    BEQ.S   .qt                      ; Yes, go ahead to ack user and cancel
    TST.B   (3+zFieldValues)         ; Did the user cancel by submitting 'N'?
    BEQ.S   .qt                      ; Yes, go ahead to ack user and cancel

    ; Confirmed; let's initialise that spare table
.go CLR.B   zHaveInfo                ; Mark our current Widget info stale
    MOVE.B  #8,D0                    ; The command is eight bytes long
    LEA     zInitSptbCmd,A0          ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Exit
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    ; Execution branch for when the user chooses to cancel.
.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    PAGE
* NeoWidEx Initialize_SpareTable scratch data allocation ===
    SECTION kSecScratch

zInitSptbCmd:
    DC.B    $10,$10,$00,$00          ; Command; bytes 3, 4 (of 8) are alterable
    DC.B    $F0,$78,$3C,$1E          ; These are the "password" command bytes
    DS.W    0                        ; Force even alignment for following data

z_CIntStbInitialVals:
    DC.B    'Istb'                   ; Initial field values for the form
    DC.B    'Init'
z_CIntStbBounds:
    DC.B    'Istb'                   ; Bounds for command parameters
    DC.B    'Bnds'


    PAGE
* NeoWidEx Send_Park strings ================================
    SECTION kSecStrings

s_CIntStbForm:                       ; User form for command parameters
    DC.B    $0D,'FORMAT OFFSET-aa INTERLEAVE-ba',0

    DS.W    0
s_CIntStbPrompts:                    ; Form prompts for command parameters
    DC.L    .p1,.p2
.p1 DC.B    'FORMAT OFFSET',0
.p2 DC.B    'FORMAT INTERLEAVE',0

s_CIntStbConfForm:                   ; User form for confirming command
    DC.B    $0D,'REALLY INITIALISE SPARE TABLE? a',0

    DS.W    0
s_CIntStbConfPrompts:
    DC.L    .p1
.p1 DC.B    'PROCEED',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
