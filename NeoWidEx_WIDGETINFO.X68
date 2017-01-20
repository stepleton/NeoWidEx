*-----------------------------------------------------------
* Title      : NeoWidEx_WIDGETINFO
* Written by : Tom Stepleton
* Date       : 08 November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Subroutines to gather/print drive info.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Certain scratch data locations must be defined.
*-----------------------------------------------------------


* NeoWidEx WIDGETINFO code =================================

    ; WINFOMAYBE -- Run WIDGETINFO iff it hasn't been run yet
    ; Args:
    ;   (none)
    ; Notes:
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
WINFOMAYBE:
    TST.B   zHaveInfo                ; Have we run WIDGETINFO yet?
    BEQ.S   WIDGETINFO               ; No, go run it!
    RTS                              ; Yes, back to the caller.

    ; WINFOSTATUSCHECK -- Invalidate cached Widget info if spare table changes
    ; Args:
    ;   (none)
    ; Notes:
    ;   Will mark cached WIDGETINFO information invalid if the "spare table was
    ;       just updated" bit is set in standard status.
    ;   For best results, run immediately after a command that could update the
    ;       spare table. Logical reads and writes with recovery mode enabled
    ;       certainly fall into this category, but other commands may also.
WINFOSTATUSCHECK:
    BTST.B  #2,(1+kStdStatus)        ; Was the spare table just updated?
    BEQ.S   .rt                      ; No, jump to return to caller
    CLR.B   zHaveInfo                ; Yes; mark Widget info invalid
.rt RTS                              ; Back to caller

    ; WIDGETCHECK -- Run WINFOMAYBE, then bail to caller's caller if no Widget
    ; Args:
    ;   (none)
    ; Notes:
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
    ;   If zIsWidgety is zero (after running WIDGETINFO if needed), the return
    ;       address for the call to WIDGETCHECK is dropped and RTS is executed,
    ;       returning to the caller's caller.
    ;   Will NOT work if the subroutine that called WIDGETCHECK places ANYTHING
    ;       on the stack prior to the BSR or JSR to WIDGETCHECK.
WIDGETCHECK:
    BSR.B   WINFOMAYBE               ; Run WIDGETINFO if it hasn't been run yet
    TST.B   zIsWidgety               ; Do we have a Widget?
    BNE.S   .rt                      ; Yes, skip ahead to return
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'YOU NEED A WIDGET TO DO THAT.'>
    ADDQ.L  #4,A7                    ; Prepare to bail to the caller's caller
.rt RTS                              ; Return to caller, or caller's caller

    ; WIDGETINFO -- Gather information from the $FFFFFF sector
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes registers: D0-D4/A0-A3.
    ;   On error, the carry bit is set. Only SECTOR will report any error
    ;       condition, so see SECTOR documentation for interpreting its
    ;       error output.
WIDGETINFO:
    ; Load the Widget's spare table.
    MOVE.L  #$00FFFFFF,D1            ; Sector ID for Widget spare table
    BSR     SECTOR                   ; Read the spare table
    BCS     .rt                      ; Jump to return on error

    ; Copy the device name (the first 13 bytes).
    mMemCpy #zSectorTag,#zDeviceName,#$D

    ; Copy the device number and also make our first guess about whether this
    ; is a Widget.
    MOVEA.L #(zSectorTag+$D),A0      ; Address for device number to A0
    m_cp3b  A0,D0                    ; Load device number into DO...
    MOVE.L  D0,zDeviceNum            ; ...and copy into RAM
    ADDQ.L  #3,A0                    ; Advance A0
    CLR.B   zIsWidgety               ; Clear the "is a widget" flag in RAM
    CMPI.L  #$00000100,D0            ; Is the device number low for a Widget?
    BLO.S   .fw                      ; Device number too low, skip ahead
    CMPI.L  #$00000121,D0            ; Is the device number too high for Widget?
    BHI.S   .fw                      ; Device number too high, skip ahead
    NOT.B   D0                       ; Inverse of device number LSByte...
    MOVE.B  D0,zIsWidgety            ; ...goes into zIsWidgety temporarily

    ; Copy the device firmware version.
.fw MOVE.W  (A0)+,zFirmware

    ; Copy the blocks count and blocksize.
    m_cp3b  A0,D0                    ; Blocks count into D0...
    MOVE.L  D0,zNumBlocks            ; ...and copy into RAM
    ADDQ.L  #2,A0                    ; A0 to 1 byte before end of block count
    MOVE.L  (A0),D0                  ; Middle two bytes are sector size...
    LSR.L   #8,D0                    ; ...shift to the lower two bytes...
    MOVE.W  D0,zBlockSize            ; ...and copy the sector size into RAM
    ADDQ.L  #3,A0                    ; Advance A0 ahead to what comes next

    ; Copy Widget-specific information if we suspect this is a Widget, and
    ; also compute spacing between spares, spares in use, and bad block counts.
    ; On the Widget, all three are padded with two $00 bytes.
    CLR.W   D0                       ; By default, there is no such padding
    TST.B   zIsWidgety               ; Is it a Widget?
    BEQ.S   .sc                      ; No; skip ahead to spares information
    ADDQ.W  #2,D0                    ; Yes, so two padding bytes
    MOVE.B  (A0)+,zCylinders         ; Cylinder count upper byte into RAM
    MOVE.B  (A0)+,(zCylinders+1)     ; Cylinder count lower byte into RAM
    MOVE.B  (A0)+,zHeads             ; Copy number of heads into RAM
    MOVE.B  (A0)+,zSectors           ; Copy sectors per track into RAM

    ; Load counts of spares, spares in use, and bad blocks.
.sc ADDA.W  D0,A0                    ; Add extra Widget spacing, if needed
    MOVE.B  (A0)+,zSpares            ; Copy count of spare sectors into RAM
    ADDA.W  D0,A0                    ; Add extra Widget spacing, if needed
    MOVE.B  (A0)+,zSparesInUse       ; Copy count of spares in use into RAM
    ADDA.W  D0,A0                    ; Add extra Widget spacing, if needed
    MOVE.B  (A0)+,zBadBlocks         ; Copy count of bad blocks into RAM

    ; Further Widget-only data follows
    TST.B   zIsWidgety               ; Are we still guessing it's a Widget?
    BEQ.S   .ck                      ; No; skip ahead to test loaded info
    MOVE.B  (A0)+,zFmtOffset         ; Copy format offset into RAM
    MOVE.B  (A0)+,zFmtIntrl          ; Copy format interlacing into RAM

    ; Validation. Now that we've loaded all of the drive parameters, we compare
    ; the ones that should be uniform across all drives of a particular type
    ; against the parameters of known drive types.
.ck LEA     sSignatures,A0           ; Point A0 at the first signature record
                             ; For each signature:
.c0 CLR.W   D1                       ;   Character errors accumulate in D1
    MOVE.W  (A0)+,D0                 ;   New signature length to D0
    BEQ.S   .c3                      ;   If it's 0, we already match; skip ahead
    SUBQ.W  #1,D0                    ;   Subtract 1 to make D0 a loop variable
    LEA     zSignature,A1            ;   A1 (back) to loaded drive's signature
                             ;   For each byte in the signature:
.c1 CMPM.B  (A0)+,(A1)+              ;     Compare next signature byte
    BEQ.S   .c2                      ;     The same? Skip to end of inner loop
    ADDQ.W  #1,D1                    ;     Otherwise accumulate error count
.c2 DBRA    D0,.c1                   ;     Loop to next byte

.c3 TST.W   D1                       ;   Did we encounter byte mismatches?
    BEQ.S   .c5                      ;   No, break out of the loop
    ADDQ.L  #1,A0                    ;   Yes, move past the isWidgety byte...
.c4 TST.B   (A0)+                    ;     ...and past the drive name string...
    BNE.S   .c4                      ;     ...yes, past the name string
    MOVE.W  A0,D0                    ;   Skip padding; copy lower A0 to D0...
    ANDI.W  #1,D0                    ;   ...keeping LSBit only, then add to...
    ADDA.W  D0,A0                    ;   ...A0, moving beyond any padding byte
    BRA.S   .c0                      ;   Try to match against the next signature

.c5 MOVE.B  (A0)+,zIsWidgety         ; Save zIsWidgety byte
    MOVE.L  A0,zDriveNamePtr         ; Save pointer to our name for this drive

    ; All done!
    MOVE.B  #1,zHaveInfo             ; We've run WIDGETINFO successfully
    ANDI.B  #$0,CCR                  ; No error to report
.rt RTS                              ; Return to the caller

    ; WINFOPRINT -- Print drive information gathered by WIDGETINFO
    ; Args:
    ;   (none)
    ; Notes:
    ;   Runs WIDGETINFO if it hasn't been run yet, and in that case, has all
    ;       of WIDGETINFO's side effects. Otherwise, there are no side effects
    ;       beyond printing stuff.
WINFOPRINT:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if needed
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- DRIVE INFO ---',$0D>

    MOVE.L  zDriveNamePtr,-(A7)      ; Drive type string pointer onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,<'.',$0D>

    MOVE.L  #zDeviceName,-(A7)       ; Drive device name pointer onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DEVICE NAME-/'>,s,<'/.'>
    MOVE.L  zDeviceNum,-(A7)         ; Drive device number onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  NUMBER-'>,3x,<'. '>
    TST.B   zIsWidgety               ; Did we decide this was a Widget?
    BNE     .yw                      ; Yes, say so
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  NOT A WIDGET.',$0D>
    BRA     .bi                      ; No; print above, skip ahead
.yw mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SEEMS WIDGETY.',$0D>

    ; Print basic information about the drive.
.bi MOVE.W  zFirmware,-(A7)          ; Drive firmware revision onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'REV-'>,hx
    MOVE.L  zNumBlocks,-(A7)         ; Drive block count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'     BLOCKS-'>,3x
    MOVE.W  zBlockSize,-(A7)         ; Drive block size onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'     BLOCKSIZE-'>,hx

    ; Print Widget-specific information about the drive, if it's a Widget.
    TST.B   zIsWidgety               ; Is this a Widget?
    BEQ     .sc                      ; No, so skip ahead

    MOVE.W  zCylinders,-(A7)         ; Drive cylinder count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'TRACKS-'>,hx

    MOVE.B  zHeads,-(A7)             ; Drive head count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  HEADS-'>,hhx
    MOVE.B  zSectors,-(A7)           ; Drive sectors per track onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  SECTORS-'>,hhx
    ; For pretty text alignment, we pull the cursor backward two spaces:
    SUBQ.W  #2,kCrtCol               ; Note that only Widgets cause this

    ; And back to basic information about the drive.
.sc ADDQ.W  #2,kCrtCol               ; Advance cursor two spaces
    MOVE.B  zSpares,-(A7)            ; Drive spares capacity onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'   SPARES-'>,hhx,endl

    ; But now back to more Widget information.
    TST.B   zIsWidgety               ; Is this a Widget?
    BEQ     .s0                      ; No, so skip ahead
    MOVE.B  zFmtOffset,-(A7)         ; Drive format offset onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'FORMAT OFFSET-'>,hhx
    MOVE.B  zFmtIntrl,-(A7)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  INTERLEAVE-'>,hhx,endl

    ; Print number of spares in use.
.s0 TST.B   zSparesInUse             ; Are any spares in use?
    BNE.S   .s1                      ; Yes, skip ahead to say how many
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO SPARES IN USE',$0D>
    BRA     .b0                      ; Jump ahead to print bad blocks in use
.s1 MOVE.B  zSparesInUse,-(A7)       ; Drive spares-in-use count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARES IN USE-'>,hhx,endl

    ; Print number of bad blocks.
.b0 TST.B   zBadBlocks               ; Are there any bad blocks?
    BNE.S   .b1                      ; Yes, skip ahead to say how many
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO BAD BLOCKS'>
    BRA     .rt                      ; Jump ahead to print bad blocks in use
.b1 MOVE.B  zBadBlocks,-(A7)         ; Drive spares-in-use count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCKS-'>,hhx

.rt RTS                              ; Back to the caller

    ; STATUSPRINT -- Print standard status bytes from last drive I/O op
    ; Args:
    ;   (none)
    ; Notes:
    ;   (none)
STATUSPRINT:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- LAST STANDARD STATUS ---'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'                          '>
    MOVE.B  (kStdStatus+3),-(A7)     ; Fourth status byte to stack for printing
    MOVE.B  (kStdStatus+2),-(A7)     ; Third status byte
    MOVE.B  (kStdStatus+1),-(A7)     ; Second status byte
    MOVE.B  (kStdStatus+0),-(A7)     ; First status byte; now print them all
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<' '>,hhx,<' '>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,<' '>,hhx,endl
    ; Print the status bitmap with explanatory text.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sStatusBitmap,kStdStatus
    MOVE.L  D0,-(A7)                 ; Save D0 so we can use it temporarily
    MOVE.B  (kStdStatus+3),D0        ; Fourth status byte to D0
    ANDI.B  #$0F,D0                  ; Preserve only the failed retry count
    MOVE.B  D0,-(A7)                 ; Onto the stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print failed retry count
    MOVE.L  (A7)+,D0                 ; Restore D0
    RTS                              ; Back to the caller

    ; SPAREPRINT -- Read and print the spare table
    ; Args:
    ;   (none)
    ; Notes:
    ;   Runs WIDGETINFO if it hasn't been run yet, and in that case, has all
    ;       of WIDGETINFO's side effects. If WIDGETINFO has been run, then
    ;       only D0-D2/A0-A2 will be trashed.
SPAREPRINT:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if needed
    mResetP                          ; Reset paging (only needed for Widget)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SPARE TABLE ---'>,pendl
    TST.B   zIsWidgety               ; Is this a Widget or a ProFile?
    BEQ.S   _SPAREPRINTPR            ; It's a ProFile; jump to specialised code
    BRA     _SPAREPRINTWI            ; It's a Widget; jump to specialised code

    ; SPAREPRINT branch for printing ProFile spare tables
_SPAREPRINTPR:
    ; Load the ProFile's spare table.
    MOVE.L  #$00FFFFFF,D1            ; Sector ID for the ProFile spare table
    BSR     SECTOR                   ; Read the spare table
    BCS     .rt                      ; Jump to return on error

    ; Set A0 to the start of the spare table.
    MOVEA.L #(zSectorTag+$1A),A0     ; Spare table is 26 bytes in

    ; Print table of spared blocks.
    TST.B   zSparesInUse
    BNE.S   .s0
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO '>
.s0 mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BLOCKS SPARED'>
    CLR.W   D0                       ; Blank D0 word for DBRA below
    MOVE.B  zSparesInUse,D0          ; Spare count into D0
    BEQ     .s3                      ; No spares? Skip to consume terminator
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; CR before spare table starts
    SUBQ.B  #1,D0                    ; Subtract 1 to make D0 a loop iterator
.s1 m_cp3b  A0,D1                    ; Next spared sector into D1...
    MOVE.L  D1,-(A7)                 ; ...and onto the stack
    CMPI.W  #(kFirstCol+56),kCrtCol  ; Do we need a CR?
    BLO.S   .s2                      ; No, print the entry
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a CR first
.s2 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,3x  ; Print space and entry
    ADDQ.L  #3,A0                    ; On to the next spare table entry
    DBRA    D0,.s1                   ; Iterate till done with spares

    ; Check that the spare table ends with an $FFFFFF entry.
.s3 m_cp3b  A0,D1                    ; Get what should be the terminator
    CMP.L   #$00FFFFFF,D1            ; Is it the terminator?
    BEQ     .s4                      ; Yes, carry on
    MOVE.L  D1,-(A7)                 ; No, get ready to print it
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SPARE TABLE ENDS WITH '>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' AND NOT FFFFFF? ODD...'>
.s4 ADDQ.L  #3,A0                    ; Advance to the bad block table

    ; Print table of bad blocks.
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; CR before bad block section
    TST.B   zBadBlocks
    BNE.S   .b0
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO '>
.b0 mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCKS'>
    CLR.W   D0                       ; Blank D0 word for DBRA below
    MOVE.B  zBadBlocks,D0            ; Bad block count into D0
    BEQ     .b3                      ; No bad blocks? Skip to consume terminator
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; CR before bad blocks table starts
    SUBQ.B  #1,D0                    ; Subtract 1 to make D0 a loop iterator
.b1 m_cp3b  A0,D1                    ; Next bad block into D1...
    MOVE.L  D1,-(A7)                 ; ...and onto the stack
    CMPI.W  #(kFirstCol+56),kCrtCol  ; Do we need a CR?
    BLO.S   .b2                      ; No, print the entry
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a CR first
.b2 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,3x  ; Print space and entry
    ADDQ.L  #3,A0                    ; On to the next bad block table entry
    DBRA    D0,.b1                   ; Iterate till done with bad blocks

    ; Check that the bad block tabel ends with an $FFFFFF entry.
.b3 m_cp3b  A0,D1                    ; Get what should be the terminator
    CMP.L   #$00FFFFFF,D1            ; Is it the terminator?
    BEQ     .rt                      ; Yes, carry on
    MOVE.L  D1,-(A7)                 ; No, get ready to print it
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'BAD BLOCK TABLE ENDS WITH '>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' AND NOT FFFFFF? ODD...'>

.rt RTS                              ; Back to SPAREPRINT's caller

    ; SPAREPRINT branch for printing Widget spare tables (in detail)
_SPAREPRINTWI:
    ; Load the Widget's spare table.
    MOVE.L  #$00FFFFFE,D1            ; Sector ID for the Widget spare table
    BSR     SECTOR                   ; Read the spare table
    BCS     .rt                      ; Jump to return on error

    MOVEA.L #(zSectorTag+$4),A0      ; Address for spare table revision to A0
    MOVE.L  (A0)+,-(A7)              ; And copied to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'THIS SPARE TABLE HAS BEEN REVISED '>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,lx,<' TIMES'>,pendl

    ; Print format and spare stats that we also saw in $FFFFFF.
    MOVE.B  zFmtOffset,D1            ; $FFFFFF format offset for comparison...
    MOVE.B  (A0)+,D0                 ; ...with this block's reported offset...
    MOVE.B  D0,-(A7)                 ; ...which also goes on the stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'FORMAT OFFSET-'>,hhx
    BSR     .cm                      ; Compare and complain if they differ

    MOVE.B  zFmtIntrl,D1             ; $FFFFFF interleave for comparison...
    MOVE.B  (A0)+,D0                 ; ...with this block's reported value...
    MOVE.B  D0,-(A7)                 ; ...which also goes on the stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  INTERLEAVE-'>,hhx
    BSR     .cm                      ; Compare and complain if they differ

    ADDA.L  #128,A0                  ; Skip past the head pointer array

    MOVE.B  zSparesInUse,D1          ; $FFFFFF spares in use for comparison...
    MOVE.B  (A0)+,D0                 ; ...with this block's reported value...
    MOVE.B  D0,-(A7)                 ; ...which also goes on the stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  SPARES-'>,hhx
    BSR     .cm                      ; Compare and complain if they differ

    MOVE.B  zBadBlocks,D1            ; $FFFFFF bad blocks for comparison...
    MOVE.B  (A0)+,D0                 ; ...with this block's reported value...
    MOVE.B  D0,-(A7)                 ; ...which also goes on the stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  BAD BLOCKS-'>,hhx
    BSR     .cm                      ; Compare and complain if they differ

    ; Print the bitmap of allocated spare blocks.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,pendl
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BITMAP OF ALLOCATED SPARES'>,pendl
    ; We just keep pulling in longs and printing out their bits using the
    ; mPrtBts templates defined in the string section. The last two bytes of
    ; the last long stray into the heap, but we don't use those.
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sSpareBitmap1,(A0)+
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sSpareBitmap2,(A0)+
    mPrtBts kCrtRow,kCrtCol,#kFirstCol,export,#sSpareBitmap3,(A0)+
    SUBQ.B  #2,zLineCount            ; Inform the pager about two newlines

    ; Prepare the array of bytes we'll use to track which spare table entries
    ; we've visited. Each entry in the array corresponds to an entry in the
    ; spare table. Its value is either $FF (we haven't visited that spare table
    ; entry) or the index of the first entry in the head pointer array (AKA the
    ; "1024-block chunk index") that caused us to visit that spare table entry.
    MOVEA.L #(zSectorTag+$214),A0    ; Start of the array
    CLR.W   D0                       ; Anticipating D0 being a loop counter
    MOVE.B  zSpares,D0               ; Number of entries in the array
    SUBQ.W  #1,D0                    ; Minus one to finish it as a loop counter
.a0 MOVE.B  #$FF,(A0)+               ; Copy $FF to this entry
    DBRA    D0,.a0                   ; On to the next entry

    ; Print allocated entries in the spare table.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARES ALLOCATED'>,pendl
    MOVEA.L #(zSectorTag+$A),A0      ; A0 to start of the head pointer array
    MOVEA.L #(zSectorTag+$96),A1     ; A1 to start of the heap
    MOVEA.L #(zSectorTag+$214),A2    ; A2 to start of visited entry array
    CLR.W   D0                       ; D0: loop over 1024-block chunk indices

.s0 MOVE.B  0(A0,D0.W),D1            ;   Head ptr for 1st 1024-block chunk to D1
    BCLR.L  #7,D1                    ;   Is there a spare here? +(Clear 8th bit)
    BNE     .s8                      ;   No, advance to the next chunk

    MOVE.B  D0,-(A7)                 ;   Yes, print out linked list
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' FROM LINKED LIST '>,hhx,qpendl
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sSpareHeadings
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

.s1 CLR.W   D2                       ;     Clear D2 word in anticipation of...
    MOVE.B  D1,D2                    ;     ...copy from D1, then update the...
    MOVE.B  D0,0(A2,D2.W)            ;     ...visited entry array, then *4...
    LSL.W   #2,D2                    ;     ...making it an index into the "heap"

    MOVE.B  D1,-(A7)                 ;     Print spare block number
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'   '>,hhx

    CLR.L   D1                       ;     To print LBA, start with empty D1
    MOVE.B  1(A1,D2.W),D1            ;     LBA bits 9..8 to D1 bits 1..0
    ROR.W   #2,D1                    ;     Rotate bits 9..8 to D1 bits 14..15
    MOVE.B  D0,D1                    ;     LBA bits 16..10 to D1 bits 6..0
    ROL.W   #2,D1                    ;     LBA bits 16..8 to D1 bits 8..0
    LSL.L   #8,D1                    ;     LBA bits 16..8 to D1 bits 16..8
    MOVE.B  2(A1,D2.W),D1            ;     LBA bits 7..0 to D1 bits 7..0
    MOVE.L  D1,-(A7)                 ;     Onto stack for printing, and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' . '>,3x

    BTST.B  #6,0(A1,D2.W)            ;     Is this spare block marked as used?
    BSR     .yn                      ;     Print yes or no
    BTST.B  #5,0(A1,D2.W)            ;     Is this spare block marked as usable?
    BSR     .yn                      ;     Print yes or no

    BTST.B  #4,0(A1,D2.W)            ;     What type of spare is this?
    BEQ.S   .s2                      ;     Skip ahead if a bad block
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' . SPARE     '>
    BRA.S   .s3                      ;     Skip ahead to data type
.s2 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' . BAD BLOCK '>

.s3 BTST.B  #3,0(A1,D2.W)            ;     Does the block hold spare table data?
    BEQ.S   .s4                      ;     No, skip ahead
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' . SPARE TABLE'>
    BRA     .s6                      ;     Done with table entry, print newline
.s4 BTST.B  #1,0(A1,D2.W)            ;     Does the block hold user data?
    BEQ.S   .s5                      ;     No, skip ahead
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' . USER DATA'>
    BRA.S   .s6                      ;     Done with table entry, print newline
.s5 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' . UNKNOWN'>
.s6 mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl

    BTST.B  #7,0(A1,D2.W)            ;     Any more spares for this chunk?
    BNE     .s8                      ;     No, all done, on to the next chunk

    MOVE.B  3(A1,D2.W),D1            ;     Next spare record pointer to D1
    CMP.B   zSpares,D1               ;     Let's make sure it's in bounds
    BLO     .s7                      ;     It's in bounds, skip ahead
    MOVE.L  0(A1,D2.W),-(A7)         ;     Not in bounds; print a warning
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sPointerOob
    mPrint  kCrtRow,kCrtCol,#kFirstCol,lx,qpendl
    BRA     .s8

.s7 ANDI.W  #$FF,D1                  ;     Prepare D1 to be used as an index
    CMPI.B  #$FF,0(A2,D1.W)          ;     Next record has been visited already?
    BEQ     .s1                      ;     No, repeat inner loop
    MOVE.L  0(A1,D2.W),-(A7)         ;     Yes; print a warning
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sPointerVisited
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl,<'    RAW RECORD-'>,lx,qpendl

.s8 ADDQ.W  #1,D0                    ;   On to the next 1024-block chunk
    CMPI.W  #128,D0                  ;   Have we seen them all?
    BLO     .s0                      ;   No, on to the next

    ; Print raw head pointer array data
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'RAW HEAD POINTER ARRAY'>
    mDump.B kCrtRow,kCrtCol,#kFirstCol,A0,zSpares,qpendl

    ; Print raw spare table data.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl,<'RAW SPARE TABLE DATA'>
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A1,zSpares,qpendl

    ; Print interleave map
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl,<'INTERLEAVE MAP'>
    mDump.B kCrtRow,kCrtCol,#kFirstCol,A1,zSectors,qpendl

    ; Print overall checksum for this sector
    MOVE.B  (A1)+,D0                 ; MSB of checksum into D0
    LSL.W   #8,D0                    ; Shift it to the MSB location
    MOVE.B  (A1)+,D0                 ; LSB of checksum into place
    MOVE.W  D0,-(A7)                 ; Checksum onto stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl,<'ENTIRE RECORD CHECKSUM-'>,hx

.rt RTS                              ; Return to caller

    ; Tiny subroutine that _SPAREPRINTWI uses to print YES or NO in the spare
    ; table readout for various flags.
.yn BEQ.S   .no
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' .   YES  '>
    RTS                              ; Return to caller
.no mPrint  kCrtRow,kCrtCol,#kFirstCol,<' .   NO   '>
    RTS                              ; Return to caller

    ; Tiny subroutine that allows _SPAREPRINTWI to compare drive parameters
    ; from sector $FFFFFE (the spare table) with their counterparts from
    ; sector $FFFFFF (loaded by WIDGETINFO).
.cm CMP.B   D0,D1
    BEQ     .rc
    MOVE.B  D1,-(A7)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'?'>,pendl
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'...SECTOR FFFFFF SAID IT WAS '>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx,pendl
.rc RTS                              ; Back to caller (i.e. _SPAREPRINTWI)


    PAGE
* NeoWidEx WIDGETINFO scratch data allocation ===============
    SECTION kSecScratch

    ; Have we run WIDGETINFO? $00 if not, anything else otherwise.
zHaveInfo:
    DC.B    0

    ; Is the disk a Widget?
    ; $00 -- No.
    ; $FF -- It's an ordinary 10MB Widget.
    ; $FE -- It's a "debug mode" 10MB Widget.
    ; $EF -- It's an "ordinary" 20MB Widget.
    ; $EE -- It's a "debug mode" 20MB Widget.
    ; $DF -- It's an "ordinary" 40MB Widget.
    ; $DE -- It's a "debug mode" 40MB Widget.
    ; Anything else -- dubious at best!
zIsWidgety:
    DC.B    0

    ; Points to the name WIDGETINFO has picked for the drive.
zDriveNamePtr:
    DC.L    0

    ; All remaining variables are disk parameters derived from reading the
    ; disk's own FFFFFF block.
    ;
    ; IMPORTANT: The contigous set of parameters starting at zNumBlocks and
    ; continuing through zSectors (for Widgets) or zSpares (for all other
    ; drives) is the "signature" of the disk's type. It is expected that these
    ; values will be the same for all disks of a particular type (e.g. all
    ; 10 MB Widgets) regardless of ROM version or block sparing/badness.
    ; These parameters will be compared byte-for-byte against the signatures
    ; defined in the strings section below.

zSignature:
    ; BEGIN SIGNATURE (((
zNumBlocks:
    DC.L    $FFFFFFFF                ; Number of blocks on disk
zBlockSize:
    DC.W    $FFFF                    ; Block size in bytes

zDeviceName:
    DCB.B   13,'d'                   ; 13-byte device name
    DC.B    0                        ; Null-terminator for the device name
zDeviceNum:
    DC.L    $00000000                ; Device number

zSpares:
    DC.B    $FF                      ; Number of spares available

    ; The following information is only retrievable from Widgets (for now?).
zHeads:
    DC.B    $FF                      ; Number of heads on disk
zCylinders:
    DC.W    $FFFF                    ; Number of cylinders on disk
zSectors:
    DC.B    $FF                      ; Number of sectors per cylinder
    ; ))) END SIGNATURE
zFmtOffset:
    DC.B    $FF                      ; Format offset
zFmtIntrl:
    DC.B    $FF                      ; Format interleave set

    ; Counts of spares and bad blocks detected by the diagnostics
zSparesInUse:
    DC.B    $FF                      ; Number of spares in use
zBadBlocks:
    DC.B    $FF                      ; Number of bad blocks

    ; Other information that may differ among drives of the same type.
    DS.W    0                        ; Word alignment
zFirmware:
    DC.W    $FFFF                    ; Disk firmware revision


    PAGE
* NeoWidEx WIDGETINFO strings ===============================
    SECTION kSecStrings

    ; What follows: "signature" record for the various kinds of drives that
    ; NeoWidEx knows about. "Pattern" regions in these records will be compared
    ; byte-for-byte against the drive signature variables in the scratch
    ; section (above).

    ; (While a checksum would have done just as well in the place of these
    ; records, it's hoped that having the actual data written out in this
    ; way will make the code more maintainable. Adding a new signature is
    ; easy: just insert it before sSigFallback. No further modification is
    ; required.)

    ; The format of a signature record is:
    ;   Byte 0 to Byte 1: Length of signature pattern in bytes (call this L).
    ;   Byte 2 to Byte L+2: Signature pattern region.
    ;   Byte L+3: Value to store in zIsWidgety if signature pattern matches.
    ;   Byte L+4 and on: Null terminated string name for this type of disk.
    ; Be CERTAIN to pad your record to word alignment with "DS.W 0"!

    DS.W    0                        ; Force word alignment
sSignatures:
    ; (Now if we wanted to, we could distinguish between "ordinary" and
    ; "debug mode" ProFiles, but (a) that information shows up in the firmware
    ; version, not the signature, and (b) we care about Widgets, not ProFiles.)

    ; Drive parameter signature for 5MB ProFile.
sSigProFile5:
    DC.W    (.zz-.aa)                ; Pattern length in bytes
.aa DC.L    $00002600                ; Number of blocks
    DC.W    $0214                    ; Block size in bytes
    DC.B    'PROFILE      ',0        ; Drive name + terminator
    DC.L    $00000000                ; Device ID
    DC.B    $20                      ; Number of spare sectors
.zz DC.B    0                        ; zIsWidgety value
    DC.B    '5 MB PROFILE',0         ; Our name for the device
    DS.W    0                        ; Pad to word alignment

    ; Drive parameter signature for LisaEm-emulated 5MB ProFile.
sSigLEMProFile5:
    DC.W    (.zz-.aa)
.aa DC.L    $00002600
    DC.W    $0214
    DC.B    'PROFILE     ',0,0       ; An extra null!
    DC.L    $00000000
    DC.B    $20
.zz DC.B    0
    DC.B    'LISAEM 5 MB PROFILE',0
    DS.W    0

    ; Drive parameter signature for 10MB ProFile.
sSigProFile10:
    DC.W    (.zz-.aa)
.aa DC.L    $00004C00
    DC.W    $0214
    DC.B    'PROFILE 10M',0,0,0
    DC.L    $00000010
    DC.B    $20
.zz DC.B    0
    DC.B    '10 MB PROFILE',0
    DS.W    0

    ; Drive parameter signature for 10MB Widget.
sSigWidget10:
    DC.W    (.zz-.aa)
.aa DC.L    $00004C00
    DC.W    $0214
    DC.B    'Widget-10    ',0
    DC.L    $00000100
    DC.B    $4C
    DC.B    $2                       ; Number of heads
    DC.W    $202                     ; Number of cylinders
    DC.B    $13                      ; Sectors per head
.zz DC.B    $FF
    DC.B    '10 MB WIDGET',0
    DS.W    0

    ; Drive parameter signature for 20MB Widget.
sSigWidget20:
    DC.W    (.zz-.aa)
.aa DC.L    $00009800
    DC.W    $0214
    DC.B    'Widget-20    ',0
    DC.L    $00000110
    DC.B    $4C
    DC.B    $2
    DC.W    $202
    DC.B    $26
.zz DC.B    $EF
    DC.B    '20 MB WIDGET',0
    DS.W    0

    ; Drive parameter signature for 40MB Widget.
sSigWidget40:
    DC.W    (.zz-.aa)
.aa DC.L    $00013000
    DC.W    $0214
    DC.B    'Widget-40    ',0
    DC.L    $00000120
    DC.B    $4C
    DC.B    $2
    DC.W    $404
    DC.B    $26
.zz DC.B    $DF
    DC.B    '40 MB WIDGET',0
    DS.W    0

    ; Drive parameter signature for 10MB Widget with debug firmware.
sSigWidget10Dbg:
    DC.W    (.zz-.aa)
.aa DC.L    $00004C00
    DC.W    $0214
    DC.B    'Widget-10    ',0
    DC.L    $00000101
    DC.B    $4C
    DC.B    $2
    DC.W    $202
    DC.B    $13
.zz DC.B    $FE
    DC.B    '10 MB DEBUG WIDGET',0
    DS.W    0

    ; Drive parameter signature for 20MB Widget with debug firmware.
sSigWidget20Dbg:
    DC.W    (.zz-.aa)
.aa DC.L    $00009800
    DC.W    $0214
    DC.B    'Widget-20    ',0
    DC.L    $00000111
    DC.B    $4C
    DC.B    $2
    DC.W    $202
    DC.B    $26
.zz DC.B    $EE
    DC.B    '20 MB DEBUG WIDGET',0
    DS.W    0

    ; Drive parameter signature for 40MB Widget with debug firmware.
sSigWidget40Dbg:
    DC.W    (.zz-.aa)
.aa DC.L    $00013000
    DC.W    $0214
    DC.B    'Widget-40    ',0
    DC.L    $00000121
    DC.B    $4C
    DC.B    $2
    DC.W    $404
    DC.B    $26
.zz DC.B    $DE
    DC.B    '40 MB DEBUG WIDGET',0
    DS.W    0

    ; Fallback signature: will match any drive. Must come last!
sSigFallback:
    DC.W    0
    DC.B    0                        ; Whatever it is, it's not Widgety
    DC.B    'UNKNOWN DRIVE TYPE',0

sStatusBitmap:
    DC.B    '                -BYTE 0-                         -BYTE 1-',$0D
    DC.B    ' NON-55 RESPONSE FROM HOST-~           SPARE TABLE OVERFLOW-u',$0D
    DC.B    '     WRITE BUFFER OVERFLOW-}    5 OR FEWER SPARES AVAILABLE-t',$0D
    DC.B    '                READ ERROR-z   CONTROLLER SELF-TEST FAILURE-r',$0D
    DC.B    '  NO MATCHING HEADER FOUND-y       SPARE TABLE JUST UPDATED-q',$0D
    DC.B    ' UNRECOVERABLE SERVO ERROR-x   SEEK TO WRONG TRACK OCCURRED-p',$0D
    DC.B    '     LAST OPERATION FAILED-w     CONTROLLER ABORTED LAST OP-o',$0D
    DC.B    $0D
    DC.B    '                -BYTE 2-                         -BYTE 3-',$0D
    DC.B    '   JUST DID POWER-ON RESET-n    ECC CIRCUIT SAYS READ ERROR-f',$0D
    DC.B    '   LAST BLOCK OUT OF RANGE-m    CRC CIRCUIT SAYS READ ERROR-e',$0D
    DC.B    '                                HEADER TIMEOUT ON LAST READ-d',$0D
    DC.B    '                                   UNSUCCESSFUL RETRY COUNT-',0

sSpareBitmap1:
    DC.B    '   ~}|{zyxw vutsrqpo nmlkjihg fedcba`_',0
sSpareBitmap2:
    DC.B    ' ~}|{zyxw vutsrqpo',$0D,'   nmlkjihg fedcba`_',0
sSpareBitmap3:
    DC.B    ' ~}|{zyxw vutsrqpo',$0D,0
sSpareHeadings:
    DC.B    '  NUM .  LBA   . IN USE  . USEABLE . SPARE TYPE . CONTENTS',0
sPointerOob:
    DC.B    '    NEXT ENTRY INDEX OUT OF BOUNDS. RAW RECORD-',0
sPointerVisited:
    DC.B    '    NEXT ENTRY INDEX IS FOR AN ENTRY WE ALREADY VISITED',0


** (Back to the code section) **
    SECTION kSecCode




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
