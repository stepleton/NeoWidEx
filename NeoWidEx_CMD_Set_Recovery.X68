*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Set_Recovery
* Written by : Tom Stepleton
* Date       : XX December 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Toggles the Widget's Recovery state.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Set_Recovery code ===============================

    ; CMD_Set_Recovery -- Toggle the Widget's recovery mode state
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D1/A0.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Set_Recovery:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- TOGGLE RECOVERY MODE ---'>
    MOVE.B  #3,D0                    ; All commands we use are three bytes long
    CLR.W   zWIOReadLen              ; No command we use reads any data
    CLR.W   zWIOWriteLen             ; No command we use writes any data

    ; Query current recovery status from controller internal status info.
    LEA     s_CSetRecStatusInt,A0    ; Command: get internal ctrlr status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .tg                      ; All OK? Advance to toggle recovery state
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSetRecStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'WILL TRY TO ENABLE RECOVERY MODE.'>
    CLR.L   kStdStatus               ; By clearing status (and its recovery bit)

    ; Attempt to set recovery status to opposite of its current value.
.tg LEA     sCmdSetRecoveryOn,A0     ; Get ready to turn recovery on
    MOVE.L  kStdStatus,D1            ; Move status to D0 for bit testing
    BTST.L  #$1F,D1                  ; Is the recovery bit set?
    BEQ.S   .re                      ; No, so go turn it on
    LEA     sCmdSetRecoveryOff,A0    ; Yes, so get ready to turn it off
.re BSR     WIDGETCMD                ; Construct actual command in RAM
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
    MOVE.L  kStdStatus,D1            ; Move status to D0 for bit testing
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


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
