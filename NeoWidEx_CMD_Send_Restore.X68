*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Send_Restore
* Written by : Tom Stepleton
* Date       : 8 March 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Issues the Widget Send_Restore command
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Send_Restore code ===============================

    ; CMD_Send_Restore -- Issue the Send_Restore command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Send_Restore:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SEND RESTORE ---'>
    CLR.W   zWIOReadLen              ; No command we use reads any data
    CLR.W   zWIOWriteLen             ; No command we use writes any data

    ; Query user for the type of restore desired.
    LEA     s_CSendRestForm,A0       ; Prepare FORM args: address of template...
    LEA     s_CSendRestPrompts,A1    ; ...address of prompt pointer array...
    SUBA.L  A2,A2                    ; ...no form initial values...
    SUBA.L  A3,A3                    ; ...no form value bounds
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, go ahead with restoring
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Send the user-selected restore command.
.go LEA     sCmdSendRestoreData,A0   ; By defaut, assume user wanted data recal
    TST.B   (3+zFieldValues)         ; Did the user want format recal?
    BEQ.S   .wc                      ; No, proceed to send command
    LEA     sCmdSendRestoreFormat,A0   ; Yes, get ready to send format recal
.wc MOVE.B  #3,D0                    ; Either command is three bytes long
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Exit
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Send_Restore strings ============================
    SECTION kSecStrings

sCmdSendRestoreData:
    DC.B    $10,$05,$40              ; Command to send a "data restore"
sCmdSendRestoreFormat:
    DC.B    $10,$05,$70              ; Command to send a "format restore"

s_CSendRestForm:                     ; User form for restore mode
    DC.B    $0D,'FORMAT RECAL INSTEAD OF DATA RECAL? a',0

    DS.W    0
s_CSendRestPrompts:                  ; Form prompts for restore mode
    DC.L    .p1
.p1 DC.B    'FORMAT RECAL',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
