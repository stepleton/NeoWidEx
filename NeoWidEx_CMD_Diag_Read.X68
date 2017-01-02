*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Diag_Read
* Written by : Tom Stepleton
* Date       : 2 January 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the diagnostic read command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Send_Seek must be defined.
*-----------------------------------------------------------


* NeoWidEx Diag_Read code ==================================

    ; CMD_Diag_Read -- Attempt the Diag_Read command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
    ;   Will ask the user if they want to seek somewhere first, in which case
    ;       calls into CMD_Send_Seek.
CMD_Diag_Read:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- READ AT SEEK ---'>

    ; See if the user wants to seek first. It's usually a good idea, since even
    ; if they've already seeked, the heads will probably have gone ahead and
    ; parked themselves.
    LEA     s_CDiagReadForm,A0       ; Prepare FORM args: address of template...
    LEA     s_CDiagReadPrompts,A1    ; ...address of prompt pointer array...
    LEA     s_CDiagReadInitialVals,A2  ; ...address of initial values array...
    SUBA.L  A3,A3                    ; ...and no value bounds specified
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .ws                      ; No, see if the user wanted to seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Did user want to seek first?
.ws TST.B   (3+zFieldValues)         ; Check user want-to-seek response
    BEQ.S   .go                      ; Looks like no; skip ahead to read
    BSR     CMD_Send_Seek_nobanner   ; Yes; jump into seek code

    ; Did user give up while seeking?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, seek is now done, go read
    RTS                              ; Yes, back to caller

    ; Perform the read
.go MOVE.B  #2,D0                    ; The command is two bytes long
    LEA     sCmdDiagRead,A0          ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; No command in this fike reads bytes
    CLR.W   zWIOWriteLen             ; No command in this file writes bytes
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ex                      ; All OK? Go check read exception register
    BSR     WIDGETPERROR             ; Error! Print error message
    MOVE.L  kStdStatus,-(A7)         ; Raw standard status to stack
    ; We go ahead and print the standard status because we are going to
    ; overwrite it in investigations to follow. This way the user can still
    ; inspect it for clues.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  RAW STANDARD STATUS-'>,lx

    ; Get exception registers from Widget
.ex MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CDiagReadStatusExp,A0  ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .rx                      ; All OK? Examine read exception register
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CDiagReadStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    BRA     .ss                      ; Skip ahead to get standard status

    ; Examine read exception register for errors
.rx CMP.B   #$20,kStdStatus          ; A nominal read has excp. reg. value $20
    BEQ     .ss                      ; Looks good, skip ahead to get std. status
    MOVE.B  kStdStatus,-(A7)         ; Error! Read-exception register onto stack
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CDiagReadExceptionErr
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<$0D,'SEE FULL STATUS FOR DETAILS.'>

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


    PAGE
* NeoWidEx Diag_Read strings ================================
    SECTION kSecStrings

sCmdDiagRead:
    DC.B    $10,$09                  ; Diag_Read command (it's short!)
s_CDiagReadStatusExp:
    DC.B    $10,$01,$06              ; Command to read exception registers
s_CDiagReadStatusStd:
    DC.B    $10,$01,$00              ; Command to read standard status

s_CDiagReadStatusErr0:
    DC.B    $0D,'FAILED TO RETRIEVE EXCEPTION REGISTERS.',0
s_CDiagReadExceptionErr:
    DC.B    $0D,'READ EXCEPTION DETECTED. EXCEPTION REGISTER-',0

s_CDiagReadForm:                     ; User form for asking about seeking
    DC.B    $0D,'SEEK SOMEWHERE FIRST? a',0

    DS.W    0
s_CDiagReadPrompts:                  ; Form prompts for asking about seeking
    DC.L    .p1
.p1 DC.B    'SEEK FIRST',0

    DS.W    0
s_CDiagReadInitialVals:              ; Initial values for the form
    DC.L    $00000001                ; By default, we do want to seek somewhere


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
