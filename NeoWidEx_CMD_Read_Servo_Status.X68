*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Read_Servo_Status
* Written by : Tom Stepleton
* Date       : XX December 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: print full servo status.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Read_Servo_Status code ==========================

    ; CMD_Read_Servo_Status -- print ALL the servo statuses
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0-A1.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Read_Servo_Status:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail

    ; The pager (cf `qpendl`) will allow the user to abort this routine after
    ; each of the status commands, but before the user leaves this subroutine,
    ; we need to be certain that the standard status is restored to kStdStatus
    ; (since the Widget interactions that follow will fill it with...
    ; nonstandard statuses). To ensure that this restoration occurs even when
    ; the user aborts the paging, we push the address of the restoration
    ; routine onto the stack, so `qpendl` will jump there.
    MOVE.L  #.ss,-(A7)               ; Return pointer refers to status restore

    ; Print first servo status bitmap.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 1 OF 8 ---'>
    MOVE.B  #$00,(zServoStatusCmd+2) ; Subcommand: get servo status 1
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print servo status bitmap 1 part 1 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus1Bitmap1,kStdStatus
    MOVE.B  (kStdStatus+1),D0        ; Byte 1 to D0 to print offset DAC value
    BSR     _PRINTSERVOOFFSETDAC     ; Print offset DAC value
    ; Print servo status bitmap 1 part 2 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus1Bitmap2,kStdStatus
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print second servo status bitmap.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 2 OF 8 ---'>
    MOVE.B  #$01,(zServoStatusCmd+2) ; Subcommand: get servo status 2
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print servo status bitmap 2 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus2Bitmap1
    MOVE.B  kStdStatus,-(A7)         ; First status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print first status byte
    ; Print servo status bitmap 2 part 2 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus2Bitmap2,kStdStatus
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print third servo status bitmap
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 3 OF 8 ---'>
    MOVE.B  #$02,(zServoStatusCmd+2) ; Subcommand: get servo status 3
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print servo status bitmap 3 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Bitmap1
    MOVE.B  kStdStatus,-(A7)         ; First status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print first status byte
    ; Print servo status bitmap 3 part 2 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Bitmap2
    MOVE.B  (kStdStatus+1),-(A7)     ; Second status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl  ; Print second status byte
    ; Print servo status bitmap 3 part 3 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Bitmap3,kStdStatus
    MOVE.B  (kStdStatus+3),-(A7)     ; Fourth status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl  ; Print fourth status byte
    ; Print servo status bitmap 3 part 4 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Bitmap4,kStdStatus
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print fourth servo status bitmap
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 4 OF 8 ---'>
    MOVE.B  #$03,(zServoStatusCmd+2) ; Subcommand: get servo status 4
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print servo status bitmap 4 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus4Bitmap1
    MOVE.W  kStdStatus,-(A7)         ; First status word onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,endl   ; Print first status word
    ; Print servo status bitmap 4 part 2 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus4Bitmap2,kStdStatus
    MOVE.B  (kStdStatus+3),-(A7)     ; Fourth status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print fourth status byte
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print fifth servo status bitmap
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 5 OF 8 ---'>
    MOVE.B  #$04,(zServoStatusCmd+2) ; Subcommand: get servo status 5
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print servo status bitmap 5 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Bitmap1
    MOVE.B  kStdStatus,-(A7)         ; First status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print first status byte
    ; Print servo status bitmap 5 part 2 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Bitmap2
    MOVE.B  (kStdStatus+1),-(A7)     ; Second status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl  ; Print second status byte
    ; Print servo status bitmap 5 part 3 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Bitmap3
    MOVE.B  (kStdStatus+2),-(A7)     ; Third status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print third status byte
    ; Print servo status bitmap 5 part 4 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Bitmap4
    MOVE.B  (kStdStatus+3),D0        ; Byte 4 to D0 to print offset DAC value
    BSR     _PRINTSERVOOFFSETDAC     ; Print offset DAC value
    ; Print servo status bitmap 5 part 5 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Bitmap5,kStdStatus
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print sixth servo status bitmap
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 6 OF 8 ---'>
    MOVE.B  #$05,(zServoStatusCmd+2) ; Subcommand: get servo status 6
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus6Header
    BSR     _PRINTSERVOCOMMAND       ; Print servo command bitmap
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print seventh servo status bitmap
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 7 OF 8 ---'>
    MOVE.B  #$06,(zServoStatusCmd+2) ; Subcommand: get servo status 7
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print servo status bitmap 5 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus7Bitmap1
    ; No pause here; move ahead to status bitmap 8

    ; Print eighth servo status bitmap
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS 8 OF 8 ---'>
    MOVE.B  #$07,(zServoStatusCmd+2) ; Subcommand: get servo status 8
    BSR     .wi                      ; Execute servo status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus8Header
    BSR     _PRINTSERVOCOMMAND       ; Print servo command bitmap

    ; We've reached the end of the subroutine "organically" without the user
    ; aborting paging. Pop the status restoration code address off the stack.
    ADDQ.L  #4,A7                    ; Pop .ss address off the stack

    ; Reload standard status into kStdStatus so that subsequent calls to
    ; STATUSPRINT actually print the standard status and not something weird.
.ss MOVEM.L D0/A0,-(A7)              ; Save registers used to the stack
    MOVE.B  #3,D0                    ; Get status commands are 3 bytes long
    LEA     sStdStatusCommand,A0     ; Location of the command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue Widget command
    MOVEM.L (A7)+,D0/A0              ; Restore registers used from the stack
    BNE     .es                      ; Error? Jump to print header and exit
    RTS                              ; No error, return to caller at last
.es mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'WHILE RESTORING STANDARD STATUS'>

.er BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller, (often via .ss)

    ; Tiny subroutine that CMD_Read_Servo_Status uses to print the four status
    ; status bytes read from the Widget servo.
.pw mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'                          '>
    MOVE.B  (kStdStatus+3),-(A7)     ; Fourth status byte to stack for printing
    MOVE.B  (kStdStatus+2),-(A7)     ; Third status byte
    MOVE.B  (kStdStatus+1),-(A7)     ; Second status byte
    MOVE.B  (kStdStatus+0),-(A7)     ; First status byte; now print them all
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<' '>,hhx,<' '>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<' '>,hhx,endl
    RTS                              ; Back to caller

    ; Tiny subroutine that CMD_Read_Servo_Status uses to send the command at
    ; zServoStatusCmd to the Widget. No data is read or written; only the
    ; four status bytes are recovered (and stored at kStdStatus as usual).
.wi MOVEM.L D0/A0,-(A7)              ; Save registers used to stack
    MOVE.B  #3,D0                    ; All ...Status commands are 3 bytes long
    LEA     zServoStatusCmd,A0       ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue Widget command
    MOVEM.L (A7)+,D0/A0              ; Restore registers used
    RTS                              ; Back to caller

    ; _PRINTSERVOOFFSETDAC -- CMD_Read_Servo_Status helper: print offset DAC.
    ; Args:
    ;   D0: status byte containing offset DAC value.
    ; Notes:
    ;   Pops offset DAC value off the stack after printing.
    ;   Trashes D0.
_PRINTSERVOOFFSETDAC:
    BTST.L  #$02,D0                  ; What's the value's sign?
    BNE.S   .ps                      ; Positive; skip ahead
    mPrtLit kCrtRow,kCrtCol,#kFirstCol,noexport,<'-'>  ; Negative; print '-'
.ps ADDQ.W  #1,kCrtCol               ; Advance cursor one pos (note noexp above)
    ANDI.B  #$1F,D0                  ; Mask so (A7) only contains magnitude
    MOVE.B  D0,-(A7)                 ; Magnitude onto stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print magnitude
    RTS                              ; Back to caller

    ; _PRINTSERVOCOMMAND -- CMD_Read_Servo_Status helper: print servo command.
    ; Args:
    ;   (kStdStatus): holds a Widget servo command.
    ; Notes:
    ;   (none)
_PRINTSERVOCOMMAND:
    MOVEM.L D0/A0,-(A7)               ; Save used registers onto the stack
    ; Print servo command bitmap part 1 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoCommandBitmap1,kStdStatus
    ; Print servo command interpretation
    CLR.W   D0                       ; Zero out D0
    MOVE.B  kStdStatus,D0            ; First byte of servo command to D0
    LSR.B   #4,D0                    ; Move command bits to low-order nibble
    LSL.B   #2,D0                    ; Now multiply command bits by 4
    MOVE.L  #dServoCommandTable,A0   ; Command description string table into D0
    MOVE.L  0(A0,D0.W),-(A7)         ; Copy out indexed string pointer to stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,endl  ; Print command description
    ; Print servo command seek magnitude
    MOVE.W  kStdStatus,-(A7)         ; First word of servo command onto stack
    ANDI.W  #$03FF,(A7)              ; Mask bits for seek magnitude
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  MOTION ARGUMENT-'>,hx,<' TRACKS '>
    BTST.B  #$02,kStdStatus          ; Which way are we seeking?
    BEQ     .aw                      ; Away from the spindle
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'TOWARD'>  ; Toward the spindle
    BRA     .sl                      ; Move ahead to print 'spindle'
.aw mPrint  kCrtRow,kCrtCol,#kFirstCol,<'AWAY FROM'>
    ; Print servo command bitmap part 2 with explanatory text.
.sl mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoCommandBitmap2,kStdStatus
    MOVE.B  (kStdStatus+2),-(A7)     ; Third status byte onto stack
    ANDI.B  #$1F,(A7)                ; Mask bits for offset magnitude
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print offset magnitude
    MOVEM.L (A7)+,D0/A0              ; Restore D0 from the stack
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Read_Servo_Status numerical data ================
    SECTION kSecData

    ; Table of servo command description strings.
    DS.L    0                        ; Align to longs
dServoCommandTable:
    DC.L    sServoCommand0
    DC.L    sServoCommand1
    DC.L    sServoCommand2
    DC.L    sServoCommandUnknown
    DC.L    sServoCommand4
    DC.L    sServoCommandUnknown
    DC.L    sServoCommandUnknown
    DC.L    sServoCommand7
    DC.L    sServoCommand8
    DC.L    sServoCommand9
    DC.L    sServoCommandUnknown
    DC.L    sServoCommandUnknown
    DC.L    sServoCommandC
    DC.L    sServoCommandUnknown
    DC.L    sServoCommandUnknown
    DC.L    sServoCommandUnknown


    PAGE
* NeoWidEx Read_Servo_Status scratch data allocation =======
    SECTION kSecScratch

zServoStatusCmd:
    DC.B    $10,$02,$00              ; Command; last byte is alterable
    DS.W    0                        ; Force even alignment for following data


    PAGE
* NeoWidEx Read_Servo_Status strings =======================
    SECTION kSecStrings
sStdStatusCommand:
    DC.B    $10,$01,$00              ; Command: retrieve standard status

sServoStatus1Bitmap1:
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '  POWER AMP OFF/PARK HEADS-w       OFFSET DAC VALUE IS... ',0
sServoStatus1Bitmap2:
    DC.B    $0D
    DC.B    '     HA-2405 MUX AT U3E D0-x          HA-2405 MUX AT U5D D0-u',$0D
    DC.B    '     HA-2405 MUX AT U3E D1-y          HA-2405 MUX AT U5D D1-v',$0D
    DC.B    ' HA-2405 MUX AT U3E ENABLE-z',$0D
    DC.B    '  L291 OFFSET DAC STRB OFF-{',$0D
    DC.B    '       RECAL MODE SELECTED-|',$0D
    DC.B    '    SETTLING MODE SELECTED-}',$0D
    DC.B    '      ACCESS MODE SELECTED-~',$0D
    DC.B    $0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    '        OP AMP U2G IS FAST-g           /ON TRACK?/ P3.2 IRQ-_',$0D
    DC.B    '         ON TRACK WINDOW??-h     /POS ERR SAMPLE?/ P3.3 IRQ-`',$0D
    DC.B    ' POS ERR MORE THAN DAC VAL-i           /ON TRACK?/ P3.1 IRQ-a',$0D
    DC.B    '  AUTO-ZERO INTEGRATOR U1B-j           /SERIAL IN/ P3.0 IRQ-b',$0D
    DC.B    '    IN FINAL TRACK WINDOW?-k   /SIO?/ACCESS?/ TMR/CTR 0 IRQ-c',$0D
    DC.B    '        OP AMP U2H IS FAST-l   /TRACK PULSE?/ TMR/CTR 1 IRQ-d',$0D
    DC.B    '     HA-2405 MUX AT U3C D0-m                      BIT 6 IRQ-e',$0D
    DC.B    '           ODD/EVEN IS ODD-n                      BIT 7 IRQ-f',0

sServoStatus2Bitmap1:
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '              SIO REGISTER-',0
sServoStatus2Bitmap2:
    DC.B                                 '          SERIAL IO RECEIVE IN-v',$0D
    DC.B    '                                                   PORT 3.1-u',$0D
    DC.B    '                -BYTE 2-                           PORT 3.2-t',$0D
    DC.B    '      TIMER/COUNTER 0 LOAD-n                       PORT 3.3-s',$0D
    DC.B    '   TMR/CTR 0 COUNT ENABLED-m                SERIAL IO READY-r',$0D
    DC.B    '      TIMER/COUNTER 1 LOAD-l                    SERVO READY-q',$0D
    DC.B    '   TMR/CTR 1 COUNT ENABLED-k                    SERVO ERROR-p',$0D
    DC.B    '                                     SERIAL IO TRANSMIT OUT-o',$0D
    DC.B    '                -BYTE 3-',$0D
    DC.B    '  USER FLAG F1-_          USER FLAG F2-`         HALF CARRY-a',$0D
    DC.B    '  DECIMAL ADJUST-b   OVERFLOW-c    SIGN-d   ZERO-e    CARRY-f',0

sServoStatus3Bitmap1:
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '           TIMER/COUNTER 0-',0
sServoStatus3Bitmap2:
    DC.B                                 '               TIMER/COUNTER 1-',0
sServoStatus3Bitmap3:
    DC.B    $0D
    DC.B    '         /ON TRACK?/ P3.2 INT MASK-g       REGISTER POINTER-',0
sServoStatus3Bitmap4:
    DC.B    '   /POS ERR SAMPLE?/ P3.3 INT MASK-h',$0D
    DC.B    '         /ON TRACK?/ P3.1 INT MASK-i',$0D
    DC.B    '         /SERIAL IN/ P3.0 INT MASK-j',$0D
    DC.B    ' /SIO?/ACCESS?/ TMR/CTR 0 INT MASK-k',$0D
    DC.B    ' /TRACK PULSE?/ TMR/CTR 1 INT MASK-l',$0D
    DC.B    '                    BIT 6 INT MASK-m',$0D
    DC.B    '                    BIT 7 INT MASK-n',0

sServoStatus4Bitmap1:
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '                            STACK POINTER-',0
sServoStatus4Bitmap2:
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    '        SERVO COMMAND BITS-jihg          ACCESS TIMEOUT MSB-',0

sServoStatus5Bitmap1:
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '          SCRATCH BYTE? 0E-',0
sServoStatus5Bitmap2:
    DC.B                                 '              SCRATCH BYTE? 0C-',0
sServoStatus5Bitmap3:
    DC.B    $0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    ' STATE MACHINE FAULT STATE-',0
sServoStatus5Bitmap4:
    DC.B                              '    OFFSET DAC VAL MASK IS... ',0
sServoStatus5Bitmap5:
    DC.B    $0D
    DC.B    '                                 HA-2405 MUX AT U5D D0 MASK-1',$0D
    DC.B    '                                 HA-2405 MUX AT U5D D1 MASK-1',0

sServoStatus6Header:
    DC.B    '                  LAST COMMAND SERVO RECEIVED',$0D,$0D,0

sServoStatus7Bitmap1:
    DC.B    '  BYTES ARE IRQ P0 P3 AND P1MASK WHICH HAVE BEEN SEEN IN',$0D
    DC.B    '  OTHER SERVO STATUS PAGES ALREADY.',$0D,0  ; LF since no pause

sServoStatus8Header:
    DC.B    '                  LAST COMMAND SERVO PROCESSED',$0D,$0D,0

sServoCommandBitmap1:
    DC.B    '                -BYTE 0 AND BYTE 1-',$0D
    DC.B    '  COMMAND-~}|{ WHICH MEANS ',0
sServoCommandBitmap2:
    DC.B                             ' SPINDLE',$0D
    DC.B    $0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    '     OFFSET TOWARD SPINDLE-n   SERIAL IO AT 57.6K NOT 19.2K-f',$0D
    DC.B    '       AUTO OFFSET ENABLED-m             POWER ON RESET BIT-e',$0D
    DC.B    '      READ OFFSET FROM DAC-l      STATUS/DIAGNOSTIC BITS-ba`_',$0D
    DC.B    '          OFFSET MAGNITUDE-',0

    ; Servo command description strings.
sServoCommand0:
    DC.B    'READ STATUS',0
sServoCommand1:
    DC.B    'OFFSET---TRACK FOLLOWING',0
sServoCommand2:
    DC.B    'DIAGNOSTIC COMMAND',0
sServoCommand4:
    DC.B    'NORMAL RECAL---TO TRACK 72',0
sServoCommand7:
    DC.B    'FORMAT RECAL---TO TRACK 32',0
sServoCommand8:
    DC.B    'ACCESS ONLY',0
sServoCommand9:
    DC.B    'ACCESS WITH OFFSET',0
sServoCommandC:
    DC.B    'HOME---SEND TO ID STOP',0
sServoCommandUnknown:
    DC.B    'UNKNOWN---NOT A COMMAND',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
