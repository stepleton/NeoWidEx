*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Diag_ReadHeader
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the diagnostic read header command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Send_Seek must be defined.
*-----------------------------------------------------------


* NeoWidEx Diag_ReadHeader code ============================

    ; CMD_Diag_ReadHeader -- Attempt the Diag_ReadHeader command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
    ;   Will ask the user if they want to seek somewhere first, in which case
    ;       calls into CMD_Send_Seek.
CMD_Diag_ReadHeader:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- READ HEADER AT SEEK ---'>

    ; See if the user wants to seek first. It's usually a good idea, since even
    ; if they've already seeked, the heads may have been bumped, or have gone
    ; ahead and parked themselves.
    LEA     s_CDiagReadHdrForm1,A0   ; Prepare FORM args: address of template...
    LEA     s_CDiagReadHdrForm1Prompts,A1  ; ...prompt pointer address array...
    LEA     s_CDiagReadHdrForm1InitialVals,A2   ; ...initial values array...
    SUBA.L  A3,A3                    ; ...and no value bounds specified
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, skip ahead to abort

    ; Did user want to seek first?
.ws TST.B   (3+zFieldValues)         ; Check user want-to-seek response
    BEQ.S   .f2                      ; Looks like no; skip ahead to second form
    BSR     CMD_Send_Seek_nobanner   ; Yes; jump into seek code

    ; Did user give up while seeking?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .f2                      ; No, seek is now done, go do second form
    RTS                              ; Yes, back to caller

    ; Set second form bounds based on drive information.
.f2 CLR.L   D0                       ; Prepare to compute sectors field bound
    MOVE.B  zSectors,D0              ; Number of sectors
    SUBQ.B  #1,D0                    ; Largest addressable sector is upper...
    MOVE.L  D0,z_CDiagReadHdrForm2Bounds   ; ...bound for the field

    ; Ask user which sector they'd like to read the header of
    LEA     s_CDiagReadHdrForm2,A0   ; Prepare FORM args: address of template...
    LEA     s_CDiagReadHdrForm2Prompts,A1  ; ...prompt pointer address array...
    LEA     z_CDiagReadHdrForm2InitialVals,A2   ; ...initial values array...
    LEA     z_CDiagReadHdrForm2Bounds,A3   ; ...and the value bounds array
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, skip ahead to abort

    ; Copy response into Diag_ReadHeader command, and into initial values array
    MOVE.L  zFieldValues,D0          ; User response
    MOVE.L  D0,z_CDiagReadHdrForm2InitialVals   ; Save as next default
    MOVE.B  D0,(2+z_CDiagReadHdrCmd)   ; And as sector argument in command

    ; Perform the read header operation
.go MOVE.B  #3,D0                    ; The command is two bytes long
    LEA     Z_CDiagReadHdrCmd,A0     ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    MOVE.W  zBlockSize,zWIOReadLen   ; Read a whole block from the Widget
    ADDI.W  #kHeaderSize,zWIOReadLen   ; ...plus a diagnostic header up front
    MOVE.L  #zSectorHeader,zWIOReadPtr   ; Read into this memory location
    CLR.W   zWIOWriteLen             ; No command in this file writes bytes
    BSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the ReadHeader command go ok?
    BEQ     .ex                      ; Yes, go check read exception register
    BSR     WIDGETPERROR             ; Error! Print error message
    MOVE.L  kStdStatus,-(A7)         ; Raw standard status to stack
    ; We go ahead and print the standard status because we are going to
    ; overwrite it in investigations to follow. This way the user can still
    ; inspect it for clues.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  RAW STANDARD STATUS-'>,lx

    ; Get exception registers from Widget
.ex MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CDiagReadHdrCmdStatExp,A0  ; Location of the cmd. template in RAM
    CLR.W   zWIOReadLen              ; Remaining cmds in this file read no bytes
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .rx                      ; All OK? Examine read exception register
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CDiagReadHdrStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    BRA     .ss                      ; Skip ahead to get standard status

    ; Examine read exception register for errors. NOTE: The claim that a nominal
    ; result leaves $0000 in the first word of the exception register is mostly
    ; an empirical claim, but after looking at the ROM code on bitsavers, I
    ; don't see how Diag_ReadHeader would set the usual "at least one successful
    ; read" bit (yielding $2000). It might be too low-level for that.
.rx CMPI.W  #$0000,kStdStatus        ; A nominal result has register value $0000
    BEQ     .ss                      ; Looks good, skip ahead to get std. status
    MOVE.W  kStdStatus,-(A7)         ; Error! Read-exception register onto stack
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CDiagReadHdrExceptionErr
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<$0D,'SEE FULL STATUS FOR DETAILS.'>

    ; Restore standard status in kStdStatus.
.ss MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CDiagReadHdrStatusStd,A0   ; Command: get std. controller status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Advance to return to caller
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO GET STANDARD STATUS.'>
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    ; Acknowledge operation cancellation and return
.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    PAGE
* NeoWidEx Diag_ReadHeader scratch data allocation ==========
    SECTION kSecScratch

z_CDiagReadHdrCmd:
    DC.B    $10,$0A,$00              ; Diag_ReadHeader cmd. (last byte editable)

    DS.W    0
z_CDiagReadHdrForm2InitialVals:      ; Initial values for "which sector" form
    DC.L    $00000000

    DS.W    0
z_CDiagReadHdrForm2Bounds:           ; Bounds for the "which sector" form
    DC.L    $00000000


    PAGE
* NeoWidEx Diag_ReadHeader strings ==========================
    SECTION kSecStrings

s_CDiagReadHdrCmdStatExp:
    DC.B    $10,$01,$06              ; Command to read exception registers
s_CDiagReadHdrStatusStd:
    DC.B    $10,$01,$00              ; Command to read standard status

s_CDiagReadHdrStatusErr0:
    DC.B    $0D,'FAILED TO RETRIEVE EXCEPTION REGISTERS.',0
s_CDiagReadHdrExceptionErr:
    DC.B    $0D,'READ EXCEPTION DETECTED. EXCEPTION REGISTER-',0

s_CDiagReadHdrForm1:                 ; User form for asking about seeking
    DC.B    $0D,'READ HEADER CAN ONLY READ FROM THE CURRENT TRACK.'
    DC.B    $0D,'SEEK SOMEWHERE FIRST? a',0

    DS.W    0
s_CDiagReadHdrForm1Prompts:          ; Form prompts for asking about seeking
    DC.L    .p1
.p1 DC.B    'SEEK FIRST',0

    DS.W    0
s_CDiagReadHdrForm1InitialVals:      ; Initial values for the form
    DC.L    $00000001                ; By default, we do want to seek somewhere

s_CDiagReadHdrForm2:                 ; User form for asking which sector to read
    DC.B    $0D,'READ HEADER AND DATA OF WHICH SECTOR ON THIS TRACK? aa',0

    DS.W    0
s_CDiagReadHdrForm2Prompts:          ; Form prompts for asking which sector
    DC.L    .p1
.p1 DC.B    'WHICH SECTOR',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
