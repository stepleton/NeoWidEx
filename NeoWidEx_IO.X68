*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: I/O subroutines.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_UI must be defined.
*-----------------------------------------------------------


* NeoWidEx disk I/O code ===================================

    ; SECTOR -- Read a sector from the hard drive into memory
    ; Args:
    ;   D1: sector to read
    ; Notes:
    ;   Tag data is loaded to zSectorTag.
    ;   Sector data is loaded to zSectorData.
    ;   Trashes registers D0-D4/A0-A3.
    ;   On failure, the carry bit is set; an error word is in D0; and a
    ;       four-byte error byte string is in D1.
SECTOR:
    MOVEA.L #zSectorTag,A1           ; Load sector tag here
    MOVEA.L #zSectorData,A2          ; Load sector data here
    MOVE.L  #kSctrTime,D2            ; Sector read timeout
    MOVEQ.L #kSctrTries,D3           ; Sector read retries
    MOVEQ.L #kSctrThresh,D4          ; Sector read threshold count
    JSR     kProRead                 ; Read the sector
    BCS.S   .er                      ; Problem? Jump ahead to print error
    RTS                              ; No problem; back to caller
.er MOVE.L  D1,-(A7)                 ; Push error bytes for printing
    MOVE.W  D0,-(A7)                 ; Push error code for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DRIVE READ ERROR -- CODE-'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<' BYTES-'>,lx,<$0D>
    ORI.B   #$1,CCR                  ; Reset carry bit to mark the error
    RTS                              ; Back to caller

    ; WIDGETCMD -- Compose a "new style" Widget command in zWIOCmd(Len)
    ; Args:
    ;   D0: Length of the command, not counting the checksum byte; only the
    ;       low-order nibble is used
    ;   A0: Buffer containing the command template string
    ; Notes:
    ;   The command template string at A0 should start with $01 or $02, and need
    ;       not include the checksum at the end. When assembling the "complete"
    ;       string at zWIOCmd, the length nibble is insterted into the first
    ;       byte, and the checksum byte is appended to the end.
    ;   The command string length (inclusive of the checksum byte) is copied to 
    ;       zWIOCmdLen, ready for use with WIDGETIO.
WIDGETCMD:
    MOVEM.L A0-A1,-(A7)              ; Save address registers used
    MOVEM.W D0-D1,-(A7)              ; Save data registers used
    ANDI.W  #$000F,D0                ; Length nibble, and also the counter
    MOVE.B  D0,zWIOCmdLen            ; Copy length to Widget command length
    ADDQ.B  #1,zWIOCmdLen            ; Add 1 to account for the checksum byte
    LEA     zWIOCmd,A1               ; Actual Widget command goes in here
    MOVE.B  (A0)+,(A1)               ; Copy command byte (first byte)
    ANDI.B  #$F0,(A1)                ; Blank out low-order nibble...
    OR.B    D0,(A1)                  ; ...and place length nibble there instead
    MOVE.B  (A1)+,D1                 ; Copy to D1 to start checksum
    SUBQ.W  #2,D0                    ; -1 D0 twice, loop-count remaining bytes
    BMI.S   .rt                      ; If D0 is now negative, no bytes remain
.lp MOVE.B  (A0),(A1)+               ; Copy current byte to buffer
    ADD.B   (A0)+,D1                 ; Add current byte to the checksum
    DBRA    D0,.lp                   ; Loop to the next byte
.rt EORI.B  #$FF,D1                  ; Compute one's complement of checksum
    MOVE.B  D1,(A1)                  ; Add checksum to the end of the command
    MOVEM.W (A7)+,D0-D1              ; Restore data registers used
    MOVEM.L (A7)+,A0-A1              ; Restore address registers used
    RTS                              ; Back to caller

    ; WIDGETIO -- General-purpose code for sending commands and data to Widget
    ; Args:
    ;   zWIOCmdLen: Length of command bytes to send
    ;   zWIOCmd: Command bytes to send
    ;   zWIOReadLen: Number of bytes to read EXCLUSIVE of status, if any
    ;   zWIOReadPtr: Where bytes read should be stored
    ;   zWIOWriteLen: Number of bytes to write, if any
    ;   zWIOWritePtr: Where bytes to write are stored
    ; Notes:
    ;   The Z bit is set iff a failure occurs, and a one-byte error code is
    ;       saved at zWIOError. (On success, zWIOError is $00.)
    ;   After successful operations, drive status bytes are saved at kStdStatus.
WIDGETIO:
    ; 0. Preliminaries
    MOVEM.L D0/D2/A0/A3,-(A7)        ; Save registers used
    m_iOff                           ; Disable interrupts
    CLR.B   zWIOError                ; No errors yet!

    ; 1. Initialise parallel I/O
    JSR     kProInit                 ; Init parallel I/O, A0; disk present?
    BEQ.S   .s2                      ; It's present; on to step 2
    MOVE.B  #kWIONoDisk,zWIOError    ; Absent; mark the error and bail
    BRA     .rt                      ; Off to the exit

    ; 2. Wait for drive to drop BSY
.s2 MOVE.L  #kSctrTime,D0            ; We'll give it around three minutes?
    BSR     _WAITONBUSY              ; Wait for BSY to deassert
    BEQ.S   .s3                      ; BSY deasserted; on to step 3
    MOVE.B  #kWIOBusy,zWIOError      ; BSY still asserted; mark error and bail
    BRA     .rt                      ; Exeunt

    ; 3. Do initial handshake
.s3 MOVE.B  #$01,D2                  ; Widget should respond with $01
    JSR     kFindD2                  ; Handshake, first attempt
    BCC.S   .s4                      ; Success, move along
    CMP.B   $85,D0                   ; Failure; did we time out?
    BNE.S   .f3                      ; No, it's a real problem
    MOVE.L  $500,D0                  ; Yes, so wait for about 10 ms
    BSR     _WAITONBUSY              ; Do the wait here
    BNE.S   .f3                      ; The drive is still busy; give up
    JSR     kFindD2                  ; Not busy; try handshake again
    BCC.S   .s4                      ; Success? Move along
.f3 MOVE.B  #kWIOHello,zWIOError     ; Failure! Mark error...
    BRA.S   .rt                      ; ...and head off to the bar

    ; 4. Send command bytes
.s4 CLR.W   D0                       ; Clear D0 word in preparation to hold...
    MOVE.B  zWIOCmdLen,D0            ; ...the length of the command to send
    LEA     zWIOCmd,A3               ; Point A3 to command bytes
    BSR     _COPYOUT                 ; Send command bytes to disk

    ; 5. Get acknowledgement handshake
    LEA     zWIOCmd,A3               ; Rewind A3 to start of command
    MOVE.B  (A3)+,D2                 ; First byte might be the instruction...
    CMPI.B  #3,D2                    ; ...if <= 2 ("Legacy" ProFile command)
    BLO.S   .c5                      ; It is, skip ahead
    MOVE.B  (A3),D2                  ; It's not; byte 2 is the instruction
.c5 ADDQ    #2,D2                    ; Expected response is instruction+2
    JSR     kFindD2                  ; Try the handshake
    BCC.S   .s6                      ; Success? Keep moving
    MOVE.B  #kWIOCmdAck,zWIOError    ; Failure! Mark error...
    BRA.S   .rt                      ; ...and move to Dallas

    ; 6. Reading or writing? If reading, skip ahead to the read
.s6 TST.W   zWIOWriteLen             ; Anything to write?
    BEQ.S   .s9                      ; No, skip ahead to read status

    ; 7. Writing, so write those bytes
    MOVE.W  zWIOWriteLen,D0          ; How much to write
    MOVE.L  zWIOWritePtr,A3          ; What to write
    BSR.B   _COPYOUT                 ; Write it

    ; 8. Get data write acknowledgement handshake
    MOVE.B  #$06,D2                  ; Expected response is $06
    JSR     kFindD2                  ; Try the handshake
    BCC.S   .s9                      ; Success? Keep moving
    MOVE.B  #kWIODataAck,zWIOError   ; Failure! Mark error...
    BRA.S   .rt                      ; ...and take up golf

    ; 9. Read status bytes
.s9 MOVE.W  #4,D0                    ; There are four status bytes
    LEA     kStdStatus,A3            ; They go in the same place the ROM uses
    BSR.B   _COPYIN                  ; Copy in status bytes

    ; A. Read any other data expected by the caller
    MOVE.W  zWIOReadLen,D0           ; How many bytes to read
    MOVE.L  zWIOReadPtr,A3           ; Where to read them to
    BSR.B   _COPYIN                  ; Read 'em in

.rt m_iOn                            ; Enable interrupts
    MOVEM.L (A7)+,D0/D2/A0/A3        ; Restore registers
    TST.B   zWIOError                ; Any errors? Set flags
    RTS                              ; Back to caller

    ; _WAITONBUSY -- WIDGETIO helper: wait for disk to deassert BSY
    ; Args:
    ;   A0: VIA 2 base address
    ;   D0: loop iterations; $1200000 is about 3 minutes?
    ; Notes:
    ;   Trashes D0.
    ;   On return, Z is true iff the drive is still asserting BSY
_WAITONBUSY:
    BTST.B  #$01,kVia2InB(A0)        ; Are we still busy?
    BNE.S   .rt                      ; No! Back to the caller
    SUBQ.L  #1,D0                    ; Yes, decrement loop counter...
    BNE.S   _WAITONBUSY              ; ...and back to top if we're still waiting
    BTST.B  #$01,kVia2InB(A0)        ; Fell out; test again so it's in the SR
.rt EORI    #$04,SR                  ; Flip Z bit so BEQ branches when not busy
    RTS                              ; Back to caller

    ; _COPYOUT -- WIDGETIO helper: copy bytes out to the drive
    ; Args:
    ;   D0: Word; number of bytes to copy out
    ;   A0: VIA 2 base address
    ;   A3: First byte of data to copy out
    ; Notes:
    ;   Trashes D0/A3.
_COPYOUT:
    ANDI.B  #$F7,kVia2OutB(A0)       ; Set RDWR signal to out
    MOVE.B  #$FF,kVia2DirA(A0)       ; All 8 data line directions are outbound
    SUBQ.W  #1,D0                    ; Decrement D0 to make it a loop counter
    BMI.S   .rt                      ; D0 was <= 0, so copy no bytes
.lp MOVE.B  (A3)+,kVia2OutA(A0)      ; Write a byte to the drive
    DBRA    D0,.lp                   ; Loop to next byte
    ORI.B   #$08,kVia2OutB(A0)       ; Set RDWR signal to in
    MOVE.B  #$00,kVia2DirA(A0)       ; All 8 data line directions are inbound
.rt RTS                              ; Back to caller

    ; _COPYIN -- WIDGETIO helper: copy bytes in from the drive
    ; Args:
    ;   D0: Word; number of bytes to copy in
    ;   A0: VIA 2 base address
    ;   A3: Where to copy the bytes
    ; Notes:
    ;   Trashes D0/A3
_COPYIN:
    SUBQ.W  #1,D0                    ; Decrement D0 to make it a loop counter
    BMI.S   .rt                      ; D0 was <= 0, so copy no bytes
.lp MOVE.B  kVia2InA(A0),(A3)+       ; Read next byte from the drive
    DBRA    D0,.lp                   ; Loop to next byte
.rt RTS                              ; Back to the caller

    ; WIDGETPERROR -- Print text describing the error encountered by WIDGETIO
    ; Args:
    ;   (none) (uses zWIOError)
    ; Notes:
    ;   Error text is preceded (but not followed) by an endl.
WIDGETPERROR:
    MOVEM.L A0/D0,-(A7)              ; Save used registers to stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl  ; Preceding all subsequent output
    MOVE.B  zWIOError,D0             ; Copy error to D0
    BEQ.S   .ok                      ; Wait, there's no error, declare victory!
    LEA     sWIOErrStrings,A0        ; Point A0 to the first error string
.ol TST.B   (A0)                     ; Out of error strings?
    BEQ.S   .ue                      ; Skip ahead to print "unknown error"
    CMP.B   (A0)+,D0                 ; Is this string for our error code?
    BEQ     .ke                      ; It is, so skip ahead to print it
.il TST.B   (A0)+                    ; It's not, so find the next string
    BNE.S   .il                      ; Not at the end yet; keep scanning
    BRA.S   .ol                      ; At the next string, start from the top

.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<'OPERATION SUCCESSFUL.'>
    BRA     .rt                      ; Skip ahead to return to caller
.ue MOVE.B  zWIOError,-(A7)          ; Unusual error code on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'AN UNKNOWN ERROR WITH CODE '>,hhx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' OCCURRED.'>
    BRA.S   .rt                      ; Skip ahead to return to caller
.ke MOVE.L  A0,-(A7)                 ; Error string address on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s

.rt MOVEM.L (A7)+,A0/D0              ; Restore used registers from stack
    RTS                              ; Back to the caller


    PAGE
* NeoWidEx disk I/O scratch data allocation ================
    SECTION kSecScratch

zWIOError:
    DC.B    $FF                      ; Error from last WIDGETIO command
zWIOCmdLen:
    DC.B    $FF                      ; Length of command
zWIOCmd:
    DCB.B   12,'c'                   ; Space for command bytes
zWIOReadLen:
    DC.W    $FFFF                    ; # of bytes to read, EXCLUSIVE of status
zWIOReadPtr:
    DC.L    $FFFFFFFF                ; Pointer to buffer for bytes read
zWIOWriteLen:
    DC.W    $FFFF                    ; # of bytes to write
zWIOWritePtr:
    DC.L    $FFFFFFFF                ; Pointer to buffer of bytes to write


    PAGE
* NeoWidEx disk I/O strings =================================
    SECTION kSecStrings

sWIOErrStrings:
    DC.B    kWIONoDisk,'THERE APPEARS TO BE NO DRIVE CONNECTED TO THIS LISA.',0
    DC.B    kWIOBusy,'GAVE UP WAITING FOR THE DRIVE TO BE READY.',0
    DC.B    kWIOHello,'THE INITIAL HANDSHAKE WITH THE DRIVE FAILED.',0
    DC.B    kWIOCmdAck,'THE POST-COMMAND HANDSHAKE WITH THE DRIVE FAILED.',0
    DC.B    kWIODataAck,'THE POST-WRITE HANDSHAKE WITH THE DRIVE FAILED.',0
    DC.B    0                        ; Error string null-terminator


** (Back to the code section) **
    SECTION kSecCode



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
