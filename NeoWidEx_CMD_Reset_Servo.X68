*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Reset_Servo
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the servo reset command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Reset_Servo code ================================

    ; CMD_Reset_Servo -- Attempt the Reset_Servo command; print info
    ; Args:
    ;   (none)
    ; Notes:
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Reset_Servo:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- RESET SERVO ---'>,endl
    MOVE.B  #2,D0                    ; The command is two bytes long
    LEA     sCmdResetServo,A0        ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Exit
    MOVE.B  zWIOError,-(A7)          ; Error! Print error byte
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'ERROR '>,hhx,<'... CHECK STATUS.'>,endl
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DONE.'>,endl
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Reset_Servo strings ==============================
    SECTION kSecStrings

sCmdResetServo:
    DC.B    $10,$12                  ; Servo reset command (it's short!)


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
