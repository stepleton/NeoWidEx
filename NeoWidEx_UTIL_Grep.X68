*-----------------------------------------------------------
* Title      : NeoWidEx_UTIL_Grep
* Written by : Tom Stepleton
* Date       : XX January 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Scan sectors and blocks for hex sequences.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Send_Seek must be defined.
*-----------------------------------------------------------


* NeoWidEx Grep code =======================================

    ; UTIL_Grep_Sectors -- Scan successive sectors for hex sequences.
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
UTIL_Grep_Sectors:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- GREP SECTORS ---'>
    BSR     _UGrep_FORM              ; Get the search pattern from the user
    BEQ     .qt                      ; Did the user cancel? Quit now

    ; Seek to a designated starting point for the search
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'ALMOST READY -- WHERE TO BEGIN?'>
    BSR     CMD_Send_Seek_nobanner   ; Ask user to seek somewhere
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .rt                      ; Yes, back to caller

    ; Setup before we begin our search
    BSR     _UGrepSec_STATUSSEEK     ; Try to get our initial seek address
    BNE     .er                      ; Giving up on error
    MOVE.L  kStdStatus,D1            ; Whole current seek address to D1
    SWAP    D1                       ; Cylinder portion to LSWord
    CMP.W   zCylinders,D1            ; Compare to number of cylinders
    BLO.S   .ss                      ; If smaller, continue
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'CYLINDER TOO HIGH -- HEAD PARKED?'>
    BEQ     .qt                      ; Otherwise, give up
.ss SWAP    D1                       ; Restore original seek address ordering
    MOVE.L  D1,z_UGrepStartPos       ; Save initial seek address in start pos
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SEARCHING...',$0D>  ; Note newline
    mResetP                          ; Reset paging

    ; MAIN LOOP at last. Throughout the loop, D1 will contain the current CHS
    ; address. Other registers are free. We start by loading the sector.
.lp MOVE.B  D1,-(A7)                 ;   Current sector onto stack to print
    ROR.L   #8,D1                    ;   Rotate head into LSByte
    MOVE.B  D1,-(A7)                 ;   Current head onto stack to print
    ROR.L   #8,D1                    ;   Rotate cylinder into LSWord
    MOVE.W  D1,-(A7)                 ;   Current cylinder onto stack to print
    SWAP    D1                       ;   Restore original seek address ordering
    MOVE.W  #kFirstCol,kCrtCol       ;   Rewind cursor to start of line
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  CYL-'>,hx,<' HEAD-'>,hhx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SECTOR-'>,hhx
    BSR     _UGrepSec_SENDSEEK       ;   Attempt to seek to this location
    BEQ.S   .rd                      ;   Success? On to reading
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' -- SEEK ERROR.'>  ; Failure!
    BRA     .er                      ;   Bail instead
.rd BSR     _UGrepSec_DIAGREAD       ;   Attempt to read at this location
    BEQ.S   .gr                      ;   Success? On to grepping
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' -- READ ERROR.'>  ; Failure!
    BRA     .er                      ;   Now bail

    ; Sector loaded, we scan for a match to our search string.
.gr BSR     _UGrep_GREP              ;   Scan for a match
    BNE.S   .nx                      ;   No match? Advance to next sector
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' -- PATTERN FOUND'>,qpendl

    ; Compute the address of the next sector.
.nx BSR     _UGrepSec_NEXTSECTOR     ;   Increment the sector in D1
    CMP.L   z_UGrepStartPos,D1       ;   Are we back at the beginning?
    BEQ.S   .dn                      ;   Yes, jump out to the exit.
    JSR     QUITPOLL                 ;   No, but did the user press the 'q' key?
    BEQ.S   .qt                      ;   If so, jump ahead to exit
    BRA     .lp                      ;   Otherwise, search on in the new sector

.dn MOVE.W  #kFirstCol,kCrtCol       ;   Rewind cursor to start of line
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DONE.                       '>
.rt RTS                              ; Back to caller

.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

.er BSR     WIDGETPERROR             ; Error! Print error message
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SEE FULL STATUS FOR DETAILS.'>
    RTS

    ; UTIL_Grep_Blocks -- Scan successive blocks for hex sequences.
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
UTIL_Grep_Blocks:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if it hasn't been run yet
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- GREP BLOCKS ---'>
    BSR     _UGrep_FORM              ; Get the search pattern from the user
    BEQ     .qt                      ; Did the user cancel? Quit now

    ; Ask user for initial block to start the search
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'ALMOST READY -- WHERE TO BEGIN?'>
    MOVE.L  zNumBlocks,D0            ; The upper bound for the block...
    SUBQ.L  #1,D0                    ; ...is zNumBlocks-1
    MOVE.L  D0,z_UGrepBloFormBounds  ; Save in bounds array
    LEA     s_UGrepBloForm,A0        ; Prepare FORM args; address of template...
    LEA     s_UGrepBloFormPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UGrepBloFormInitVals,A2  ; ...address of initial values array...
    LEA     z_UGrepBloFormBounds,A3  ; ...and address of bounds array
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .rt                      ; Yes, jump ahead to quit

    ; Setup before we begin our search
    MOVE.L  zFieldValues,D1          ; Starting block into D1
    MOVE.L  D1,z_UGrepStartPos       ; Save initial seek address in start pos
    MOVE.L  D1,z_UGrepBloFormInitVals  ; And also to initial field values
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SEARCHING...',$0D>  ; Note newline
    mResetP                          ; Reset paging

    ; MAIN LOOP at last. Throughout the loop, D1 will contain the current block.
    ; Other registers are free. We start by loading the block.
.lp MOVE.L  D1,-(A7)                 ;   Current block onto stack to print
    MOVE.W  #kFirstCol,kCrtCol       ;   Rewind cursor to start of line
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  BLOCK-'>,3x
    BSR     _UGrepBlo_PROREAD        ;   Attempt to read this block
    BEQ.S   .gr                      ;   Success? On to grepping
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' -- READ ERROR.'>  ; Failure!
    BSR     WINFOSTATUSCHECK         ;   Force info refresh if spares changed
    BRA     .er                      ;   Now bail

    ; Block loaded, we scan for a match to our search string.
.gr BSR     _UGrep_GREP              ;   Scan for a match
    BNE.S   .nx                      ;   No match? Advance to next sector
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' -- PATTERN FOUND'>,qpendl

    ; Compute the address of the next block.
.nx ADDQ.L  #1,D1                    ;   Simple as counting upward
    CMP.L   zNumBlocks,D1            ;   But have we hit disk capacity?
    BLO.S   .iv                      ;   No, proceed
    CLR.L   D1                       ;   Yes, loop around to the first block
.iv MOVE.L  D1,z_UGrepBloFormInitVals  ; Copy new block to initial field values
    JSR     QUITPOLL                 ;   Did the user press the 'q' key?
    BEQ.S   .qt                      ;   If so, jump ahead to exit
    CMP.L   z_UGrepStartPos,D1       ;   Are we back at the start of the search?
    BNE     .lp                      ;   No, continue search in the new block

.dn MOVE.W  #kFirstCol,kCrtCol       ;   Rewind cursor to start of line
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DONE.         '>
.rt RTS                              ; Back to caller

.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Ack user quit
    RTS                              ; Back to caller

.er BSR     WIDGETPERROR             ; Error! Print error message
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SEE FULL STATUS FOR DETAILS.'>
    RTS

    ; _UGrep_GREP -- UTIL_Grep_* helper: look for search pattern in data buffer
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/D2/A0-A3.
    ;   This algorithm is naive and slow, but simple.
    ;   On return, the Z bit is set iff the pattern appears in the data buffer.
_UGrep_GREP:
    LEA     zSectorTag,A0            ; The search starts here...
    MOVEA.L A0,A1                    ; ...and it continues through both the...
    ADDA.W  zBlockSize,A1            ; ...tag and the data area, but only...
    CLR.W   D0                       ; ...up to the last position where the...
    MOVE.B  z_UGrepPatternLen,D0     ; ...pattern could fit, and now A1...
    SUBA.W  D0,A1                    ; ...points just there (inclusive bound)
    MOVE.B  z_UGrepPattern,D0        ; Copy first byte of pattern into D0

.gl CMP.B   (A0)+,D0                 ;   Current byte matches first pat. byte?
    BNE.S   .gn                      ;   No, skip ahead to next byte

    MOVEA.L A0,A2                    ;   Yes; prepare to compare remaining...
    MOVEA.L #(1+z_UGrepPattern),A3   ;   ...bytes of the pattern
    MOVE.B  z_UGrepPatternLen,D2     ;   Of which there are this many
    SUBQ.B  #1,D2                    ;   (And we've already consumed one)
    BEQ.S   .rt                      ;   Was that all? Back to caller with Z set
.gm CMPM.B  (A2)+,(A3)+              ;     Does the next byte match?
    BNE.S   .gn                      ;     Nope! Continue scanning from byte 0
    SUBQ.B  #1,D2                    ;     Yes, one fewer byte remaining
    BEQ.S   .rt                      ;     Pattern done! Return with Z set
    BRA.S   .gm                      ;     On to the next pattern byte

.gn CMPA.L  A1,A0                    ;   Have we reached the buffer's end?
    BLS.S   .gl                      ;   No, around to the next byte
    ANDI.B  #$FB,CCR                 ; Yes, clear zero bit to mark "no match"

.rt RTS                              ; Back to caller

    ; _UGrep_FORM -- UTIL_Grep_* helper: get search pattern from user
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   User-specified pattern winds up in z_UGrepPattern, with pattern length
    ;       in z_UGrepPatternLen.
    ;   Test the Z flag (or check for a zero value in zFormIntent) to see if the
    ;       user typed 'q' instead of completing a form.
_UGrep_FORM:
    ; First we ask the user for the pattern length
    LEA     s_UGrepFormLen,A0        ; Prepare FORM args; address of template...
    LEA     s_UGrepFormLenPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UGrepFormLenInitVals,A2  ; ...addr of initial values array...
    LEA     d_UGrepSecFormLenBounds,A3   ; ...and you can't have >16 bytes
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .rt                      ; Yes, jump ahead to quit
    MOVE.B  (3+zFieldValues),D0      ; No, copy user's choice to D0
    BEQ     .zr                      ; But quit if it's 0
    MOVE.B  D0,z_UGrepPatternLen     ; If not, copy it to the pattern size

    ; We now customise the pattern entry form to match the pattern size
    LEA     z_UGrepSecFormPatFields,A0   ; A0 points to the form's fields
    MOVE.B  #'a',0(A0)               ; Restore the form's field names: first...
    MOVE.B  #'b',8(A0)               ; ...second...
    MOVE.B  #'c',16(A0)              ; ...third...
    MOVE.B  #'d',D1                  ; ...(cache 'd' since we use it a lot)...
    MOVE.B  D1,24(A0)                ; ...fourth
    MOVE.B  D1,1(A0)                 ; Restore the form's field sizes: first...
    MOVE.B  D1,9(A0)                 ; ...second...
    MOVE.B  D1,17(A0)                ; ...third...
    MOVE.B  D1,25(A0)                ; ...fourth...
    MOVE.B  D0,D1                    ; Copy pattern length to D1 for scratch use
    MOVEA.L A0,A1                    ; Copy form fields start to A1 for same
    SUBQ.L  #7,A1                    ; Pull A1 back to first field size minus 8
.fl ADDQ.L  #8,A1                    ;   Advance to the next field size byte
    CMPI.B  #4,D1                    ;   Field still has >4 bytes left to go?
    BLS.S   .fa                      ;   No! Jump out and adjust field size
    SUBQ.B  #4,D1                    ;   Yes, shrink D1 by four bytes...
    BRA.S   .fl                      ;   ...and around to the next field
.fa SUBQ.B  #4,D1                    ; Compute change to this field size byte
    ADD.B   D1,(A1)                  ; Apply change to this field size byte
    MOVE.B  D0,D1                    ; Now restore field size in D1
    LSL.B   #1,D1                    ; Multiply it by 2...
    EXT.W   D1                       ; ...extend to word...
    LEA     0(A0,D1.W),A1            ; ...and point A1 past form's last byte
    SUB.B   #32,D1                   ; Subtract 32 from D1
    BEQ.S   .iv                      ; Already 0? Jump ahead; make initial vals
.fb MOVE.B  #' ',(A1)+               ;   Put a blank space in the form; advance
    ADDQ.B  #1,D1                    ;   Increment D1...
    BLT.S   .fb                      ;   ...and continue until D1 >= 0

    ; Prepare form initial values from the saved pattern. The saved pattern is
    ; a contiguous string of bytes, but the form deals in longs, so the last
    ; mod(length, 4) bytes of the need to be shifted rightward in the initial
    ; values so that they show up in the expected locations as the user edits.
.iv MOVE.B  D0,D1                    ; Restore pattern length in D1
    LEA     z_UGrepPattern,A0        ; Point A0 at top of existing pattern
    LEA     z_UGrepFormPatInitVals,A1  ; Point A1 at top of initial values
.il MOVE.L  (A0)+,(A1)               ;   Copy next pattern long to initial vals
    CMPI.B  #4,D1                    ;   Pattern still has >4 bytes left to go?
    BLS.S   .ia                      ;   No! Jump out and shift this long
    SUBQ.B  #4,D1                    ;   Yes, shrink D1 by four bytes...
    ADDQ.L  #4,A1                    ;   ...advance A1 to the next long...
    BRA.S   .il                      ;   ...and around to copy the next long
.ia SUBQ.B  #4,D1                    ; Now -D1 counts the bytes to shift right
    BEQ.S   .fm                      ; (Already 0? Jump ahead to the form)
    NEG.B   D1                       ; Now it's D1
    LSL.B   #3,D1                    ; Now D1 counts the *bits* to shift right
    MOVE.L  (A1),D2                  ; We have to shift in a register, so D2
    LSR.L   D1,D2                    ; Shift D2 right as directed
    MOVE.L  D2,(A1)                  ; And place the result back in RAM

    ; Now we can ask user for the pattern
.fm LEA     z_UGrepFormPat,A0        ; Set FORM args; address of template...
    LEA     s_UGrepFormPatPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UGrepFormPatInitVals,A2  ; ...addr of initial values array...
    SUBA.L  A3,A3                    ; ...and search patterns are unbounded
    ; Copy user options into defaults
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .rt                      ; Yes, jump ahead to quit
    mMemCpy #zFieldValues,#z_UGrepPattern,#16  ; No, copy user's pattern

    ; Now we copy results from the user back to the saved pattern. This is
    ; essentially the opposite of the preparation of the initial values we did
    ; earlier, reversing the rightward shift for "dangling" bytes. We start by
    ; blanking out the saved pattern so that if the user later wants to use a
    ; new pattern that's bigger than the current one, the new bytes are all 0s.
    mMemSet #0,#z_UGrepPattern,#16   ; Here are all those 0s
    MOVE.B  z_UGrepPatternLen,D1     ; Restore pattern length in D1
    LEA     zFieldValues,A0          ; Point 0 at top of field values
    LEA     z_UGrepPattern,A1        ; Point A1 at top of the pattern
.pl MOVE.L  (A0)+,(A1)               ;   Copy next pattern long to initial vals
    CMPI.B  #4,D1                    ;   Pattern still has >4 bytes left to go?
    BLS.S   .pa                      ;   No! Jump out and shift this long
    SUBQ.B  #4,D1                    ;   Yes, shrink D1 by four bytes...
    ADDQ.L  #4,A1                    ;   ...advance A1 to the next long...
    BRA.S   .pl                      ;   ...and around to copy the next long
.pa SUBQ.B  #4,D1                    ; Now -D1 counts the bytes to shift left
    BEQ.S   .cl                      ; (Already 0? Jump ahead to length copy)
    NEG.B   D1                       ; Now it's D1
    LSL.B   #3,D1                    ; Now D1 counts the *bits* to shift left
    MOVE.L  (A1),D2                  ; We have to shift in a register, so D2
    LSL.L   D1,D2                    ; Shift D2 left as directed
    MOVE.L  D2,(A1)                  ; And place the result back in RAM

    ; The above copy commits the user's inputs to be the defaults for the next
    ; time the user uses this form, so we may as well copy the user's selected
    ; length to the form length initial values as well. This will also clear the
    ; Z flag for the return (since the length can't be 0).
.cl MOVE.B  z_UGrepPatternLen,(3+z_UGrepFormLenInitVals)

.rt RTS                              ; Back to caller

.zr mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'LENGTH MUST BE NONZERO.'>
    CLR.B   zFormIntent              ; Mark user as wanting to cancel
    RTS                              ; Back to caller

    ; _UGrepSec_STATUSSEEK -- UTIL_Grep_Sectors helper: get Widget seek address
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0.
    ;   Widget seek address is loaded into kStdStatus.
    ;   Success/failure indications are identical to WIDGETIO.
_UGrepSec_STATUSSEEK:
    CLR.W   zWIOReadLen              ; Current seek addr command reads no data
    CLR.W   zWIOWriteLen             ; Current seek addr command writes no data
    LEA     s_UGrepSecStatusSeek,A0  ; Command: get int status, curr seek pos
    MOVE.B  #3,D0                    ; This command is three bytes long
    JSR     WIDGETCMD                ; Construct actual command in RAM
    JSR     WIDGETIO                 ; Issue command
    RTS                              ; Back to caller

    ; _UGrepSec_DIAGREAD -- UTIL_Grep_Sectors helper: issue Diag_Read command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0.
    ;   Success/failure indications are identical to WIDGETIO.
_UGrepSec_DIAGREAD:
    MOVE.W  zBlockSize,zWIOReadLen   ; Read a whole block from the Widget
    MOVE.L  #zSectorTag,zWIOReadPtr  ; Read into this memory location
    CLR.W   zWIOWriteLen             ; Diag_Read command writes no data
    LEA     s_UGrepSecDiagRead,A0    ; Location of command template
    MOVE.B  #2,D0                    ; This command is two bytes long
    JSR     WIDGETCMD                ; Construct actual command in RAM
    JSR     WIDGETIO                 ; Issue command
    JSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the read command go ok?
    RTS                              ; Back to caller

    ; _UGrepSec_SENDSEEK -- UTIL_Grep_Sectors helper: issue Send_Seek command
    ; Args:
    ;   D1: Longword coding cylinder/head/sector seek address. Cylinder is
    ;       MSWord, head is the second least significant byte, sector is
    ;       the LSByte (CCHS).
    ; Notes:
    ;   Trashes D0/A0.
    ;   Success/failure indications are identical to WIDGETIO.
_UGrepSec_SENDSEEK:
    CLR.W   zWIOReadLen              ; Send_Seek command reads no data
    CLR.W   zWIOWriteLen             ; Send_Seek command writes no data
    MOVE.L  D1,(2+z_UGrepSecSendSeekCmd)   ; Inject seek address into command
    LEA     z_UGrepSecSendSeekCmd,A0   ; Location of command template
    MOVE.B  #6,D0                    ; This command is six bytes long
    JSR     WIDGETCMD                ; Construct actual command in RAM
    JSR     WIDGETIO                 ; Issue command
    RTS                              ; Back to caller

    ; _UGrepSec_NEXTSECTOR -- UTIL_Grep_Sectors helper: increment CHS address
    ; Args:
    ;   D1: Longword coding cylinder/head/sector seek address. Cylinder is
    ;       MSWord, head is the second least significant byte, sector is
    ;       the LSByte (CCHS).
    ; Notes:
    ;   "Trashes" D1.
    ;   On completion, D1 contains the "next" seek address, Seek addresses
    ;       iterate through sectors, heads, and cylinders.
    ;   The next sector after the drive's largest addressable sector is
    ;       cylinder 0, head 0, sector 0.
    ;   Will not work properly if the drive has $FF sectors per track, $FF
    ;       heads, or $FF cylinders.
_UGrepSec_NEXTSECTOR:
    ADDQ.B  #1,D1                    ; Increment sector
    CMP.B   zSectors,D1              ; Used up all sectors on this track?
    BLO.S   .rt                      ; Not yet; jump back to caller
    LSR.L   #8,D1                    ; Yes, clear sectors, focus on heads
    ADDQ.B  #1,D1                    ; Increment head
    CMP.B   zHeads,D1                ; Used up all heads on this track?
    BLO.S   .rh                      ; Not yet; unshift and back to caller
    LSR.L   #8,D1                    ; Yes, clear heads, focus on cylinders
    ADDQ.W  #1,D1                    ; Increment cylinder
    CMP.W   zCylinders,D1            ; Used up all cylinders in this drive?
    BLO.S   .rc                      ; Not yet; unshift and back to caller
    CLR.W   D1                       ; Yes, clear cylinders
.rc LSL.L   #8,D1                    ; Shift cylinders back one byte
.rh LSL.L   #8,D1                    ; Shift cylinders and heads back into place
.rt RTS                              ; Back to caller

    ; _UGrepBlo_PROREAD -- UTIL_Grep_Blocks helper: issue ProFile_Read command
    ; Args:
    ;   D1: Longword containing logical block address to read
    ; Notes:
    ;   Success/failure indications are identical to WIDGETIO.
_UGrepBlo_PROREAD:
    MOVE.L  D1,z_UGrepProReadCmd     ; Copy desired block to command
    CLR.B   z_UGrepProReadCmd        ; Reset actual command byte to 0
    MOVE.B  #4,zWIOCmdLen            ; This command is four bytes long
    mMemCpy #z_UGrepProReadCmd,#zWIOCmd,#4   ; We copy it to the command buffer
    MOVE.W  zBlockSize,zWIOReadLen   ; Read a whole block from the Widget
    MOVE.L  #zSectorTag,zWIOReadPtr  ; Read into this memory location
    CLR.W   zWIOWriteLen             ; ProFile_Read command writes no data
    JSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the read command go ok?
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Grep numerical data =============================
    SECTION kSecData

    DS.W    0                        ; Force even alignment for what follows
d_UGrepSecFormLenBounds:
    DC.L    $00000010                ; Patterns can be no longer than 16 bytes


    PAGE
* NeoWidEx Grep scratch data allocation ====================
    SECTION kSecScratch

z_UGrepPatternLen:
    DC.B    10                       ; Length of pattern to search for in bytes

    DS.W    0
z_UGrepPattern:
    DC.L    $F0783C1E                ; Actual pattern to search for
    DC.L    $11223344                ; The widget pattern is a useful initial...
    DC.L    $55667788                ; ...pattern to start with, at least for...
    DC.L    $99AABBCC                ; ...the first bit

z_UGrepStartPos:                     ; CHS or block where our search has started
    DC.B    'UGSS'

    DS.W    0
z_UGrepBloFormInitVals:              ; Initial field vals for first search block
    DC.L    $00000000

    DS.W    0
z_UGrepBloFormBounds:                ; Bounds for the first search block
    DC.L    $00000000

    DS.W    0                        ; Initial field values for the length form
z_UGrepFormLenInitVals:
    DC.L    $00000010

z_UGrepFormPat:                      ; Pattern form template. The actual form...
    DC.B    $0D,'PATTERN-'           ; ...fields will change depending on the...
z_UGrepSecFormPatFields:             ; ...user-specified pattern length
    DC.B    'ad      bd      cd      dd      ',0

    DS.W    0                        ; Initial field values for the pattern form
z_UGrepFormPatInitVals:
    DC.B    'Patt'                   ; These will always be overwritten by...
    DC.B    'ernI'                   ; ...the current contents of...
    DC.B    'nitl'                   ; ...z_UGrepPattern before the user...
    DC.B    'Vals'                   ; ...is shown the form

    DS.W    0                        ; Force even alignment for following data
z_UGrepSecSendSeekCmd:               ; Send_Seek cmd; last four bytes can change
    DC.B    $10,$04,$00,$00,$00,$00
z_UGrepProReadCmd:                   ; ProFile_Read cmd; last 3 bytes can change
    DC.B    $00,$00,$00,$00          ; (Also requires even alignment)


    PAGE
* NeoWidEx Grep strings ====================================
    SECTION kSecStrings

s_UGrepSecStatusSeek:
    DC.B    $10,$01,$02              ; Command to get current seek address
s_UGrepSecStatusStd:
    DC.B    $10,$01,$00              ; Command to read standard status
s_UGrepSecDiagRead:
    DC.B    $10,$09                  ; Diag_Read command (it's short!)

s_UGrepBloForm:                      ; User form for first block of search
    DC.B    $0D,'START SEARCH AT BLOCK ac____',0

    DS.W    0                        ; Form prompts for first block of search
s_UGrepBloFormPrompts:
    DC.L    .p1
.p1 DC.B    'BLOCK',0

s_UGrepFormLen:                      ; User form for pattern length
    DC.B    $0D,'PATTERN LENGTH IN BYTES-aa',0

    DS.W    0                        ; Form prompts for pattern length
s_UGrepFormLenPrompts:
    DC.L    .p1
.p1 DC.B    'BYTES',0

    DS.W    0                        ; Form prompts for pattern
s_UGrepFormPatPrompts:
    DC.L    .p1,.p2,.p3,.p4
.p1 DC.B    'FROM 0',0
.p2 DC.B    'FROM 4',0
.p3 DC.B    'FROM 8',0
.p4 DC.B    'FROM C',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
