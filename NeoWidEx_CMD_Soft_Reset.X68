*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Soft_Reset
* Written by : Tom Stepleton
* Date       : XX December 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the soft-reset command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Soft_Reset code =================================

    ; CMD_Soft_Reset -- Attempt the Soft_Reset command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D1/A0.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Soft_Reset:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SOFT RESET ---'>
    CLR.B   zHaveInfo                ; Resetting? May as well refresh our info
    MOVE.B  #2,D0                    ; The command is two bytes long
    LEA     sCmdSoftReset,A0         ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Exit

    ; It would be weird if it were OK, since the drive should be busy resetting
    ; itself. So we poll it instead with successive requests for drive status.
    MOVE.B  #3,D0                    ; The command is three bytes long
    LEA     s_CmdSoftResetStdStatus,A0   ; Location of the cmd. template in RAM
    BSR     WIDGETCMD                ; Construct the actual command in RAM
    MOVE.W  #19,D1                   ; We'll try the command 20 times
.lp BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Exit
    DBEQ    D1,.lp                   ; Otherwise, try again...

    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,sCmdSoftResetFail
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Soft_Reset strings ===============================
    SECTION kSecStrings

sCmdSoftReset:
    DC.B    $10,$07                  ; Soft_Reset command (it's short!)
s_CmdSoftResetStdStatus:
    DC.B    $10,$01,$00              ; Command to request standard status

sCmdSoftResetFail:
    DC.B    $0D,'FAILED TO COMMUNICATE WITH DRIVE AFTER RESET. ATTEMPTED'
    DC.B    $0D,'TO RETRIEVE STANDARD STATUS 20 TIMES. LAST ERROR--'

** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
