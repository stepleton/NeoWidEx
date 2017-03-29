*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Exercise_Disk
* Written by : Tom Stepleton
* Date       : 16 March 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: 
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_BUFFER must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Exercise Disk code ==============================

    ; UTIL_Exercise_Disk -- Read and write to some or all logical blocks
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
UTIL_Exercise_Disk:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if it hasn't been run yet
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- EXERCISE DISK ---'>

    ; Ask user for exercise parameters
    MOVE.L  zNumBlocks,D0            ; Upper bound for block and increment...
    SUBQ.L  #1,D0                    ; ...is zNumBlocks-1
    MOVE.L  D0,z_UExrDiskForm1Bounds   ; Save upper block bound in bounds array
    MOVE.L  D0,(4+z_UExrDiskForm1Bounds)   ; Save increment bound in bounds
    LEA     s_UExrDiskForm1,A0       ; Prepare FORM args; address of template...
    LEA     s_UExrDiskForm1Prompts,A1  ; ...address of prompt pointer array...
    LEA     z_UExrDiskForm1InitVals,A2   ; ...address of initial values array...
    LEA     z_UExrDiskForm1Bounds,A3   ; ...and address of bounds array
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, jump ahead to quit
    ; No cancel; save current parameters for future defaults and use below
    mMemCpy #zFieldValues,#z_UExrDiskForm1InitVals,#(4*4)

    ; Ask user for exercise stopping criteria and confirmation
    LEA     s_UExrDiskForm2,A0       ; Prepare FORM args; address of template...
    LEA     s_UExrDiskForm2Prompts,A1  ; ...address of prompt pointer array...
    LEA     z_UExrDiskForm2InitVals,A2   ; ...address of initial values array...
    SUBA.L  A3,A3                    ; ...and specify no bounds...
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, jump ahead to quit
    TST.B   (7+zFieldValues)         ; Did the user say not to proceed?
    BEQ     .qt                      ; They did, jump ahead to quit
    ; No cancel; save user's stopping preference.
    MOVE.L  zFieldValues,z_UExrDiskForm2InitVals

    ; Setup before we begin the exercise. These are the only registers we need
    ; to preserve as we go; the rest of our state we keep in RAM.
    MOVE.L  z_UExrDiskLfsrSeed,D0    ; D0: current state of the LFSR...
    NOT.W   D0                       ; ...once its bits are inverted
    MOVE.L  z_UExrDiskStartBlock,D1  ; D1: the block to read next
    LEA     zSectorTag,A0            ; Start of the disk data buffer
    ; Zero out the error statistics we collect.
    mMemSet #0,#d_UExrDiskBlockCount,#(4*18)

    ; Print initial progress display, full of zeros
    BSR      _UExrDisk_PRINT_Initial

    ; Miscellaneous setup
    MOVE.B  #4,zWIOCmdLen            ; All our disk commands are four bytes

    ; If we're using the current data buffer contents as the data to write to
    ; the disk, save a backup copy just after the buffer. We also only need to
    ; compute the sector data CRC once, so we do it here.
    TST.W   D0                       ; 0 LFSR means use existing buffer data...
    BNE.S   .l0                      ; ...so skip ahead if that's not the case
    MOVEA.L A0,A1                    ; Copy disk data buffer address to A1
    ADDA.W  zBlockSize,A1            ; Advance A1 past end of buffer
    mMemCpy A0,A1,zBlockSize         ; Copy buffer to region just after buffer
    MOVEM.L D0-D1/A0,-(A7)           ; Save registers before computing data CRC
    MOVE.W  zBlockSize,D2            ; Size of region to compute CRC over
    BSR     CRC                      ; Compute data CRC
    MOVE.W  D0,z_UExrDiskTrueCrc     ; And save it for later comparison
    MOVEM.L (A7)+,D0-D1/A0           ; Restore registers

    ; Main exercise loop!
    ; Part 0: Generate the next round of data, if desired
.l0 JSR     QUITPOLL                 ; First, did the user want to quit early?
    BEQ     .qt                      ; If so, jump ahead to quit

    MOVE.W  D0,z_UExrDiskLastLsfrState   ; Save current LFSR state
    ; The move also updates the Z flag. 0 LFSR means use existing buffer data...
    BNE.S   .rf                      ; ...so skip ahead if that's not the case
    MOVEA.L A0,A1                    ; Copy disk data buffer address to A1
    ADDA.W  zBlockSize,A1            ; Advance A1 past end of buffer
    EXG     A0,A1                    ; mMemCpy dest cannot be A0, so swap
    mMemCpy A0,A1,zBlockSize         ; Copy buffer to region just after buffer
    EXG     A0,A1                    ; Undo register swap
    BRA.S   .l1                      ; Jump ahead to write the block

.rf MOVE.W  zBlockSize,D2            ; Generate this much random data
    MOVEM.L D1-D2/A0,-(A7)           ; Save registers before generating data
    BSR     LFSRFILL                 ; Generate random data
    MOVEM.L (A7)+,D1-D2/A0           ; Restore registers
    MOVEM.L D0-D1/A0,-(A7)           ; Save registers before computing data CRC
    BSR     CRC                      ; Compute data CRC
    MOVE.W  D0,z_UExrDiskTrueCrc     ; And save it for later comparison
    MOVEM.L (A7)+,D0-D1/A0           ; Restore registers

    ; Part 1: Write the block to disk at the current logical address.
.l1 MOVE.L  D1,z_UExrDiskProFileCmd  ; Save sector to the ProFile command
    MOVE.B  #1,z_UExrDiskProFileCmd  ; By default, we perform a write
    TST.B   (3+z_UExrDiskUseWriteVerify)   ; But did we want a write-verify?
    BEQ.S   .ww                      ; No, skip ahead and do the write
    MOVE.B  #2,z_UExrDiskProFileCmd  ; Yes, get ready to write-verify
.ww mMemCpy #z_UExrDiskProFileCmd,#zWIOCmd,#4  ; Copy command to the cmd. buffer
    CLR.W   zWIOReadLen              ; This command reads no bytes
    MOVE.W  zBlockSize,zWIOWriteLen  ; Write a whole block to the drive
    MOVE.L  #zSectorTag,zWIOWritePtr   ; Write data at this memory location
    JSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed

    LEA     d_UExrDiskWriteCounters,A1   ; Prepare to update write anomaly ctrs.
    BSR     _UExrDisk_UPDATECOUNTS   ; Update anomaly counters from std. status
    BEQ.S   .l2                      ; No failure? Jump ahead to Part 2
    TST.B   (3+z_UExrDiskStopOnFailure)  ; But do we stop on failure?
    BNE     .fa                      ; Yes, jump to quit early

    ; Part 2: Read the block from disk at the current logical address.
.l2 MOVE.L  D1,z_UExrDiskProFileCmd  ; Save sector to the ProFile command
    CLR.B   z_UExrDiskProFileCmd     ; We will perform a read
    mMemCpy #z_UExrDiskProFileCmd,#zWIOCmd,#4  ; Copy command to the cmd. buffer
    MOVE.W  zBlockSize,zWIOReadLen   ; Read a whole block from the drive
    CLR.W   zWIOWriteLen             ; This command writes no bytes
    MOVE.L  #zSectorTag,zWIOReadPtr  ; Read data to this memory location
    JSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed

    LEA     d_UExrDiskReadCounters,A1  ; Prepare to update read anomaly counters
    BSR     _UExrDisk_UPDATECOUNTS   ; Update anomaly counters from std. status
    BEQ.S   .l3                      ; No failure? Jump ahead to Part 3
    TST.B   (3+z_UExrDiskStopOnFailure)  ; But do we stop on failure?
    BNE     .fa                      ; Yes, jump to quit early

    ; Part 3: Compute CRC of the block data we just read.
.l3 MOVEM.L D0-D1/A0,-(A7)           ; Save registers before computing data CRC
    MOVE.W  zBlockSize,D2            ; Size of region to compute CRC over
    BSR     CRC                      ; Compute data CRC
    CMP.W   z_UExrDiskTrueCrc,D0     ; Compare it with saved data CRC
    MOVEM.L (A7)+,D0-D1/A0           ; Restore registers (preserves flags)
    BEQ.S   .l4                      ; CRC match? Jump ahead to Part 4
    ADDQ.L  #1,d_UExrDiskCrcMismatch   ; No, increment mismatch count
    TST.B   (3+z_UExrDiskStopOnFailure)  ; But do we stop on failure?
    BNE     .fa                      ; Yes, jump to quit early

    ; Part 4: Print updated info, then advance to the next block to read
.l4 ADDQ.L  #1,d_UExrDiskBlockCount  ; Bump up count of blocks exercised
    BSR     _UExrDisk_PRINT          ; Refresh display information

    ADD.L   z_UExrDiskBlockIncrement,D1  ; Add increment to the current LBA
    CMP.L   zNumBlocks,D1            ; Have we jumped beyond the last legal LBA?
    BLO.S   .l5                      ; No, jump ahead to Part 5
    SUB.L   zNumBlocks,D1            ; Subtract disk size in blocks from LBA

    ; Part 5. Exit if we've looped around the disk, otherwise repeat the loop.
.l5 CMP.L   z_UExrDiskStartBlock,D1  ; Back to the beginning?
    BEQ.S   .ok                      ; Yes, all done!
    BRA     .l0                      ; No, back to top of loop

.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Ack user quit
    RTS                              ; Back to caller

    ; For failures, we change the default starting block and the LFSR random
    ; seed so that restarting the exercise with default parameters means
    ; picking up just where we left off. Of course this does mean that if the
    ; drive is now well-behaved, the new exercise will terminate as soon as it
    ; reaches this point, not the place that would have been the stopping point
    ; on the last run.
.fa MOVE.L  D1,z_UExrDiskStartBlock  ; Update start block so we can restart here
    CLR.L   D0                       ; Likewise with the state of the random...
    MOVE.W  z_UExrDiskLastLsfrState,D0   ; ...block data generator, which...
    NOT.W   D0                       ; ...has to be inverted to work with the...
    MOVE.L  D0,z_UExrDiskLfsrSeed    ; ...form requesting data from the user
    BSR      _UExrDisk_PRINT         ; Print final anomaly counts
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,$0D,'STOPPING ON FAILURE.'>
    RTS                              ; Back to caller


    ; _UExrDisk_UPDATECOUNTS -- Update anomaly counts from standard status
    ; Args:
    ;   A1: points to the beginning of a block of 8 long anomaly counts, like
    ;       d_UExrDiskWriteCounters.
    ; Notes:
    ;   On return, Z is cleared iff the operation has failed.
    ;   Trashes A1/D2.
_UExrDisk_UPDATECOUNTS:
    MOVE.L  kStdStatus,D2            ; Copy standard status to D2
    BTST.L  #$18,D2                  ; Did the operation just fail?
    BEQ.S   .u1                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment failure count
.u1 BTST.L  #$12,D2                  ; Was the spare table updated?
    BEQ.S   .u2                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment spare table update count
.u2 BTST.L  #$1B,D2                  ; Was there a read error?
    BEQ.S   .u3                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment read error count
.u3 BTST.L  #$19,D2                  ; Was there a servo error?
    BEQ.S   .u4                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment servo error count
.u4 BTST.L  #$11,D2                  ; Did the heads seek to the wrong track?
    BEQ.S   .u5                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment bad seek count
.u5 BTST.L  #$07,D2                  ; Did ECC circuit say read error?
    BEQ.S   .u6                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment ECC error count
.u6 BTST.L  #$06,D2                  ; Did CRC circuit say read error?
    BEQ.S   .u7                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment CRC error count
.u7 BTST.L  #$1A,D2                  ; Was no matching sector header found?
    BEQ.S   .rt                      ;   No, move on
    ADDQ.L  #1,(A1)+                 ;   Yes, increment sector not found count
.rt BTST.L  #$18,D2                  ; Set Z flag to the operation's success
    RTS                              ; Back to caller


    ; _UExrDisk_PRINT -- Print disk exercise progress information
    ; Args:
    ;   (none)
    ; Notes:
    ;   The full _UExrDisk_PRINT rewinds the current row in order to overwrite
    ;       earlier copies of information it has printed. To print the very
    ;       first copy without overwriting any text on the screen, branch to
    ;       _UExrDisk_PRINT_Initial instead of _UExrDisk_PRINT.
    ;   Trashes A1/D2.
_UExrDisk_PRINT:
    SUBI.W  #(14*kCharHeight),kCrtRow  ; Rewind cursor to overwrite earlier data
_UExrDisk_PRINT_Initial:
    MOVE.L  d_UExrDiskBlockCount,-(A7)   ; Blocks exercised so far and...
    MOVE.L  D1,-(A7)                 ; ...current block to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,$0D,'BLOCK-'>,3x,<' COUNT-'>,3x
    MOVE.W  z_UExrDiskTrueCrc,-(A7)  ; Last true CRC to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' CRC-'>,hx

    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,$0D,'   WRITE'>
    TST.B   (3+z_UExrDiskUseWriteVerify)   ; Are we using write-verify?
    BEQ.S   .pt                      ; No; skip ahead to print write table
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'-VERIFY'>
.pt LEA     d_UExrDiskWriteCounters,A1   ; Print table of write statistics
    BSR     _UExrDisk_TABLE          ; Call table printer
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,$0D,'   READ'>
    LEA     d_UExrDiskReadCounters,A1  ; Print table of write statistics
    BSR     _UExrDisk_TABLE          ; Call table printer

    MOVE.L  d_UExrDiskCrcMismatch,-(A7)  ; CRC mismatches to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,$0D>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' NEOWIDEX DATA CRC MISMATCHES'>
    RTS


    ; _UExrDisk_TABLE -- Print table of disk I/O anomaly counters
    ; Args:
    ;   A1: Address of 8 consecutive longs to print.
    ; Notes:
    ;   Trashes A1/D2.
_UExrDisk_TABLE:
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UExrDiskTableHeader
    MOVEQ.L #7,D2                    ; We will print eight numerical quantities
.lp MOVE.L  (A1)+,-(A7)              ; Next quantity to print onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,3x  ; Print onto the stack
    ADDQ.W  #2,kCrtCol               ; Advance cursor to next table entry
    DBRA    D2,.lp                   ; Loop until we're out of things to print
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Exercise Disk numerical data =====================
    SECTION kSecData

    ; The following locations store counts of events reported in the standard
    ; status while the disk exercise takes place.
    DS.W    0

    ; How many blocks have we visited in this exercise?
d_UExrDiskBlockCount:
    DC.L    $00000000

    ; In the following, it's important that the order of these anomaly counters
    ; be identical for both the read counters and the write counters. The
    ; printing code in _UExrDisk_PRINT and _UExrDisk_TABLE depends on this.

    ; During writes or write-verifies:
d_UExrDiskWriteCounters:
d_UExrDiskWOpFailures:               ; Operation failed
    DC.L    $00000000
d_UExrDiskWSpareUpdates:             ; Spare table was updated
    DC.L    $00000000
d_UExrDiskWReadErrors:               ; Read error (for write-verify only)
    DC.L    $00000000
d_UExrDiskWServoErrors:              ; Servo error
    DC.L    $00000000
d_UExrDiskWWrongSeeks:               ; Heads seeked to wrong track
    DC.L    $00000000
d_UExrDiskWEccErrors:                ; ECC circuit says read error (wr-ver only)
    DC.L    $00000000
d_UExrDiskWCrcErrors:                ; CRC circuit says read error (wr-ver only)
    DC.L    $00000000
d_UExrDiskWNoHeaders:                ; No matching header found
    DC.L    $00000000

    ; During reads:
d_UExrDiskReadCounters:
d_UExrDiskROpFailures:               ; Operation failed
    DC.L    $00000000
d_UExrDiskRSpareUpdates:             ; Spare table was updated
    DC.L    $00000000
d_UExrDiskRReadErrors:               ; Read error
    DC.L    $00000000
d_UExrDiskRServoErrors:              ; Servo error
    DC.L    $00000000
d_UExrDiskRWrongSeeks:               ; Heads seeked to wrong track
    DC.L    $00000000
d_UExrDiskREccErrors:                ; ECC circuit says read error
    DC.L    $00000000
d_UExrDiskRCrcErrors:                ; CRC circuit says read error
    DC.L    $00000000
d_UExrDiskRNoHeaders:                ; No matching header found
    DC.L    $00000000

    ; After reading in what we've written: does the CRC of the data we read
    ; match the CRC of what we wrote?
d_UExrDiskCrcMismatch:
    DC.L    $00000000


    PAGE
* NeoWidEx Exercise Disk scratch data allocation ============
    SECTION kSecScratch

    DS.W    0                        ; (Alignment makes copying easier)
z_UExrDiskProFileCmd:                ; Space for ProFile read/write(verify) cmd.
    DC.B    $01,$00,$00,$00

z_UExrDiskTrueCrc:                   ; CRC of data written to the disk
    DC.W    $0000
z_UExrDiskLastLsfrState:             ; LFSR state before generating current data
    DC.W    $0000

    ; These values are also used for parameter value storage during the
    ; execution of the exercise---they're not just for defaults. Sorry!
    DS.W    0
z_UExrDiskForm1InitVals:             ; Initial field values for the first form
z_UExrDiskStartBlock:
    DC.L    $00000000                ;   Start block
z_UExrDiskBlockIncrement:
    DC.L    $00000001                ;   Block increment
z_UExrDiskLfsrSeed:
    DC.L    $0000FFFF                ;   Random seed
z_UExrDiskUseWriteVerify:
    DC.L    $00000000                ;   Write-verify?

    DS.W    0
z_UExrDiskForm1Bounds:               ; Field bounds for the first form
    DC.L    $00000000                ;   Start block
    DC.L    $00000000                ;   Block increment
    DC.L    $0000FFFF                ;   Random seed
    DC.L    $FFFFFFFF                ;   Write-verify?

    DS.W    0
z_UExrDiskForm2InitVals:             ; Initial field values for the first form
z_UExrDiskStopOnFailure:
    DC.L    $00000000                ;   Stop exercise on failure?
    DC.L    $00000000                ;   Really destroy all data on the disk?


    PAGE
* NeoWidEx Exercise Disk strings ============================
    SECTION kSecStrings

s_UExrDiskForm1:                     ; User form for disk exercise parameters
    DC.B    $0D,'START EXERCISE AT BLOCK ac____ AND INCREMENT BY bc____'
    DC.B    $0D,'EXERCISE DATA RANDOM SEED cb__'
    DC.B    $0D,'          ...SPECIFY FFFF TO USE DATA BUFFER CONTENTS.'
    DC.B    $0D,'WRITE-VERIFY INSTEAD OF WRITE? d',0

    DS.W    0
s_UExrDiskForm1Prompts:              ; Form prompts for disk exercise parameters
    DC.L    .p1,.p2,.p3,.p4
.p1 DC.B    'START BLOCK',0
.p2 DC.B    'BLOCK INCREMENT',0
.p3 DC.B    'RANDOM SEED',0
.p4 DC.B    'WRITE-VERIFY',0

s_UExrDiskForm2:                     ; User form for stop criteria, confirmation
    DC.B    $0D
    DC.B    $0D,'STOP EXERCISE ON FAILURE? a'
    DC.B    $0D,'ARE YOU READY TO DESTROY ALL DATA ON THIS DISK? b',0

    DS.W    0
s_UExrDiskForm2Prompts:              ; Form prompts for same
    DC.L    .p1,.p2
.p1 DC.B    'STOP ON FAILURE',0
.p2 DC.B    'PROCEED',0

s_UExrDiskTableHeader:
    DC.B    $0D,'OP      SPARE   READ    SERVO   WRONG   ECC     CRC     NO'
    DC.B    $0D,'FAILURE UPDATE  ERROR   ERROR   SEEK    ERROR   ERROR   HEADER'
    DC.B    $0D,0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
