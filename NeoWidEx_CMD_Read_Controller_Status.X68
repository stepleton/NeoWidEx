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

    ; CMD_Read_Controller_Status -- print ALL the statuses
    ; Args:
    ;   (none)
    ; Notes:
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Read_Controller_Status:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail

    ; First, print standard status using an existing subroutine.
    BSR     STATUSPRINT              ; Assumes it's loaded into kStdStatus
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; The pager (cf `qpendl`) will allow the user to abort this routine after
    ; each of the status commands, but before the user leaves this subroutine,
    ; we need to be certain that the standard status is restored to kStdStatus
    ; (since the Widget interactions that follow will fill it with...
    ; nonstandard statuses). To ensure that this restoration occurs even when
    ; the user aborts the paging, we push the address of the restoration
    ; routine onto the stack, so `qpendl` will jump there.
    MOVE.L  #.ss,-(A7)               ; Return pointer refers to status restore

    ; Print seek and head position information.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- LAST ADDRESS INFO ---'>
    MOVE.B  #$01,(zStatusCmd+2)      ; Subcommand: get last logical block
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    MOVE.L  kStdStatus,-(A7)         ; Prepare to print last logical block
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<'LAST LOGICAL BLOCK-'>,3x
    MOVE.B  #$02,(zStatusCmd+2)      ; Subcommand: get current seek address
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    MOVE.W  kStdStatus,-(A7)         ; Prepare to print cylinder of last seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<'LAST SEEK TO CYLINDER-'>,hx
    MOVE.B  (kStdStatus+2),-(A7)     ; Prepare to print head of last seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' HEAD-'>,hhx
    MOVE.B  (kStdStatus+2),-(A7)     ; Prepare to print sector of last seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SECTOR-'>,hhx
    MOVE.B  #$03,(zStatusCmd+2)      ; Subcommand: get current head position
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    MOVE.W  kStdStatus,-(A7)         ; Prepare to print current cylinder
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<' HEAD NOW ON CYLINDER-'>,hx
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print Widget internal status information.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- LAST INTERNAL STATUS ---'>
    MOVE.B  #$04,(zStatusCmd+2)      ; Subcommand: get internal status
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print internal status bitmap with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sInternalStatusBitmap,kStdStatus
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    ; Print Widget state registers
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- STATE REGISTERS ---'>
    MOVE.B  #$05,(zStatusCmd+2)      ; Subcommand: get state registers
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print state registers bitmap with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sStateRegistersBitmap,kStdStatus
    MOVE.B  (kStdStatus+3),-(A7)     ; Last status byte to stack for printing...
    ANDI.B  #$07,(A7)                ; ...but first mask state machine state
    MOVE.B  #1,zLineCount            ; Force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,qpendl

    ; Printe Widget exception registers
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- EXCEPTION REGISTERS ---'>
    MOVE.B  #$06,(zStatusCmd+2)      ; Subcommand: get state registers
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .er                      ; Error? Jump ahead to print and exit
    BSR     .pw                      ; Print raw status bytes
    ; Print first part of exeption registers bitmap with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sExp1RegistersBitmap,kStdStatus
    MOVE.B  (kStdStatus+1),-(A7)     ; 2nd status byte to stack for printing...
    ANDI.B  #$0F,(A7)                ; ...but first mask bad read retry count
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx
    ; Print second part of exeption registers bitmap with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sExp2RegistersBitmap,kStdStatus
    MOVE.B  (kStdStatus+3),-(A7)     ; Last status byte to stack for printing...
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,endl

    ; We've reached the end of the subroutine "organically" without the user
    ; aborting paging. Pop the status restoration code address off the stack.
    ADDQ.L  #4,A7                    ; Pop .ss address off the stack

    ; Reload standard status into kStdStatus so that subsequent calls to
    ; STATUSPRINT actually print the standard status and not something weird.
.ss MOVE.B  #$00,(zStatusCmd+2)      ; Subcommand: get standard status
    BSR     .wi                      ; Execute Widget status retrieval command
    BNE     .es                      ; Error? Jump to print header and exit
    RTS                              ; No error, return to caller at last
.es mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'WHILE RESTORING STANDARD STATUS'>

.er mPrint  kCrtRow,kCrtCol,#kFirstCol,endl
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller, (often via .ss)

    ; Tiny subroutine that CMD_Read_Controller_Status uses to print the four
    ; status bytes read from the Widget.
.pw mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<'                          '>
    MOVE.B  (kStdStatus+3),-(A7)     ; Fourth status byte to stack for printing
    MOVE.B  (kStdStatus+2),-(A7)     ; Third status byte
    MOVE.B  (kStdStatus+1),-(A7)     ; Second status byte
    MOVE.B  (kStdStatus+0),-(A7)     ; First status byte; now print them all
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<' '>,hhx,<' '>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<' '>,hhx,endl
    RTS                              ; Back to caller

    ; Tiny subroutine that CMD_Read_Controller_Status uses to send the command
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
* NeoWidEx Read_Controller_Status scratch data =============
    SECTION kSecScratch

zStatusCmd:
    DC.B    $10,$01,$00              ; Command; last byte is alterable
    DS.W    0                        ; Force even alignment for following data


    PAGE
* NeoWidEx Read_Controller_Status strings ==================
    SECTION kSecStrings
sInternalStatusBitmap:
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
    DC.B    '            MSEL1-l  MSEL2-k                WRITE NOT VALID-e',$0D
    DC.B    '              BSY-j    CMD-i                    SERVO READY-d',$0D
    DC.B    '     NO ECC ERROR DETECTED-h                    SERVO ERROR-c',$0D
    DC.B    '  STATE MACHINE IS RUNNING-g            STATE MACHINE STATE-',0

sExp1RegistersBitmap:
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
