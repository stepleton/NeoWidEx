*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Read_Controller_Status
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: print full controller status.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Read_Controller_Status code =====================

    ; CMD_Read_Ctrlr_Status -- print ALL the controller statuses
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0-A1.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Read_Ctrlr_Status:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail

    ; First, retrieve and print all controller status longs
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- ALL STATUS LONGS ---'>
    BSR     _READALLCTRLRSTATUS      ; Retrieve all controller status longs
    
    MOVE.B  #$00,D0                  ; We will print statuses in forward order
    MOVEA.L #zStatus0,A0             ; A0 points to current status storage entry
    MOVEA.L #dStatusDescTable,A1     ; A1 points to current desc table entry
.lp MOVE.L  (A1)+,-(A7)              ; Desc table pointer to stack for printing
    MOVE.L  (A0)+,-(A7)              ; Status table entry to stack for printing
    MOVE.B  D0,-(A7)                 ; Status type byte to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,hhx,<'- '>,lx,<'  '>,s
    ADDQ.B  #1,D0                    ; Get ready to print next status
    CMPI.B  #$08,D0                  ; Or have we run out?
    BLT     .lp                      ; We haven't; back to print next status
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Next, print standard status using an existing subroutine.
    BSR     STATUSPRINT              ; Assumes it's loaded into kStdStatus
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print seek and head position information.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- LAST ADDRESS INFO ---'>
    MOVE.L  zStatus1,-(A7)           ; Prepare to print last logical block
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'LAST LOGICAL BLOCK-'>,3x
    MOVE.B  (zStatus2+3),-(A7)       ; Prepare to print sector of last seek
    MOVE.B  (zStatus2+2),-(A7)       ; Prepare to print head of last seek
    MOVE.W  zStatus2,-(A7)           ; Prepare to print cylinder of last seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,' CURRENT SEEK ADDRESS CYLINDER-'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' HEAD-'>,hhx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SECTOR-'>,hhx
    MOVE.B  (zStatus7+3),-(A7)       ; Prepare to print sector of last seek
    MOVE.B  (zStatus7+2),-(A7)       ; Prepare to print head of last seek
    MOVE.W  zStatus7,-(A7)           ; Prepare to print cylinder of last seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'PREVIOUS SEEK ADDRESS CYLINDER-'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' HEAD-'>,hhx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SECTOR-'>,hhx
    MOVE.W  zStatus3,-(A7)           ; Prepare to print current cylinder
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'          HEAD NOW ON CYLINDER-'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print Widget internal status bitmap with explanatory text.
    ;mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- LAST INTERNAL STATUS ---'>
    MOVEA.L #sStatusDesc4,A0
    MOVE.L  zStatus4,D0
    BSR     .ph
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sInternalStatusBitmap,zStatus4
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print Widget state registers bitmap with explanatory text.
    MOVEA.L #sStatusDesc5,A0
    MOVE.L  zStatus5,D0
    BSR     .ph
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sStateRegistersBitmap,zStatus5
    MOVE.B  (zStatus5+3),-(A7)       ; Last status byte to stack for printing...
    ANDI.B  #$07,(A7)                ; ...but first mask state machine state
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,qpendl

    ; Printe Widget exception registers bitmap with explanatory text.
    MOVEA.L #sStatusDesc6,A0
    MOVE.L  zStatus6,D0
    BSR     .ph
    ; Print first part of exeption registers bitmap.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sExp1RegistersBitmap,zStatus6
    MOVE.B  (zStatus6+1),-(A7)       ; 2nd status byte to stack for printing...
    ANDI.B  #$0F,(A7)                ; ...but first mask bad read retry count
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx
    ; Print second part of exeption registers bitmap.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sExp2RegistersBitmap,zStatus6
    MOVE.B  (zStatus6+3),-(A7)       ; Last status byte to stack for printing...
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx

    RTS                              ; Back to caller

    ; .ph -- CMD_Read_Ctrlr_Status helper: print title and raw hex bytes
    ; Args:
    ;   A0: address of bitmap display title string
    ;   D0: long whose hex bytes will be printed below the title
    ; Notes:
    ;   Prints the title and hex dump of status long that shows above certain
    ;       status bitmaps.
.ph MOVE.L  A0,-(A7)                 ; Title to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- '>,s,<' ---'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'                          '>
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


    ; _READALLCTRLRSTATUS -- Reads all 8 controller status longs to zStatusX
    ; Args:
    ;   (none)
    ; Notes:
    ;   Leaves Widget standard status in kStdStatus.
_READALLCTRLRSTATUS:
    MOVEM.L A0-A1,-(A7)              ; Save address registers used to stack
    MOVE.W  D0,-(A7)                 ; Save data register used to stack
    MOVE.B  #$07,D0                  ; We will load statuses in reverse order
    MOVEA.L #(zStatus0+8*4),A0       ; A0 points above curr status storage entry
    MOVEA.L #(dStatusDescTable+7*4),A1   ; A1 points to current desc table entry
.lp MOVE.B  D0,(zStatusCmd+2)        ; Specify Read_Controller_Status subcommand
    BSR     .wi                      ; Execute Read_Controller_Status command
    BEQ     .nx                      ; Read successful, finish up and move along
    MOVE.L  (A1),-(A7)               ; Read failed; desc table pointer to stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO RETRIEVE '>,s
    BSR     WIDGETPERROR             ; Print disk error string
.nx MOVE.L  kStdStatus,-(A0)         ; Copy read status to status storage table
    SUBQ.L  #4,A1                    ; Nove A1 to next desc table entry
    SUBQ.B  #1,D0                    ; Next status command into D0
    BPL     .lp                      ; Repeat loop while status subcommand >= 0
    MOVE.W  (A7)+,D0                 ; Restore data register used from stack
    MOVEM.L (A7)+,A0-A1              ; Restore address registers used from stack
    RTS                              ; Back to caller

    ; Tiny subroutine that _READALLCONTROLLERSTATUS uses to send the command
    ; at zStatusCmd to the Widget. No data is read or written; only the
    ; four status bytes are recovered (and stored at kStdStatus as usual).
.wi MOVEM.L D0/A0,-(A7)              ; Save registers used to stack
    MOVE.B  #3,D0                    ; All ...Status commands are 3 bytes long
    LEA     zStatusCmd,A0            ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue Widget command
    MOVEM.L (A7)+,D0/A0              ; Restore registers used
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Read_Controller_Status numerical data ===========
    SECTION kSecData

    ; Table of controller status description strings.
    DS.L    0                        ; Align to longs
dStatusDescTable:
    DC.L    sStatusDesc0
    DC.L    sStatusDesc1
    DC.L    sStatusDesc2
    DC.L    sStatusDesc3
    DC.L    sStatusDesc4
    DC.L    sStatusDesc5
    DC.L    sStatusDesc6
    DC.L    sStatusDesc7

    PAGE
* NeoWidEx Read_Controller_Status scratch data allocation ==
    SECTION kSecScratch

zStatusCmd:
    DC.B    $10,$01,$00              ; Command; last byte is alterable
    DS.W    0                        ; Force even alignment for following data

zStatus0:                            ; These slots will hold all eight Widget...
    DC.B    '[Wid'                   ; ...controller status responses, but...
zStatus1:                            ; ...we initialise them with text to...
    DC.B    'get '                   ; ...make their use obvious to debuggers
zStatus2:
    DC.B    'stat'
zStatus3:
    DC.B    'us w'
zStatus4:
    DC.B    'ill '
zStatus5:
    DC.B    'be p'
zStatus6:
    DC.B    'ut h'
zStatus7:
    DC.B    'ere]'


    PAGE
* NeoWidEx Read_Controller_Status strings ==================
    SECTION kSecStrings

sStatusDesc0:
    DC.B    'STANDARD STATUS',0
sStatusDesc1:
    DC.B    'LAST LOGICAL BLOCK',0
sStatusDesc2:
    DC.B    'CURRENT SEEK ADDRESS',0
sStatusDesc3:
    DC.B    'CURRENT CYLINDER',0
sStatusDesc4:
    DC.B    'INTERNAL STATUS',0
sStatusDesc5:
    DC.B    'STATE REGISTERS',0
sStatusDesc6:
    DC.B    'EXCEPTION REGISTERS',0
sStatusDesc7:
    DC.B    'LAST SEEK ADDRESS',0

sInternalStatusBitmap:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '      RECOVERY MODE ACTIVE-~       HEADS ON THE RIGHT TRACK-v',$0D
    DC.B    '   SPARE TABLE ALMOST FULL-}        READ HEADER AFTER RECAL-u',$0D
    DC.B    'BUFFER STRUCT CONTAMINATED-|       CURRENT OP IS A WRITE OP-t',$0D
    DC.B    ' POWER RESET JUST OCCURRED-{               HEADS ARE PARKED-s',$0D
    DC.B    '   NONZERO STANDARD STATUS-z   SEQUENTIAL LB LOOKAHD SEARCH-r',$0D
    DC.B    '        CONTROLLER LED LIT-w    LAST COMMAND WAS MULTIBLOCK-q',$0D
    DC.B    '                                              SEEK COMPLETE-p',$0D
    DC.B    '                -BYTE 2-                SERVO OFFSET ACTIVE-o',$0D
    DC.B    '         SEEK WAS REQUIRED-n',$0D
    DC.B    '  HEAD CHANGE WAS REQUIRED-m',$0D
    DC.B    '      CURRENT BLOCK IS BAD-h           -BYTE 3 IS UNUSED-',$0D
    DC.B    '    CURRENT BLOCK IS SPARE-g',0

sStateRegistersBitmap:
    DC.B    $0D
    DC.B    '                                                 -BYTE 1-',$0D
    DC.B    '                                                RAM FAILURE-v',$0D
    DC.B    '                                              EPROM FAILURE-u',$0D
    DC.B    '                                         DISK SPEED FAILURE-t',$0D
    DC.B    '      -BYTE 0 IS UNUSED-                      SERVO FAILURE-s',$0D
    DC.B    '                                       SECTOR COUNT FAILURE-r',$0D
    DC.B    '                                      STATE MACHINE FAILURE-q',$0D
    DC.B    '                                         READ-WRITE FAILURE-p',$0D
    DC.B    '                                       NO SPARE TABLE FOUND-o',$0D
    DC.B    '                -BYTE 2-',$0D
    DC.B    '    DISK RD-WR DIR IS READ-n                     -BYTE 3-',$0D
    DC.B    'SERVO CAN ACCEPT A COMMAND-m          NO CRC ERROR DETECTED-f',$0D
    DC.B    '            MSEL1-l  MSEL2-k            NOT WRITE-NOT-VALID-e',$0D
    DC.B    '              BSY-j    CMD-i                    SERVO READY-d',$0D
    DC.B    '     NO ECC ERROR DETECTED-h                    SERVO ERROR-c',$0D
    DC.B    '  STATE MACHINE IS RUNNING-g            STATE MACHINE STATE-',0

sExp1RegistersBitmap:
    DC.B    $0D
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    '   READ ERROR ON LAST READ-~',$0D
    DC.B    '  SERVO ERROR WHEN READING-}         ECC CIRCUIT SAYS ERROR-v',$0D
    DC.B    '  ANY OK READ ON LAST READ-|         CRC CIRCUIT SAYS ERROR-u',$0D
    DC.B    '    NO HEADER ON LAST READ-{                 HEADER TIMEOUT-t',$0D
    DC.B    'CRC/ECC ERROR ON LAST READ-z       BAD RETRIES ON LAST READ-',0

sExp2RegistersBitmap:
    DC.B    $0D,$0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    ' WRITE ERROR ON LAST WRITE-n',$0D
    DC.B    ' SERVO ERROR ON LAST WRITE-m',$0D
    DC.B    'ANY OK WRITE ON LAST WRITE-l',$0D
    DC.B    '   NO HEADER ON LAST WRITE-k      BAD RETRIES ON LAST WRITE-',0


** (Back to the code section) **
    SECTION kSecCode



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
