*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Diag_Write
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the diagnostic write command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Send_Seek must be defined.
*-----------------------------------------------------------


* NeoWidEx Diag_Write code =================================

    ; CMD_Diag_Write -- Attempt the Diag_Write command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
    ;   Will ask the user if they want to seek somewhere first, in which case
    ;       calls into CMD_Send_Seek.
CMD_Diag_Write:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- WRITE AT SEEK ---'>

    ; See if the user wants to seek first. It's usually a good idea, since even
    ; if they've already seeked, the heads may have been bumped, or have gone
    ; ahead and parked themselves.
    LEA     s_CDiagWriteForm,A0      ; Prepare FORM args: address of template...
    LEA     s_CDiagWritePrompts,A1   ; ...address of prompt pointer array...
    LEA     s_CDiagWriteInitialVals,A2   ; ...address of initial values array...
    SUBA.L  A3,A3                    ; ...and no value bounds specified
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .ws                      ; No, see if the user wanted to seek
    BRA     .qt                      ; Yes, go ahead to ack user and cancel

    ; Did user want to seek first?
.ws TST.B   (3+zFieldValues)         ; Check user want-to-seek response
    BEQ.S   .cf                      ; Looks like no; skip ahead to confirm
    BSR     CMD_Send_Seek_nobanner   ; Yes; jump into seek code

    ; Did user give up while seeking?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .cf                      ; No, seek is now done, go confirm
    RTS                              ; Yes, back to caller

    ; Does the user really want to write?
.cf LEA     s_CDiagReallyWriteForm,A0  ; Prep. FORM args: address of template...
    LEA     s_CDiagReallyWritePrompts,A1   ; ...addr. of prompt pointer array...
    SUBA.L  A2,A2                    ; ...no initial values specified...
    SUBA.L  A3,A3                    ; ...and no value bounds specified
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel by typing 'Q'?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel
    TST.B   (3+zFieldValues)         ; Did the user cancel by submitting 'N'?
    BEQ     .qt                      ; Yes, go ahead to ack user and cancel

    ; Perform the write
.go MOVE.B  #2,D0                    ; The command is two bytes long
    LEA     sCmdDiagWrite,A0         ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; No command in this file reads bytes
    MOVE.W  zBlockSize,zWIOWriteLen  ; Write a whole block to the Widget
    MOVE.L  #zSectorTag,zWIOWritePtr   ; Write data from this memory location
    BSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the write command go ok?
    BEQ     .ex                      ; Yes, go check read exception register
    BSR     WIDGETPERROR             ; Error! Print error message
    MOVE.L  kStdStatus,-(A7)         ; Raw standard status to stack
    ; We go ahead and print the standard status because we are going to
    ; overwrite it in investigations to follow. This way the user can still
    ; inspect it for clues.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  RAW STANDARD STATUS-'>,lx

    ; Get exception registers from Widget
.ex MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CDiagWriteStatusExp,A0   ; Location of the command template in RAM
    CLR.W   zWIOWriteLen             ; Remaining cmds in this file write nothing
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .rx                      ; All OK? Examine write exception register
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CDiagWriteStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    BRA     .ss                      ; Skip ahead to get standard status

    ; Examine write exception register for errors
.rx CMPI.W  #$2000,(2+kStdStatus)    ; A nominal write has register value $2000
    BEQ     .ss                      ; Looks good, skip ahead to get std. status
    MOVE.B  (2+kStdStatus),-(A7)     ; Error! Write-exception reg. onto stack
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CDiagWriteExceptionErr
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<$0D,'SEE FULL STATUS FOR DETAILS.'>

    ; Restore standard status in kStdStatus.
.ss MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSndSkStatusStd,A0     ; Command: get standard controller status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Advance to return to caller
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO GET STANDARD STATUS.'>
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    ; Execution branch for when the user chooses to cancel.
.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Diag_Write strings ===============================
    SECTION kSecStrings

sCmdDiagWrite:
    DC.B    $10,$0B                  ; Diag_Write command (it's short!)
s_CDiagWriteStatusExp:
    DC.B    $10,$01,$06              ; Command to write exception registers
s_CDiagWriteStatusStd:
    DC.B    $10,$01,$00              ; Command to write standard status

s_CDiagWriteStatusErr0:
    DC.B    $0D,'FAILED TO RETRIEVE EXCEPTION REGISTERS.',0
s_CDiagWriteExceptionErr:
    DC.B    $0D,'WRITE EXCEPTION DETECTED. EXCEPTION REGISTER-',0

s_CDiagWriteForm:                    ; User form for asking about seeking
    DC.B    $0D,'SEEK SOMEWHERE FIRST? a',0

    DS.W    0
s_CDiagWritePrompts:                 ; Form prompts for asking about seeking
    DC.L    .p1
.p1 DC.B    'SEEK FIRST',0

s_CDiagReallyWriteForm:              ; User form for confirming write intent
    DC.B    $0D,'REALLY WRITE? a',0

    DS.W    0
s_CDiagReallyWritePrompts:           ; Form promts for confiming write intent
    DC.L    .p1
.p1 DC.B    'WRITE',0

    DS.W    0
s_CDiagWriteInitialVals:             ; Initial values for the form
    DC.L    $00000001                ; By default, we do want to seek somewhere


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
