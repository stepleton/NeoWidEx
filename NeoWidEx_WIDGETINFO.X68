*-----------------------------------------------------------
* Title      : NeoWidEx_WIDGETINFO
* Written by : Tom Stepleton
* Date       : 08 November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: the WIDGETINFO subroutine.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Certain scratch data locations must be defined.
*-----------------------------------------------------------


* NeoWidEx WIDGETINFO code =================================

    ; WIDGETINFO -- Display information from the "spare table" sector
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes registers: D0-D2/A0.
WIDGETINFO:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- DRIVE INFO ---'>,endl

    ; Load the Widget's spare table.
    MOVE.L  #$00FFFFFF,D1            ; Sector ID for Widget spare table
    BSR     SECTOR                   ; Read the spare table
    BCS     .rt                      ; Jump to return on error

    ; Copy the first 13 bytes (the device name) to zNumToStr (even though it's
    ; not a number) and null-terminate. Then print.
    mMemCpy #zSectorTag,#zNumToStr,#$D   ; Do copy
    CLR.B   (zNumToStr+$D)           ; Null-terminate
    MOVE.L  #zNumToStr,-(A7)         ; String address to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DEVICE NAME-/'>,s,<'/.'>

    ; Load and print device number.
    m_cp3b  #(zSectorTag+$D),D0      ; Load device number
    MOVE.L  D0,-(A7)                 ; Copy onto stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  NUMBER-'>,3x,<'. '>

    ; Say whether this is a widget.
    CMPI.L  #$00000100,D0            ; Widget device number?
    BEQ     .yw                      ; Yes, say so
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  NOT A WIDGET.'>,endl
    BRA     .bi                      ; No; print above, skip ahead
.yw mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SEEMS WIDGETY.'>,endl
    NOT.B   zIsWidgety               ; Mark that this is a widget

    ; Print basic information about the drive.
.bi MOVEA.L #(zSectorTag+$10),A0     ; Address for firmware revision number...
    MOVE.W  (A0)+,-(A7)              ; ...and onto the stack, and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'REV-'>,hx

    m_cp3b  A0,D0                    ; Blocks on the device into D0...
    MOVE.L  D0,-(A7)                 ; ...and onto the stack, and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'     BLOCKS-'>,3x
    ADDQ.L  #2,A0                    ; A0 to 1 byte before end of block count

    MOVE.L  (A0),D0                  ; Middle two bytes are sector size...
    LSR.L   #8,D0                    ; ...shift to the lower two bytes...
    MOVE.W  D0,-(A7)                 ; ...and onto the stack, and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'     BLOCKSIZE-'>,hx
    ADDQ.L  #3,A0                    ; A0 ahead to the spare count

    ; Widget-specific information about the drive.
    TST.B   zIsWidgety               ; Widgets have additional header info
    BEQ     .sp                      ; This is no Widget, so nevermind

    MOVE.W  (A0)+,D0                 ; Number of cylinders (or tracks) to D0...
    MOVE.W  D0,zCylinders            ; ...and into memory for safekeeping...
    MOVE.W  D0,-(A7)                 ; ...and onto the stack too, and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<'TRACKS-'>,hx

    MOVE.B  (A0)+,D0                 ; Number of heads to D0...
    MOVE.B  D0,zHeads                ; ...and into memory for safekeeping...
    MOVE.B  D0,-(A7)                 ; ...and onto the stack too, and print
    mPrint  kCrtRow,kCrtRow,#kFirstCol,<'  HEADS-'>,hhx

    MOVE.B  (A0)+,D0                 ; Number of sectors per track to D0...
    MOVE.B  D0,zSectors              ; ...and into memory for safekeeping...
    MOVE.B  D0,-(A7)                 ; ...and onto the stack too, and print
    mPrint  kCrtRow,kCrtRow,#kFirstCol,<'  SECTORS-'>,hhx

    ADDQ.L  #2,A0                    ; Advance past two mystery 0 bytes
    ; For pretty text alignment, we pull the cursor backward two spaces:
    SUBQ.W  #2,kCrtCol               ; Note that only Widgets cause this

    ; And back to basic information about the drive.
.sp ADDQ.W  #2,kCrtCol               ; Advance cursor two spaces
    MOVE.B  (A0)+,D1                 ; Number of spares into D1 for later...
    MOVE.B  D1,zSpares               ; ...and into memory for safekeeping...
    MOVE.B  D1,-(A7)                 ; ...and onto the stack too, and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'   SPARES-'>,hhx,endl

    ; Make sure spare table size is sensible. 83 is a conservative comparison
    ; value deriving from the fact that there would not be enough space in the
    ; rest of the sector to list 83 spare blocks and 83 bad blocks.
    CMPI.B  #83,D1                   ; Do we have more than 83 "spares"?
    BLS.S   .s0                      ; No, it's safe to carry on
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'PREPOSTEROUS SPARE TABLE SIZE... GIVING UP.'>,endl
    BRA     .rt                      ; Yes, print above message and return

    ; Print table of spared blocks.
.s0 MOVEA.L #(zSectorTag+$1A),A0     ; A0 points to spare table first entry
    CLR.W   D0                       ; Clear D0 word
    MOVE.B  (zSectorTag+$18),D0      ; Allocated spares count to D0 lower byte
    BNE     .s1                      ; Skip to spare table dump if any in use
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO SPARES IN USE'>,endl
    BRA     .s8                      ; No spares used, skip to terminator check
.s1 MOVE.B  D0,-(A7)                 ; Used spares count-->stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARES IN USE-'>,hhx,endl
    CMPI.B  #$A7,D0                  ; Used spares count is implausible?
    BLS     .s2                      ; No, carry on
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'PREPOSTEROUS NUMBER OF SPARES IN USE... GIVING UP.'>,endl
    BRA     .rt                      ; Yes, print above message and return
.s2 CMP.B   D1,D0                    ; Used spares count exceeds # of spares?
    BLS     .s3                      ; No, carry on
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'MORE THAN THE NUMBER OF SPARE SECTORS ON DISK? ODD...'>,endl
.s3 SUBQ.B  #1,D0                    ; Decrement used spares for looping
.s4 m_cp3b  A0,D2                    ; Next spare table entry into D2...
    MOVE.L  D2,-(A7)                 ; ...and onto the stack
    CMPI.W  #(kFirstCol+56),kCrtCol  ; Do we need a CR?
    BLO.S   .s5                      ; No, print the entry
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a CR first
.s5 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,3x  ; Print space and entry
    ADDQ.L  #3,A0                    ; On to the next spare table entry
    DBEQ    D0,.s4                   ; Iterate till done with spares
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Follow table print with a CR

    ; Check that the spare table ends with an $FFFFFF entry.
.s8 m_cp3b  A0,D2                    ; Get what should be the terminator
    CMP.L   #$00FFFFFF,D2            ; Is it the terminator?
    BEQ     .s9                      ; Yes, carry on
    MOVE.L  D2,-(A7)                 ; No, get ready to print it
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARE TABLE ENDS WITH '>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' AND NOT FFFFFF? ODD...'>,endl
.s9 ADDQ.L  #3,A0                    ; Advance to the bad block table

    ; Print table of bad blocks.
    ; A0 already points to bad block table first entry; there is no .b0
    CLR.W   D0                       ; Clear D0 word
    MOVE.B  (zSectorTag+$19),D0      ; Bad block count to D0 lower byte
    BNE     .b1                      ; Skip to bad block dump if any in use
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO BAD BLOCKS'>,endl
    BRA     .b5                      ; No bad blocks, skip to return
.b1 MOVE.B  D0,-(A7)                 ; Bad block count-->stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCKS-'>,hhx,endl
    CLR.W   D2                       ; Clear D2 word
    MOVE.B  (zSectorTag+$18),D2      ; Allocated spares count to D2 lower byte
    ADD.W   D0,D2                    ; Add bad block count to D2
    CMPI.W  #$A7,D2                  ; More than the space for both tables?
    BLS     .b2                      ; No, carry on
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'TOO LITTLE ROOM LEFT FOR A TABLE THAT BIG...'>,endl
    MOVE.W  #$A7,D0                  ; Max table size sum into D0
    SUB.B   (zSectorTag+$18),D0      ; Subtract size of spares table
    MOVE.B  D0,-(A7)                 ; Copy to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SHOWING JUST '>,hhx,<' ENTRIES INSTEAD.'>,endl
.b2 SUBQ.B  #1,D0                    ; Decrement used spares for looping
.b3 m_cp3b  A0,D2                    ; Next bad block into D2...
    MOVE.L  D2,-(A7)                 ; ...and onto the stack
    CMPI.W  #(kFirstCol+56),kCrtCol  ; Do we need a CR?
    BLO.S   .b4                      ; No, print the entry
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a CR first
.b4 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,3x  ; Print space and entry
    ADDQ.L  #3,A0                    ; On to the next spare table entry
    DBEQ    D0,.b3                   ; Iterate till done with bad blocks
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Follow table print with a CR

    ; Check that the bad block table ends with an $FFFFFF entry.
.b5 m_cp3b  A0,D2                    ; Get what should be the terminator
    CMP.L   #$00FFFFFF,D2            ; Is it the terminator?
    BEQ     .rt                      ; Yes, carry on
    MOVE.L  D2,-(A7)                 ; No, get ready to print it
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCK TABLE ENDS WITH '>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' AND NOT FFFFFF? ODD...'>,endl

    ; All done!
.rt RTS                              ; Return to caller


    PAGE
* NeoWidEx UI scratch data allocation =======================
    SECTION kSecScratch

zIsWidgety:
    DC.B    0                        ; Is the disk a Widget?

zSpares:
    DC.B    $FF                      ; Number of spares available.
zCylinders:
    DC.W    $FFFF                    ; Number of cylinders on disk.
zHeads:
    DC.B    $FF                      ; Number of heads on disk.
zSectors:
    DC.B    $FF                      ; Number of sectors per cylinder.


** (Back to the code section) **
    SECTION kSecCode
