*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Set_AutoOffset
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the auto-offset enable command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Set_AutoOffset code =============================

    ; CMD_Set_AutoOffset-- Attempt the Set_AutoOffset command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Set_AutoOffset:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- AUTO-OFFSET HEADS ---'>
    MOVE.B  #2,D0                    ; The command is two bytes long
    LEA     sCmdSetAutoOffset,A0     ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Exit
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Set_AutoOffset strings ==========================
    SECTION kSecStrings

sCmdSetAutoOffset:
    DC.B    $10,$0C                  ; Set_AutoOffset command (it's short!)


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
