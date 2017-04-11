*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Set_Recovery
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Sets the Widget's Recovery state.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Set_Recovery code ===============================

    ; CMD_Set_Recovery -- Toggle the Widget's recovery mode state
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Set_Recovery:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SET RECOVERY MODE ---'>
    CLR.W   zWIOReadLen              ; No command we use reads any data
    CLR.W   zWIOWriteLen             ; No command we use writes any data

    ; Query current recovery status from controller internal status info.
    LEA     s_CSetRecStatusInt,A0    ; Command: get internal ctrlr status
    MOVE.B  #3,D0                    ; This command is three bytes long
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .fm                      ; All OK? Advance to show form
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSetRecStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    CLR.L   kStdStatus               ; Clear std. status; recovery presumed off

    ; Query user for preferred state of controller.
.fm CLR.L   z_CSetRecInitialVals     ; Clear initial field value
    MOVE.L  kStdStatus,D1            ; Move status to D0 for bit testing
    BTST.L  #$1F,D1                  ; Is the recovery bit set?
    BEQ.S   .f0                      ; No, we are ready to query user
    MOVE.B  #$01,(3+z_CSetRecInitialVals)  ; Yes, set initial form value to Y
.f0 LEA     s_CSetRecForm,A0         ; Prepare FORM args: address of template...
    LEA     s_CSetRecPrompts,A1      ; ...address of prompt pointer array...
    LEA     z_CSetRecInitialVals,A2  ; ...address of initial values array...
    SUBA.L  A3,A3                    ; ...no form value bounds
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, go ahead with setting recovery mode
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Set user-specified recovery mode.
.go LEA     sCmdSetRecoveryOff,A0    ; By defaut, assume user wanted it off
    TST.B   (3+zFieldValues)         ; Did the user want it on?
    BEQ.S   .wc                      ; No, proceed to turn it off
    LEA     sCmdSetRecoveryOn,A0     ; Yes, get ready to turn it on
.wc MOVE.B  #3,D0                    ; Either command is three bytes long
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .is                      ; All OK? Advance to reload internal status
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO CHANGE RECOVERY MODE.'>
    BSR     WIDGETPERROR             ; Error! Print error message

    ; Query new recovery status from controller internal status info.
.is LEA     s_CSetRecStatusInt,A0    ; Command: get internal ctrlr status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .pr                      ; All OK? Advance to print recovery status
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSetRecStatusErr1
    BSR     WIDGETPERROR             ; Error! Print error message
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'NOT SURE WHAT MODE WE ARE IN...'>
    BRA     .ss                      ; Skip ahead to recover standard status

    ; Print the new current recovery status.
.pr mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'RECOVERY IS NOW '>
    MOVE.L  kStdStatus,D1            ; Move status to D1 for bit testing
    BTST.L  #$1F,D1                  ; Is the recovery bit set?
    BEQ     .nr                      ; No, skip ahead to say so
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'ACTIVE.'>   ; Yes, it is!
    BRA     .ss                      ; Skip ahead to recover standard status
.nr mPrint  kCrtRow,kCrtCol,#kFirstCol,<'INACTIVE.'>

    ; Restore standard status in kStdStatus.
.ss LEA     s_CSetRecStatusStd,A0    ; Command: get standard controller status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .rt                      ; All OK? Advance to return to caller
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO GET STANDARD STATUS.'>
    BSR     WIDGETPERROR             ; Error! Print error message

.rt RTS                              ; Back to caller


    PAGE
* NeoWidEx Set_Recovery scratch data allocation ============
    SECTION kSecScratch

    DS.W    0
z_CSetRecInitialVals:
    DC.B    'SRIV'                   ; Initial field values for the form


    PAGE
* NeoWidEx Set_Recovery strings ============================
    SECTION kSecStrings

sCmdSetRecoveryOff:
    DC.B    $10,$06,$00              ; Command to disable recovery
sCmdSetRecoveryOn:
    DC.B    $10,$06,$01              ; Command to enable recovery
s_CSetRecStatusInt:
    DC.B    $10,$01,$04              ; Command to read ctrlr internal status
s_CSetRecStatusStd:
    DC.B    $10,$01,$00              ; Command to read standard status

s_CSetRecStatusErr0:
    DC.B    $0D,'FAILED TO GET WIDGET CONTROLLER INTERNAL STATUS.',0
s_CSetRecStatusErr1:
    DC.B    $0D,'FAILED TO GET NEW WIDGET CONTROLLER INTERNAL STATUS.',0

s_CSetRecForm:                       ; User form for recovery mode
    DC.B    $0D,'WANT RECOVERY MODE ON? a',0

    DS.W    0
s_CSetRecPrompts:                    ; Form prompts for recovery mode
    DC.L    .p1
.p1 DC.B    'RECOVERY MODE ON',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
