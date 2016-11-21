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
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- DRIVE INFO ---'>,endl

    MOVE.L  zDriveNamePtr,-(A7)      ; Drive type string pointer onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,<'.'>,endl

    MOVE.L  #zDeviceName,-(A7)       ; Drive device name pointer onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DEVICE NAME-/'>,s,<'/.'>
    MOVE.L  zDeviceNum,-(A7)         ; Drive device number onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  NUMBER-'>,3x,<'. '>
    TST.B   zIsWidgety               ; Did we decide this was a Widget?
    BNE     .yw                      ; Yes, say so
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  NOT A WIDGET.'>,endl
    BRA     .bi                      ; No; print above, skip ahead
.yw mPrint  kCrtRow,kCrtCol,#kFirstCol,<' SEEMS WIDGETY.'>,endl

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
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<'TRACKS-'>,hx

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
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  INTERLEAVE FACTOR-'>,hhx,endl

    ; Print number of spares in use
.s0 TST.B   zSparesInUse             ; Are any spares in use?
    BNE.S   .s1                      ; Yes, skip ahead to say how many
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO SPARES IN USE'>,endl
    BRA     .b0                      ; Jump ahead to print bad blocks in use
.s1 MOVE.B  zSparesInUse,-(A7)       ; Drive spares-in-use count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARES IN USE-'>,hhx,endl

    ; Print number of bad blocks
.b0 TST.B   zBadBlocks               ; Are there any bad blocks?
    BNE.S   .b1                      ; Yes, skip ahead to say how many
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'NO BAD BLOCKS'>,endl
    BRA     .rt                      ; Jump ahead to print bad blocks in use
.b1 MOVE.B  zBadBlocks,-(A7)         ; Drive spares-in-use count onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCKS-'>,hhx,endl

.rt RTS                              ; Back to the caller


    ; SPAREPRINT -- Read and print the spare table
    ; Args:
    ;   (none)
    ; Notes:
    ;   Runs WIDGETINFO if it hasn't been run yet, and in that case, has all
    ;       of WIDGETINFO's side effects.
SPAREPRINT:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if needed
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SPARE TABLE ---'>,endl
    TST.B   zIsWidgety               ; Is this a Widget or a ProFile?
    BEQ.S   _SPAREPRINTPR            ; It's a ProFile; jump to specialised code
    BRA     _SPAREPRINTWI            ; It's a Widget; jump to specialised code

_SPAREPRINTPR:
    ; Load the ProFile's spare table.
    MOVE.L  #$00FFFFFF,D1            ; Sector ID for the ProFile spare table
    BSR     SECTOR                   ; Read the spare table
    BCS     .rt                      ; Jump to return on error

    ; Set A0 to the start of the spare table.
    MOVEA.L #(zSectorTag+$1A),A0     ; Spare table is 26 bytes in

    ; Print table of spared blocks.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARE TABLE--'>,endl
    CLR.W   D0                       ; Blank D0 word for DBEQ below
    MOVE.B  zSparesInUse,D0          ; Spare count into D0
    BEQ     .s3                      ; No spares? Skip to consume terminator
    SUBQ.B  #1,D0                    ; Subtract 1 to make D0 a loop iterator
.s1 m_cp3b  A0,D1                    ; Next spared sector into D1...
    MOVE.L  D1,-(A7)                 ; ...and onto the stack
    CMPI.W  #(kFirstCol+56),kCrtCol  ; Do we need a CR?
    BLO.S   .s2                      ; No, print the entry
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a CR first
.s2 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,3x  ; Print space and entry
    ADDQ.L  #3,A0                    ; On to the next spare table entry
    DBEQ    D0,.s1                   ; Iterate till done with spares
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Follow table print with a CR

    ; Check that the spare table ends with an $FFFFFF entry.
.s3 m_cp3b  A0,D1                    ; Get what should be the terminator
    CMP.L   #$00FFFFFF,D1            ; Is it the terminator?
    BEQ     .s4                      ; Yes, carry on
    MOVE.L  D1,-(A7)                 ; No, get ready to print it
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'SPARE TABLE ENDS WITH '>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' AND NOT FFFFFF? ODD...'>,endl
.s4 ADDQ.L  #3,A0                    ; Advance to the bad block table

    ; Print table of bad blocks.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCK TABLE--'>,endl
    CLR.W   D0                       ; Blank D0 word for DBEQ below
    MOVE.B  zBadBlocks,D0            ; Bad block count into D0
    BEQ     .b3                      ; No bad blocks? Skip to consume terminator
    SUBQ.B  #1,D0                    ; Subtract 1 to make it a loop iterator
.b1 m_cp3b  A0,D1                    ; Next bad block into D1...
    MOVE.L  D1,-(A7)                 ; ...and onto the stack
    CMPI.W  #(kFirstCol+56),kCrtCol  ; Do we need a CR?
    BLO.S   .b2                      ; No, print the entry
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a CR first
.b2 mPrint  kCrtRow,kCrtCol,#kFirstCol,<' '>,3x  ; Print space and entry
    ADDQ.L  #3,A0                    ; On to the next bad block table entry
    DBEQ    D0,.b1                   ; Iterate till done with bad blocks
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Follow table print with a CR

    ; Check that the bad block tabel ends with an $FFFFFF entry.
.b3 m_cp3b  A0,D1                    ; Get what should be the terminator
    CMP.L   #$00FFFFFF,D1            ; Is it the terminator?
    BEQ     .rt                      ; Yes, carry on
    MOVE.L  D1,-(A7)                 ; No, get ready to print it
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'BAD BLOCK TABLE ENDS WITH '>,3x
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' AND NOT FFFFFF? ODD...'>,endl

.rt RTS                              ; Back to SPAREPRINT's caller

_SPAREPRINTWI:
    ; Load the Widget's spare table.
    MOVE.L  #$00FFFFFE,D1            ; Sector ID for the Widget spare table
    BSR     SECTOR                   ; Read the spare table
    BCS     .rt                      ; Jump to return on error

.rt RTS                              ; Back to SPAREPRINT's caller


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
    DC.B    $FF                      ; Format interleave

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


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
