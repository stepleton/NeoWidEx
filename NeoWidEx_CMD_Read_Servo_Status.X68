*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Read_Servo_Status
* Written by : Tom Stepleton
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

    ; First, retrieve and print all servo status longs
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- ALL SERVO STATUS LONGS ---'>
    BSR     _READALLSERVOSTATUS      ; Retrieve all controller status longs

    MOVE.B  #$00,D0                  ; We will print statuses in forward order
    MOVEA.L #zServoStatus1,A0        ; A0 points to current status storage entry
.lp MOVE.L  (A0)+,-(A7)              ; Status table entry to stack for printing
    MOVE.B  D0,-(A7)                 ; Status table index to stack for printing
    ADDQ.B  #1,(A7)                  ; Increment for true status subcommand byte
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,hhx,<'- '>,lx
    ADDQ.B  #1,D0                    ; Get ready to print next status
    CMPI.B  #$08,D0                  ; Or have we run out?
    BLT     .lp                      ; We haven't; back to print next status
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print first servo status bitmap.
    MOVE.B  #$01,D0                  ; Prepare to print servo status 1 header
    BSR     .ph                      ; Print it
    ; Print servo status bitmap 1 part 1 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus1Btmap1,zServoStatus1
    MOVE.B  (zServoStatus1+1),D0     ; Byte 1 to D0 to print offset DAC value
    BSR     PRINTSERVOOFFSETDAC      ; Print offset DAC value
    ; Print servo status bitmap 1 part 2 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus1Btmap2,zServoStatus1
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print second servo status bitmap.
    MOVE.B  #$02,D0                  ; Prepare to print servo status 2 header
    BSR     .ph                      ; Print it
    ; Print servo status bitmap 2 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus2Btmap1,zServoStatus2
    MOVE.B  zServoStatus2,-(A7)      ; First status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print first status byte
    ; Print servo status bitmap 2 part 2 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus2Btmap2,zServoStatus2
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print third servo status bitmap
    MOVE.B  #$03,D0                  ; Prepare to print servo status 3 header
    BSR     .ph                      ; Print it
    ; Print servo status bitmap 3 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Btmap1
    MOVE.B  zServoStatus3,-(A7)      ; First status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print first status byte
    ; Print servo status bitmap 3 part 2 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Btmap2
    MOVE.B  (zServoStatus3+1),-(A7)  ; Second status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl  ; Print second status byte
    ; Print servo status bitmap 3 part 3 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Btmap3,zServoStatus3
    MOVE.B  (zServoStatus3+3),-(A7)  ; Fourth status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl  ; Print fourth status byte
    ; Print servo status bitmap 3 part 4 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus3Btmap4,zServoStatus3
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print fourth servo status bitmap
    MOVE.B  #$04,D0                  ; Prepare to print servo status 4 header
    BSR     .ph                      ; Print it
    ; Print servo status bitmap 4 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus4Btmap1
    MOVE.W  zServoStatus4,-(A7)      ; First status word onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,endl   ; Print first status word
    ; Print servo status bitmap 4 part 2 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus4Btmap2,zServoStatus4
    MOVE.B  (zServoStatus4+3),-(A7)  ; Fourth status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print fourth status byte
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print fifth servo status bitmap
    MOVE.B  #$05,D0                  ; Prepare to print servo status 5 header
    BSR     .ph                      ; Print it
    ; Print servo status bitmap 5 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Btmap1
    MOVE.B  zServoStatus5,-(A7)      ; First status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print first status byte
    ; Print servo status bitmap 5 part 2 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Btmap2
    MOVE.B  (zServoStatus5+1),-(A7)  ; Second status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl  ; Print second status byte
    ; Print servo status bitmap 5 part 3 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Btmap3
    MOVE.B  (zServoStatus5+2),-(A7)  ; Third status byte onto stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print third status byte
    ; Print servo status bitmap 5 part 4 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Btmap4
    MOVE.B  (zServoStatus5+3),D0     ; Byte 4 to D0 to print offset DAC value
    BSR     PRINTSERVOOFFSETDAC      ; Print offset DAC value
    ; Print servo status bitmap 5 part 5 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus5Btmap5,zServoStatus5
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print sixth servo status bitmap
    MOVE.B  #$06,D0                  ; Prepare to print servo status 6 header
    BSR     .ph                      ; Print it
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus6Header
    BSR     _PRINTSERVOCOMMAND       ; Print servo command bitmap
    ; Done with this page
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print seventh servo status bitmap
    MOVE.B  #$07,D0                  ; Prepare to print servo status 7 header
    BSR     .ph                      ; Print it
    ; Print servo status bitmap 5 part 1 with explanatory text.
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus7Btmap1
    ; No pause here; move ahead to status bitmap 8

    ; Print eighth servo status bitmap
    MOVE.B  #$08,D0                  ; Prepare to print servo status 8 header
    BSR     .ph                      ; Print it
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sServoStatus8Header
    BSR     _PRINTSERVOCOMMAND       ; Print servo command bitmap

    RTS                              ; Back to CMD_Read_Servo_Status caller

    ; .ph -- CMD_Read_Controller_Status helper: print title and raw hex bytes
    ; Args:
    ;   D0: which status long (in 1..8) to print
    ; Notes:
    ;   Prints the title and hex dump of status long that shows above certain
    ;       status bitmaps.
    ;   Trashes D0/A0.
    ;   Specified status long is copied to D0.
.ph MOVE.B  D0,-(A7)                 ; Status index to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SERVO STATUS '>,hhx,<' ---'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'                          '>
    LEA     zServoStatus1,A0         ; Start of servo status table to A0
    SUBQ.B  #1,D0                    ; Make D0 zero-indexed
    ANDI.W  #$7,D0                   ; Mask out out-of-bounds bits in D0
    ASL.B   #2,D0                    ; Multiply D0 by sizeof(long)
    ADDA.W  D0,A0                    ; Add to A0 to point it to status long
    MOVE.L  (A0),D0                  ; Copy status long to D0
    ROL.L   #8,D0                    ; Get ready to move MSByte to stack...
    MOVE.B  D0,-(A7)                 ; ...then move, then print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx
    ROL.L   #8,D0                    ; Now secondmost significant byte...
    MOVE.B  D0,-(A7)                 ; ...to stack, then print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,hhx
    ROL.L   #8,D0                    ; Now second-least significant byte...
    MOVE.B  D0,-(A7)                 ; ...to stack, then print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,hhx
    ROL.L   #8,D0                    ; At last, LSByte...
    MOVE.B  D0,-(A7)                 ; ...to stack, then print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,hhx
    RTS                              ; Back to caller


    ; PRINTSERVOOFFSETDAC -- CMD_Read_Servo_Status helper: print offset DAC.
    ; Args:
    ;   D0: status byte containing offset DAC value.
    ; Notes:
    ;   Trashes D0.
PRINTSERVOOFFSETDAC:
    BTST.L  #$05,D0                  ; What's the value's sign?
    BNE.S   .ps                      ; Positive; skip ahead
    mPrtLit kCrtRow,kCrtCol,#kFirstCol,noexport,<'-'>  ; Negative; print '-'
.ps ADDQ.W  #1,kCrtCol               ; Advance cursor one pos (note noexp above)
    ANDI.B  #$1F,D0                  ; Mask so (A7) only contains magnitude
    MOVE.B  D0,-(A7)                 ; Magnitude onto stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print magnitude
    RTS                              ; Back to caller


    ; _PRINTSERVOCOMMAND -- CMD_Read_Servo_Status helper: print servo command.
    ; Args:
    ;   D0: a Widget servo command.
    ; Notes:
    ;   (none)
_PRINTSERVOCOMMAND:
    MOVEM.L D1/A0,-(A7)               ; Save used registers onto the stack
    ; Print servo command bitmap part 1 with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoCommandBtmap1,D0
    ; Print servo command interpretation
    MOVE.L  D0,D1                    ; Copy entire servo command to D1
    ROL.L   #4,D1                    ; Rotate servo command nibble to LSNibble
    ANDI.W  #$F,D1                   ; Mask servo command
    LSL.W   #2,D1                    ; Now multiply servo command by 4
    MOVE.L  #dServoCommandTable,A0   ; Command description string table into D1
    MOVE.L  0(A0,D1.W),-(A7)         ; Copy out indexed string pointer to stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,endl  ; Print command description
    ; Print servo command seek magnitude
    MOVE.L  D0,D1                    ; Copy entire servo command to D1
    SWAP    D1                       ; Swap first and last words of servo cmd
    MOVE.W  D1,-(A7)                 ; First word of servo command onto stack
    ANDI.W  #$03FF,(A7)              ; Mask bits for seek magnitude
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  MOTION ARGUMENT-'>,hx,<' TRACKS '>
    BTST.L  #$1A,D0                  ; Which way are we seeking?
    BEQ     .aw                      ; Away from the spindle
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'TOWARD'>  ; Toward the spindle
    BRA     .sl                      ; Move ahead to print 'spindle'
.aw mPrint  kCrtRow,kCrtCol,#kFirstCol,<'AWAY FROM'>
    ; Print servo command bitmap part 2 with explanatory text.
.sl mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sServoCommandBtmap2,D0
    MOVE.W  D0,D1                    ; Copy lower word of servo command to D1
    LSR.W   #8,D1                    ; Move the third byte to D1 LSByte
    ANDI.B  #$1F,D1                  ; Mask bits for offset magnitude
    MOVE.B  D1,-(A7)                 ; Place onto stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print offset magnitude
    MOVEM.L (A7)+,D1/A0              ; Restore used registers from the stack
    RTS                              ; Back to caller


    ; _READALLSERVOSTATUS -- Reads all 8 servo status longs to zServoStatusX
    ; Args:
    ;   (none)
    ; Notes:
    ;   Note how servo status counts up from 01.
_READALLSERVOSTATUS:
    MOVE.L  A1,-(A7)                 ; Save address registers used to stack
    MOVE.W  D0,-(A7)                 ; Save data register used to stack
    MOVE.B  #$08,D0                  ; We will load statuses in reverse order
    MOVEA.L #(zServoStatus1+7*4),A1  ; A1 points to curr status storage entry
.lp MOVE.B  D0,(zServoStatusCmd+2)   ; Specify Read_Servo_Status subcommand
    BSR     .sv                      ; Execute Read_Servo_Status command
    BEQ     .nx                      ; Read successful, finish up and move along
    MOVE.B  D0,-(A7)                 ; Read failed; subcommand to stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO RETRIEVE SERVO STATUS '>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx
    BSR     WIDGETPERROR             ; Print disk error string
.nx SUBQ.L  #4,A1                    ; Next status storage entry address into A1
    SUBQ.B  #1,D0                    ; Next status subcommand into D0
    CMPI.B  #0,D0                    ; Have we reached the end (subcomand 0?)
    BGT     .lp                      ; Repeat loop while status subcommand > 0
    MOVE.W  (A7)+,D0                 ; Restore data register used from stack
    MOVEA.L (A7)+,A1                 ; Restore address registers used from stack
    RTS                              ; Back to caller

    ; Tiny subroutine that _READALLSERVOSTATUS uses to send the command at
    ; zServoStatusCmd to the Widget. Four bytes of data---the servo's status
    ; bytes---are read to the location stored in A1. Standard status is stored
    ; at kStdStatus as usual.
.sv MOVEM.L D0/A0,-(A7)              ; Save registers used to stack
    MOVE.B  #3,D0                    ; All ...Status commands are 3 bytes long
    LEA     zServoStatusCmd,A0       ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    MOVE.W  #4,zWIOReadLen           ; We will read four servo status bytes...
    MOVE.L  A1,zWIOReadPtr           ; ...to the location stored in A1
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue Widget command
    MOVEM.L (A7)+,D0/A0              ; Restore registers used
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

zServoStatus1:                       ; These slots will hold all eight Widget...
    DC.B    '[Ser'                   ; ...servo status responses, but we...
zServoStatus2:                       ; ...initialise them with text to make...
    DC.B    'vo s'                   ; ...their use obvious to debuggers
zServoStatus3:
    DC.B    'tatu'
zServoStatus4:
    DC.B    's wi'
zServoStatus5:
    DC.B    'll b'
zServoStatus6:
    DC.B    'e pu'
zServoStatus7:
    DC.B    't he'
zServoStatus8:
    DC.B    're ]'


    PAGE
* NeoWidEx Read_Servo_Status strings =======================
    SECTION kSecStrings

sServoStatus1Btmap1:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '  POWER AMP OFF/PARK HEADS-w       OFFSET DAC VALUE IS... ',0
sServoStatus1Btmap2:
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

sServoStatus2Btmap1:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '              SIO REGISTER-',0
sServoStatus2Btmap2:
    DC.B                                 '          SERIAL IO RECEIVE IN-v',$0D
    DC.B    '                                                   PORT 3.1-u',$0D
    DC.B    '                -BYTE 2-                           PORT 3.2-t',$0D
    DC.B    '      TIMER/COUNTER 0 LOAD-g                       PORT 3.3-s',$0D
    DC.B    '   TMR/CTR 0 COUNT ENABLED-h                SERIAL IO READY-r',$0D
    DC.B    '      TIMER/COUNTER 1 LOAD-i                    SERVO READY-q',$0D
    DC.B    '   TMR/CTR 1 COUNT ENABLED-j                    SERVO ERROR-p',$0D
    DC.B    '                                     SERIAL IO TRANSMIT OUT-o',$0D
    DC.B    '                -BYTE 3-',$0D
    DC.B    '  USER FLAG F1-_          USER FLAG F2-`         HALF CARRY-a',$0D
    DC.B    '  DECIMAL ADJUST-b   OVERFLOW-c    SIGN-d   ZERO-e    CARRY-f',0

sServoStatus3Btmap1:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '           TIMER/COUNTER 0-',0
sServoStatus3Btmap2:
    DC.B                                 '               TIMER/COUNTER 1-',0
sServoStatus3Btmap3:
    DC.B    $0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    '         /ON TRACK?/ P3.2 INT MASK-g       REGISTER POINTER-',0
sServoStatus3Btmap4:
    DC.B    '   /POS ERR SAMPLE?/ P3.3 INT MASK-h',$0D
    DC.B    '         /ON TRACK?/ P3.1 INT MASK-i',$0D
    DC.B    '         /SERIAL IN/ P3.0 INT MASK-j',$0D
    DC.B    ' /SIO?/ACCESS?/ TMR/CTR 0 INT MASK-k',$0D
    DC.B    ' /TRACK PULSE?/ TMR/CTR 1 INT MASK-l',$0D
    DC.B    '                    BIT 6 INT MASK-m',$0D
    DC.B    '                    BIT 7 INT MASK-n',0

sServoStatus4Btmap1:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '                            STACK POINTER-',0
sServoStatus4Btmap2:
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    '        SERVO COMMAND BITS-jihg          ACCESS TIMEOUT MSB-',0

sServoStatus5Btmap1:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '          SCRATCH BYTE? 0E-',0
sServoStatus5Btmap2:
    DC.B                                 '              SCRATCH BYTE? 0C-',0
sServoStatus5Btmap3:
    DC.B    $0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    ' STATE MACHINE FAULT STATE-',0
sServoStatus5Btmap4:
    DC.B                              '    OFFSET DAC VAL MASK IS... ',0
sServoStatus5Btmap5:
    DC.B    $0D
    DC.B    '                                 HA-2405 MUX AT U5D D0 MASK-m',$0D
    DC.B    '                                 HA-2405 MUX AT U5D D1 MASK-n',0

sServoStatus6Header:
    DC.B    $0D
    DC.B    '                  LAST COMMAND SERVO RECEIVED',$0D,0

sServoStatus7Btmap1:
    DC.B    $0D
    DC.B    '  BYTES ARE IRQ P0 P3 AND P1MASK WHICH HAVE BEEN SEEN IN',$0D
    DC.B    '  OTHER SERVO STATUS PAGES ALREADY.',$0D,0  ; LF since no pause

sServoStatus8Header:
    DC.B    $0D
    DC.B    '                  LAST COMMAND SERVO PROCESSED',$0D,0

sServoCommandBtmap1:
    DC.B    $0D
    DC.B    '                -BYTE 0 AND BYTE 1-',$0D
    DC.B    '  COMMAND-~}|{ WHICH MEANS ',0
sServoCommandBtmap2:
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
