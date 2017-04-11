*-----------------------------------------------------------
* Title      : NeoWidEx_UTIL_Format
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Formatter for Widgets.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Scan must be defined.
*      Resources from NeoWidEx_CMD_Read_Servo_Status must be defined.
*-----------------------------------------------------------


* NeoWidEx Formatter code ==================================

    ; UTIL_Format -- Format a Widget
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
UTIL_Format:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- FORMAT WIDGET ---'>
    CLR.W   zWIOReadLen              ; Except for two, no command reads any data
    CLR.W   zWIOWriteLen             ; No command writes data
    MOVE.L  #zSectorTag,zWIOReadPtr  ; Commands that do read data put it here

    ; Query recovery mode status from the controller internal status info.
    MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdIntStatus,A0   ; Command: get internal status 
    LEA     s_UFormatErr0,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; See whether recovery mode is active. If so, tell the user to disable it.
.rm BTST.B  #7,kStdStatus            ; Is recovery mode active?
    BEQ.S   .s0                      ; Yes, skip to restore standard status
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UFormatErr1
    BRA     .qs                      ; Attempt to restore std. status and bail

    ; Restore standard status (mostly so that's what's in kStdStatus if the user
    ; decides to quit).
.s0 MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdStdStatus,A0   ; Command: get standard status 
    LEA     s_UFormatErr2,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; See whether the controller believes it's passed all self-tests.
.ch BTST.B  #3,(1+kStdStatus)        ; Controller passed self-test?
    BEQ.S   .fm                      ; Yes, skip to ask user for format params
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UFormatErr3
    BRA     .qt                      ; Bail out

    ; Set form bounds based on drive information.
.fm CLR.L   D0                       ; Assemble format offset bound in D0
    MOVE.B  zSectors,D0              ; This parameter can't exceed the number...
    SUBQ.B  #1,D0                    ; ...of sectors minus 1
    MOVE.L  D0,z_UFormatBounds       ; Copy to bounds array
    MOVE.B  #$6,D0                   ; Meanwhile, interleave set can't exceed 6
    MOVE.L  D0,(4+z_UFormatBounds)   ; Copy to bounds array

    ; Set form initial values based on drive information
    MOVE.B  zFmtOffset,D0            ; Format offset bounces off D0...
    MOVE.L  D0,z_UFormatInitialVals  ; ...and into the initial values array
    MOVE.B  zFmtIntrl,D0             ; Format interleave value bounces off D0...
    MOVE.L  D0,(4+z_UFormatInitialVals)  ; ...and into the initial values array

    ; Query user for track formatting parameters
    LEA     s_UFormatForm,A0         ; Prepare FORM args: address of template...
    LEA     s_UFormatPrompts,A1      ; ...address of prompt pointer array...
    LEA     z_UFormatInitialVals,A2  ; ...address of initial values array...
    LEA     z_UFormatBounds,A3       ; ...address of value bounds array
    JSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel

    ; Copy parameters into format/spare table init commands
    MOVE.B  (3+zFieldValues),(2+z_UFormatCmdFmt)   ; Format offset to fmt. cmd.
    MOVE.B  (7+zFieldValues),(3+z_UFormatCmdFmt)   ; Interleave set to fmt. cmd.
    MOVE.B  (3+zFieldValues),(2+z_UFormatCmdInitSpTb)   ; Likewise for init...
    MOVE.B  (7+zFieldValues),(3+z_UFormatCmdInitSpTb)   ; ...spare table cmd.

    ; Print format/spare table init commands we'll use
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FORMAT COMMAND'>
    LEA     z_UFormatCmdFmt,A0
    mDump.B kCrtRow,kCrtCol,#kFirstCol,A0,#8,endl
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'INITIALISE SPARE TABLE COMMAND'>
    LEA     z_UFormatCmdInitSpTb,A0
    mDump.B kCrtRow,kCrtCol,#kFirstCol,A0,#8,endl

    ; Clear dry-run flag and confirm that user want to format.
    CLR.B   z_UFormatDryRun          ; Clear dry-run flag
    LEA     s_UFormatConfForm,A0     ; Prepare FORM args: address of template...
    LEA     s_UFormatConfPrompts,A1  ; ...address of prompt pointer array...
    SUBA.L  A2,A2                    ; ...no custom initial values...
    SUBA.L  A3,A3                    ; ...no custom value bounds
    JSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel by typing 'Q'?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel
    TST.B   (3+zFieldValues)         ; Did the user cancel by submitting 'N'?
    BNE     .go                      ; No, prepare to format!

    ; User does want to cancel; would they like a dry run instead?
    MOVE.B  #$FF,z_UFormatDryRun     ; Set dry-run flag
    LEA     s_UFormatDryRunForm,A0   ; Prepare FORM args: address of template...
    LEA     s_UFormatDryRunPrompts,A1  ; ...address of prompt pointer array...
    SUBA.L  A2,A2                    ; ...no custom initial values...
    SUBA.L  A3,A3                    ; ...no custom value bounds
    JSR     FORM                     ; Display form; get user input

    ; Back from form; did user want a dry run?
    TST.B   zFormIntent              ; Did the user cancel by typing 'Q'?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel
    TST.B   (3+zFieldValues)         ; Did the user say "no dry run, thanks"?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel

    ; OK, it's formatting time. We'll do essentially the same steps that Dr.
    ; Patrick Schäfer observed via logic analyser from Apple 3 format sessions.
.go mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'1. PREPARATION'>
    CLR.B   zHaveInfo                ; Force drive data reload after we're done

    ; Attempt to read the state registers.
    MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdStateRegs,A0   ; Command: get state registers
    LEA     s_UFormatErr4,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; See whether state registers look nominal.
    CMPI.L  #$0000DBE0,kStdStatus    ; Are state registers nominal?
    BEQ.S   .r0                      ; Yes, jump ahead to first recal
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UFormatErr5
    BRA     .qs                      ; Restore standard status and bail
 
    ; Issue first format recalibration command.
.r0 MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdFmtRecal,A0  ; Command: format recalibration
    LEA     s_UFormatErr6,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; Seek to track 0, head 0, sector 0.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'2. TRACK 0 HEAD 0 TRIAL FORMAT'>
    CLR.W   (2+z_UFormatCmdSeek)     ; Cylinder 0
    CLR.W   (4+z_UFormatCmdSeek)     ; Head 0, sector 0
    MOVE.B  #6,D0                    ; This command is six bytes long
    LEA     z_UFormatCmdSeek,A0      ; Command: seek
    LEA     s_UFormatErr7,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; Attempt to format this track.
    TST.B   z_UFormatDryRun          ; Are we only doing a dry run?
    BNE     .x0                      ; If so, skip this part
    MOVE.B  #8,D0                    ; This command is eight bytes long
    LEA     z_UFormatCmdFmt,A0       ; Command: format
    LEA     s_UFormatErr8,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; Attempt to read a sector on this track
.x0 MOVE.B  #2,D0                    ; This command is two bytes long
    LEA     s_UFormatCmdDiagRead,A0  ; Command: Diag_Read
    LEA     s_UFormatErr9,A1         ; Message to print on error
    MOVE.W  zBlockSize,zWIOReadLen   ; A Diag_Read reads a whole sector of data
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure
    CLR.W   zWIOReadLen              ; By default, commands don't read any data

    ; Issue second format recalibration command.
    MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdFmtRecal,A0  ; Command: format recalibration
    LEA     s_UFormatErr6,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; Initial setup for format. Get track after recal and start formatting
    ; on the next higher track. This seems to be correct for Widget-10 but may
    ; not be appropriate for Widget-40...
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'3. FORMATTING DRIVE'>
    MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdCurCyl,A0    ; Command: get current cylinder
    LEA     s_UFormatErrA,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qs                      ; Bail on failure, restoring std. status

    MOVE.W  kStdStatus,D1            ; Copy current cylinder to D1
    ADDQ.W  #1,D1                    ; Add one; the first cylinder we'll format

    ; Main formatting loop!
    ; First, put current cylinder and head values into the seek command.
.lo CLR.W   D2                       ; Prepare D2 to receive...
    MOVE.B  zHeads,D2                ; ...the current number of heads; we'll...
    SUBQ.B  #1,D2                    ; ...count down from the highest head

.li MOVE.B  D2,-(A7)                 ;   Current head to stack for printing
    MOVE.W  D1,-(A7)                 ;   Current cylinder to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  CYLINDER-'>,hx,<'  HEAD-'>,hhx

    ; Perform seek to track to be formatted.
    MOVE.W  D1,(2+z_UFormatCmdSeek)  ;   Copy current cylinder to seek command
    MOVE.B  D2,(4+z_UFormatCmdSeek)  ;   Copy current head to seek command
    MOVE.B  #6,D0                    ;   This command is six bytes long
    LEA     z_UFormatCmdSeek,A0      ;   Command: Diag_Seek
    LEA     s_UFormatErrB,A1         ;   Message to print on error
    BSR     _UFormatDoCmd            ;   Issue command
    BNE     .qt                      ;   Bail on failure

    ; Command heads to auto-adjust to the centre of the track. We do this three
    ; times with the idea that it gives the heads a chance to settle.
    MOVE.B  #2,D0                    ;   This command is two bytes long
    LEA     s_UFormatCmdAutoOffset,A0  ; Command: Set_AutoOffset
    LEA     s_UFormatErrC,A1         ;   Message to print on error
    BSR     _UFormatDoCmd            ;   Issue command
    BNE     .qt                      ;   Bail on failure
    BSR     _UFormatDoCmd            ;   Issue command
    BNE     .qt                      ;   Bail on failure
    BSR     _UFormatDoCmd            ;   Issue command
    BNE     .qt                      ;   Bail on failure

    ; Retrieve "main" servo status to get track centre's offset.
    MOVE.B  #3,D0                    ;   This command is three bytes long
    LEA     s_UFormatCmdSrvoStatus,A0  ; Command: get "main" servo status
    LEA     s_UFormatErrD,A1         ;   Message to print on error
    MOVE.W  #4,zWIOReadLen           ;   This command reads four bytes of data
    BSR     _UFormatDoCmd            ;   Issue command
    BNE     .qt                      ;   Bail on failure
    CLR.W   zWIOReadLen              ;   By default, commands don't read data

    ; Print offset and indicate whether it's larger than 16.
    MOVE.B  (1+zSectorTag),D0        ;   Offset DAC value to D0
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  FINE OFFSET IS '>
    BSR     PRINTSERVOOFFSETDAC      ;   Print offset DAC value
    MOVE.B  (1+zSectorTag),D0        ;   Offset DAC value to D0
    ANDI.B  #$1F,D0                  ;   Preserve magnitude only
    CMPI.B  #$10,D0                  ;   Is magnitude larger than 16?
    BLS.B   .zp                      ;   No, jump ahead to format the track
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'--THAT IS LARGE.'>

    ; Format the track regardless.
.zp TST.B   z_UFormatDryRun          ;   Are we only doing a dry run?
    BNE     .x1                      ;   If so, skip this part
    MOVE.B  #8,D0                    ;   This command is eight bytes long
    LEA     z_UFormatCmdFmt,A0       ;   Command: Format_Track
    LEA     s_UFormatErr8,A1         ;   Message to print on error
    BSR     _UFormatDoCmd            ;   Issue command
    BNE     .qt                      ;   Bail on failure

.x1 DBRA    D2,.li                   ;   Loop to the preceding head
    DBRA    D1,.lo                   ; Loop to the preceding cylinder

    ; Format complete! Finishing tasks now.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'4. DRIVE SOFT RESET'>
    MOVE.B  #2,D0                    ; This command is two bytes long
    LEA     s_UFormatCmdSoftReset,A0   ; Command: Soft_Reset
    JSR     WIDGETCMD                ; Construct actual command in RAM
    JSR     WIDGETIO                 ; Issue command (we expect+ignore failure)

    MOVE.B  #3,D0                    ; The next command is three bytes long
    LEA     s_UFormatCmdStateRegs,A0   ; Command: get controller state registers
    JSR     WIDGETCMD                ; Construct the actual command in RAM
    MOVE.W  #19,D1                   ; We'll try the command 20 times
.cs JSR     WIDGETIO                 ; Issue command
    BEQ     .ck                      ; All OK? Jump to check state registers
    DBEQ    D1,.cs                   ; Otherwise, try again

    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UFormatSoftResetFail
    JSR     WIDGETPERROR             ; Error! Print error message
    BRA     .qs                      ; Bail, try to restore standard status

.ck CMPI.L  #$0001DBE0,kStdStatus    ; Are state registers as expected?
    BEQ     .is                      ; Yes, jump to initialise the spare table
    MOVE.L  kStdStatus,-(A7)         ; No; state registers on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  HMM... CONTROLLER STATE '>,lx
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UFormatErrE

    ; Initialise the spare table
.is mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'5. INITIALISE SPARE TABLE'>
    TST.B   z_UFormatDryRun          ; Are we only doing a dry run?
    BNE     .x2                      ; If so, skip this part
    MOVE.B  #8,D0                    ; This command is eight bytes long
    LEA     z_UFormatCmdInitSpTb,A0  ; Command: Initialize_Spare_Table
    LEA     s_UFormatErrF,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    BNE     .qt                      ; Bail on failure

    ; Issue scan command
.x2 mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'6. PERFORMING SURFACE SCAN'>
    MOVE.B  #2,D0                    ; The Scan command is two bytes long
    LEA     s_UFormatCmdScan,A0      ; Command: Scan
    JSR     WIDGETCMD                ; Construct actual command in RAM
    JSR     WIDGETIO                 ; Issue command (we expect+ignore failure)

    MOVE.B  #3,D0                    ; The next command is three bytes long
    LEA     s_UFormatCmdStdStatus,A0   ; Command: get standard status
    JSR     WIDGETCMD                ; Construct the actual command in RAM
    MOVE.W  #19,D1                   ; We'll try the command 20 times
.s1 JSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Jump to the exit!
    DBEQ    D1,.s1                   ; Otherwise, try again

    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sCmdScanFail
    JSR     WIDGETPERROR             ; Error! Print error message
    BRA     .qt                      ; Bail, try to restore standard status

    ; All done.
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    ; Attempt to restore standard status and quit.
.qs MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UFormatCmdStdStatus,A0   ; Command: get standard status 
    LEA     s_UFormatErr2,A1         ; Message to print on error
    BSR     _UFormatDoCmd            ; Issue command
    ; Notify user of quitting and quit.
.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>
    RTS                              ; Back to caller


    ; _UFormatDoCmd -- Issue a Widget command; write an error message if needed
    ; Args:
    ;   D0: Command length
    ;   A0: Address of command template in RAM
    ;   A1: Address of error message in RAM
    ; Notes:
    ;   zWIOReadLen, zWIOWriteLen, zWIOReadPtr, and zWIOWritePtr should be set
    ;       prior to calling.
    ;   The Z bit is cleared iff a failure occurs, and a one-byte error code is
    ;       saved at zWIOError. (On success, zWIOError is $00.)
_UFormatDoCmd:
    JSR     WIDGETCMD                ; Construct actual command in RAM
    JSR     WIDGETIO                 ; Issue command
    BEQ.S   .rt                      ; Success? Return straightaway
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,A1
    JSR     WIDGETPERROR             ; Error! Print error message
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark error
.rt RTS                              ; Back to caller


    PAGE
* NeoWidEx Formatter scratch data allocation ===============
    SECTION kSecScratch

z_UFormatDryRun:
    DC.B    $00                      ; Whether it's a "dry run" of the formatter

    DS.W    0                        ; The seek command needs to be word-aligned
z_UFormatCmdSeek:
    DC.B    $10,$04,$00,$00          ; Command; bytes 3-6 (of 6) are alterable
    DC.B    $00,$00
z_UFormatCmdFmt:
    DC.B    $10,$0F,$00,$00          ; Command; bytes 3, 4 (of 8) are alterable
    DC.B    $F0,$78,$3C,$1E          ; These are the "password" command bytes
z_UFormatCmdInitSpTb:
    DC.B    $10,$10,$00,$00          ; Command; bytes 3, 4 (of 8) are alterable
    DC.B    $F0,$78,$3C,$1E          ; These are the "password" command bytes

    DS.W    0                        ; Force even alignment for following data
z_UFormatInitialVals:
    DC.B    '4mat'                   ; Initial field values for the form
    DC.B    'Init'
z_UFormatBounds:
    DC.B    '4mat'                   ; Bounds for command parameters
    DC.B    'Bnds'


    PAGE
* NeoWidEx Formatter strings ===============================
    SECTION kSecStrings

s_UFormatCmdStdStatus:
    DC.B    $10,$01,$00              ; Command for retrieving standard status
s_UFormatCmdCurCyl:
    DC.B    $10,$01,$03              ; Command for retrieving the current cyl.
s_UFormatCmdIntStatus:
    DC.B    $10,$01,$04              ; Command for retrieving internal status
s_UFormatCmdStateRegs:
    DC.B    $10,$01,$05              ; Command for retrieving state registers
s_UFormatCmdDiagRead:
    DC.B    $10,$09                  ; Diag_Read command
s_UFormatCmdFmtRecal:
    DC.B    $10,$05,$70              ; Command for format recalibration
s_UFormatCmdAutoOffset:
    DC.B    $10,$0C                  ; Command to set auto-offset
s_UFormatCmdSrvoStatus:
    DC.B    $10,$02,$01              ; Command to get "main" servo status
s_UFormatCmdSoftReset:
    DC.B    $10,$07                  ; Soft_Reset command
s_UFormatCmdScan:
    DC.B    $10,$13                  ; Scan command

s_UFormatErr0:
    DC.B    $0D,'FAILED TO GET WIDGET INTERNAL STATUS.',0
s_UFormatErr1:
    DC.B    $0D,'RECOVERY MODE IS ACTIVE. PLEASE DISABLE RECOVERY MODE AND'
    DC.B    $0D,'TRY FORMATTING AGAIN. CONSIDER ISSUING A SOFT RESET AS WELL'
    DC.B    $0D,'BEFORE DISABLING RECOVERY MODE.',0
s_UFormatErr2:
    DC.B    $0D,'FAILED TO GET WIDGET STANDARD STATUS.',0
s_UFormatErr3:
    DC.B    $0D,'THE WIDGET CONTROLLER INDICATES THAT ITS SELF-TEST HAS '
    DC.B    $0D,'FAILED. STOPPING NOW.',0
s_UFormatErr4:
    DC.B    $0D,'FAILED TO GET WIDGET STATE REGISTERS.',0
s_UFormatErr5:
    DC.B    $0D,'WIDGET STATE REGISTERS DO NOT LOOK HEALTHY. STOPPING NOW.',0
s_UFormatErr6:
    DC.B    $0D,'FAILED TO PERFORM FORMAT RECALIBRATION.',0
s_UFormatErr7:
    DC.B    $0D,'FAILED TO SEEK TO TRACK 0.',0
s_UFormatErr8:
    DC.B    $0D,'FAILED TO FORMAT THE CURRENT TRACK.',0
s_UFormatErr9:
    DC.B    $0D,'FAILED TO READ A SECTOR ON TRACK 0 AFTER TRIAL FORMAT.',0
s_UFormatErrA:
    DC.B    $0D,'FAILED TO GET CURRENT CYLINDER.',0
s_UFormatErrB:
    DC.B    $0D,'FAILED TO SEEK TO THIS FORMAT LOCATION.',0
s_UFormatErrC:
    DC.B    $0D,'FAILED TO FINE-TUNE HEAD POSITION AT THIS LOCATION.',0
s_UFormatErrD:
    DC.B    $0D,'FAILED TO OBTAIN SERVO STATUS.',0
s_UFormatErrE:
    DC.B    ' DOES NOT MATCH EXPECTED'
    DC.B    $0D,'  CONTROLLER STATE VALUE--0001DBE0. FORGING AHEAD ANYWAY...',0
s_UFormatErrF:
    DC.B    $0D,'FAILED TO INITIALISE SPARE TABLE.',0

s_UFormatSoftResetFail:
    DC.B    $0D,'FAILED TO COMMUNICATE WITH DRIVE AFTER RESET. ATTEMPTED'
    DC.B    $0D,'TO RETRIEVE CONTROLLER STATE VARIABLES 20 TIMES. THIS '
    DC.B    $0D,'WIDGET HAS NO SPARE TABLES NOW. LAST ERROR--',0

s_UFormatForm:                       ; User form for command parameters
    DC.B    $0D,'FORMAT OFFSET-aa INTERLEAVE-ba',0

    DS.W    0
s_UFormatPrompts:                    ; Form prompts for command parameters
    DC.L    .p1,.p2
.p1 DC.B    'OFFSET',0
.p2 DC.B    'INTERLEAVE',0

s_UFormatConfForm:                   ; User form for confirming command
    DC.B    $0D,'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
    DC.B    $0D,'zz THIS IS YOUR LAST CHANCE TO CANCEL zz'
    DC.B    $0D,'zz       REALLY FORMAT DRIVE? a       zz'
    DC.B    $0D,'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',0

    DS.W    0
s_UFormatConfPrompts:
    DC.L    .p1
.p1 DC.B    'PROCEED',0

s_UFormatDryRunForm:
    DC.B    $0D,'WELL HOW ABOUT JUST A DRY RUN THEN? a',0

    DS.W    0
s_UFormatDryRunPrompts:
    DC.L    .p1
.p1 DC.B    'DRY RUN',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
