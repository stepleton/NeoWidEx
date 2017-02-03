*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Date       : XX January 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Disk data buffer manipulation routines.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_UI must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx disk data buffer code ===========================

    ; BUFFER -- UI for manipulating the disk data buffer
    ; Args:
    ;   (none)
    ; Notes:
    ;   A "sub-UI" with its own menu and everything.
    ;   Probably destroys most registers; depends on what user chooses to do.
    ;   Will not trash beyond D0-D4/A0-A4.
BUFFER:
    mMenuUi #sBufferMenu,#dBufferMenuHandlers  ; Buffer menu UI loop
    RTS                              ; Return to the main menu

    ; _RAWSHOW -- Display hex dump of data in the disk data buffer, with CRC
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D2/D5/A0-A1.
_RAWSHOW:
    ; Do setup and print header
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- DISK BUFFER CONTENTS ---'>
    LEA     zSectorTag,A0            ; Starting address of buffer
    CLR.B   D5                       ; Count up through sectors in buffer

    ; Loop over sectors in buffer
.lp mResetP                          ;   Reset paging for this new sector
    ADDQ.B  #1,D5                    ;   Sector count is 1-indexed, so increment
    MOVEA.L A0,A1                    ;   Save sector starting address for CRC
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'RAW TAG DATA'>  ; delib. not qpendl
    BSR     _SECTSUFFIX              ;   Say which sector's tag data
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A0,z_BufferTagLongs,qpendl
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl,<'RAW SECTOR DATA'>
    BSR     _SECTSUFFIX              ;   Say which sector's sector data
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A0,z_BufferSectorLongs,qpendl
    ; Compute CRC of tag and data
    MOVEA.L A1,A0                    ;   The CRC calculation starts here
    BSR     _SECTSIZED2              ;   Size of memory to scan in longs to D2
    LSL.W   #2,D2                    ;   Convert size to bytes
    BSR     _CRC                     ;   Calculate CRC now
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl  ; qpendl needs an empty stack
    MOVE.W  D0,-(A7)                 ;   Copy CRC onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'TAG/SECTOR CRC16-'>,hx
    ; See if we're done, loop again if not
    CMP.B   z_BufferNumSectors,D5    ;   All done with looping over sectors?
    BHS.S   .rt                      ;   Yes, jump to exit
    MOVE.B  #1,zLineCount            ;   No, force the pager to pause output
    mPrint  kCrtRow,kCrtCol,#kFirstCol,qpendl
    BRA     .lp                      ;   Round again for another go

.rt RTS                              ; Back to caller

    ; _CRC -- Compute 16-bit CRC of some data region
    ; Args:
    ;   D2: Word counting number of bytes of memory region to scan
    ;   A0: Points to start of memory region to scan
    ; Notes:
    ;   When finished, A0 points just past the memory region scanned
    ;   Trashes D0-D2/A0.
    ;   Computed CRC goes in D0.
_CRC:
    CLR.W   D0                       ; Initialise CRC with zeroes
    TST.W   D2                       ; What if the caller said: scan no bytes?
    BEQ.S   .rt                      ; No bytes left to scan? Return
    SUBQ.W  #1,D2                    ; Make D2 into a loop counter
.lo MOVE.B  (A0)+,D1                 ;   Copy next byte into A0
    LSL.W   #8,D1                    ;   Shift it left into word's MSByte
    EOR.W   D1,D0                    ;   XOR the result with the CRC
    MOVE.W  #7,D1                    ;   Repeat this next loop eight times
.li LSL.W   #1,D0                    ;     Left-shift the CRC one bit
    BCC.S   .db                      ;     If a bit fell off when we did that...
    EORI.W  #$1021,D0                ;     ...XOR this magic number with the CRC
.db DBRA    D1,.li                   ;     Repeat for the next bit
    DBRA    D2,.lo                   ;   Repeat outer loop for next byte
.rt RTS                              ; Back to caller

    ; _SPARESHOW - Parse buffer as a spare table, and print
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D5/A0-A4.
_SPARESHOW:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- BUFFER AS SPARE TABLE ---'>
    LEA     s_ShowAsSprTblForm,A0    ; Prepare FORM args; address of template...
    LEA     s_ShowAsSprTblPrompts,A1   ; ...address of prompt pointer array...
    SUBA.L  A2,A2                    ; ...defaulting to N for the form value...
    SUBA.L  A3,A3                    ; ...and no bounds specified.
    BSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, jump ahead to parse and print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller
.go mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; SPAREPRINT?? need a newline first.
    mResetP                          ; Reset paging (only needed for Widget)
    TST.B   (3+zFieldValues)         ; Did user want a ProFile spare dump?
    BNE.S   .pr                      ; Yes, jump to print it
    BSR     SPAREPRINTWI             ; No, parse/print buf as Widget spare table
    RTS                              ; Back to caller
.pr BSR     SPAREPRINTPR             ; Parse/print buffer as ProFile spare table
    RTS                              ; Back to caller

    ; _EDIT -- Edit tag and sector information
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D5/A0-A4.
    ;   Cancelling _EDIT (by typing 'q' in a form) only prevents inputs from
    ;       the current form from being committed to memory. All previous form
    ;       inputs will have already been saved.
_EDIT:
    ; Do setup and print header
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- EDIT BUFFER DATA ---'>
    LEA     zSectorTag,A1            ; We start at the beginning of the buffer
    CLR.B   D5                       ; Count up through sectors in buffer

    ; Loop over sectors in buffer
.lp ADDQ.B  #1,D5                    ;   Sector count is 1-indexed, so increment
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'EDIT SECTOR TAG'>
    BSR     _SECTSUFFIX              ;   Say which sector's tag data
    MOVE.B  z_BufferTagLongs,D0      ;   A sector tag has this many longwords
    CLR.W   D1                       ;   (For printing) Editing starts at byte 0
    BSR     _EDITMEM                 ;   Edit the sector tag
    TST.B   zFormIntent              ;   Did the user cancel?
    BEQ.S   .qt                      ;   Yes: abort, with printed caveat
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'EDIT SECTOR DATA'>
    BSR     _SECTSUFFIX              ;   Say which sector's sector data
    MOVE.B  z_BufferSectorLongs,D0   ;   Sector data has this many longwords
    CLR.W   D1                       ;   (For printing) Editing starts at byte 0
    BSR     _EDITMEM                 ;   Edit the sector data
    TST.B   zFormIntent              ;   Did the user cancel?
    BEQ.S   .qt                      ;   Yes: abort, with printed caveat
    ; See if we're done, loop again if not
    CMP.B   z_BufferNumSectors,D5    ;   All done with looping over sectors?
    BNE     .lp                      ;   No, loop again for the next sector
    RTS                              ; Yes, back to caller

.qt mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_AbortEdit   ; Ack quit intent
    RTS                              ; Back to caller

    ; _EDITMEM -- Helper to _EDIT, mainly: edit a memory region
    ; Args:
    ;   D0: (byte) Size of the memory region to edit in longwords
    ;   D1: (word) For printing---bytes being edited will be said to start
    ;       from this position, in bytes
    ;   A1: Start of memory region to edit
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   Behaviour is undefined if D0 is 0.
    ;   Prints nothing if the routine exits normally after editing the entire
    ;       region; prints nothing if user has stopped editing early by typing
    ;       'q'. Check zFormIntent to see which: if 0, early cancellation.
    ;   Cancelling _EDITMEM (by typing 'q' in a form) only prevents inputs from
    ;       the current form from being committed to memory. All previous form
    ;       inputs will have already been saved.
    ;   When finished, A1 points just past last memory region that was changed.
_EDITMEM:
    ; Prepare; how many longwords are there to edit?
    MOVE.L  A1,-(A7)                 ; Save memory region address on stack
    MOVE.L  A1,A2                    ; And copy to A2 to be FORM initial values
    CLR.W   D2                       ; Prepare for D2 to be a table offset
    MOVE.B  D0,D2                    ; Copy in longs left to edit
    CMPI.B  #4,D2                    ; Is it more than four?
    BLS.S   .ed                      ; Yes, skip past the next line
    MOVE.B  #4,D2                    ; No, limit longs to edit to four

    ; Edit this next batch of longwords
.ed MOVE.W  D0,-(A7)                 ; Save sizing info in registers to stack
    MOVE.W  D1,-(A7)
    MOVE.W  D2,-(A7)
    LSL.B   #2,D2                    ; Convert D2 from longwords to bytes
    ; This clumsy interlude to print which bytes we're editing
    ADD.W   D2,D1                    ; The number of the last byte we'll edit...
    SUBQ.W  #1,D1                    ; ...is D2+D1-1
    MOVE.W  D1,-(A7)                 ; Onto stack for printing
    SUB.W   D2,D1                    ; And now to restore the number of the...
    ADDQ.W  #1,D1                    ; ...first byte we'll edit
    MOVE.W  D1,-(A7)                 ; Onto stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,' BYTES '>,hx,<'-'>,hx
    ; Another clumsy interlude to customise form prompts, which trashes D0-D1
    MOVEA.L #(21+z_EditPrompts),A4   ; "Customisable area" of first prompt to A4
    MOVE.W  D1,D0                    ; HEXW2STR needs its argument to be in D0
    MOVE.W  #3,D1                    ; We'll repeat the following four times
.fp BSR     HEXW2STR                 ; Build string representation of D0
    mMemCpy A3,A4,#4                 ; Copy string representation to prompt
    ADDQ.W  #4,D0                    ; Update D0 for the next prompt
    ADDA.W  #10,A4                   ; Move to the next "customisable area"
    DBRA    D1,.fp                   ; Loop to update the next prompt
    ; Back to the editing
    SUBQ.B  #4,D2                    ; Make D2 a memory offset: subtract four
    LEA     s_LongsForms,A0          ; Form pointer array base to A0
    MOVEA.L 0(A0,D2.W),A0            ; Get form template address in A0, then...
    LEA     z_EditPrompts,A1         ; ...address of prompt pointer array...
    SUBA.L  A3,A3                    ; ...A2 already set, and no bounds in A3
    BSR     FORM                     ; Launch the form
    ; Back from form, restore registers, did user want to cancel?
    MOVE.W  (A7)+,D2                 ; Restore sizing info on stack to registers
    MOVE.W  (A7)+,D1
    MOVE.W  (A7)+,D0
    MOVE.L  (A7)+,A1                 ; Restore memory region address from stack
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .rt                      ; Yes, jump ahead to quit

    ; Update sizing information and copy data
    SUB.B   D2,D0                    ; Update number of longwords left to edit
    LSL.B   #2,D2                    ; Compute the number of bytes just edited
    mMemCpy #zFieldValues,A1,D2      ; Copy that many bytes from form to memory
    ADD.W   D2,D1                    ; Update byte position for printing
    ADDA.W  D2,A1                    ; Point A1 just past region just edited
    TST.B   D0                       ; Did we run out of memory left to copy?
    BNE     _EDITMEM                 ; Nope, so go around again!

.rt RTS                              ; Back to caller

    ; _PATTERN -- Fill the data buffer with a user-specified pattern
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
_PATTERN:
    ; First we ask the user for the pattern length
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- PATTERN FILL ---'>
    LEA     s_LongsToEditForm,A0     ; Prepare FORM args; address of template...
    LEA     s_LongsToEditPrompts,A1  ; ...address of prompt pointer array...
    LEA     z_LongsToEdit,A2         ; ...address of initial values array...
    LEA     d_LongsToEditBounds,A3   ; ...and you can't edit over 4 at a time
    BSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, jump ahead to quit

    ; Copy user selection to the initial values array
    MOVE.L  zFieldValues,z_LongsToEdit   ; Did user select a length of 0?
    BEQ     .qt                      ; Yes, jump ahead to quit

    ; Next we ask the user for a fill pattern
    MOVE.L  z_LongsToEdit,D0         ; Prepare FORM args; which template?
    SUBQ.B  #1,D0                    ; First, form length to array index...
    LSL.B   #2,D0                    ; ...times four for longword offsets
    LEA     s_LongsForms,A0          ; Form pointer array base to A0
    MOVEA.L 0(A0,D0.W),A0            ; Finally, get template address, then...
    LEA     s_LongsPrompts,A1        ; ...address of prompt pointer array...
    LEA     z_PatternInitialVals,A2  ; ...address of initial values array...
    SUBA.L  A3,A3                    ; ...and pattern values have no bounds!
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'ENTER PATTERN'>
    BSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, jump ahead to quit

    ; Copy form values to initial values, saving them for next time
    mMemCpy #zFieldValues,#z_PatternInitialVals,#$10

    ; Now fill the buffer with a nice unrolled loop
    LEA     zSectorTag,A0            ; A0 will iterate through the buffer
    MOVE.B  z_BufferNumSectors,D3    ; Number of sectors in buffer to D3
    MOVE.L  z_LongsToEdit,D1         ; Pattern size into D1

.lo BSR     _SECTSIZED2              ;   Number of longwords to fill to D2
.li LEA     z_PatternInitialVals,A1  ;     Refresh pattern start into A1
    MOVE.B  D1,D0                    ;     Refresh pattern size into D0

    MOVE.L  (A1)+,(A0)+              ;     Copy first pattern long
    SUBQ.W  #1,D2                    ;     Decrement long count
    BEQ.S   .br                      ;     All done with sector? See what's next
    SUBQ.B  #1,D0                    ;     Decrement longs left in pattern
    BEQ.S   .li                      ;     Pattern over? Back up to restart it

    MOVE.L  (A1)+,(A0)+              ;     Copy second pattern long
    SUBQ.W  #1,D2                    ;     Decrement long count
    BEQ.S   .br                      ;     All done with sector? See what's next
    SUBQ.B  #1,D0                    ;     Decrement longs left in pattern
    BEQ.S   .li                      ;     Pattern over? Back up to restart it

    MOVE.L  (A1)+,(A0)+              ;     Copy third pattern long
    SUBQ.W  #1,D2                    ;     Decrement long count
    BEQ.S   .br                      ;     All done with sector? See what's next
    SUBQ.B  #1,D0                    ;     Decrement longs left in pattern
    BEQ.S   .li                      ;     Pattern over? Back up to restart it

    MOVE.L  (A1)+,(A0)+              ;     Copy fourth pattern long
    SUBQ.W  #1,D2                    ;     Decrement long count
    BEQ.S   .br                      ;     All done with sector? See what's next
    BRA.S   .li                      ;     And another round through the pattern

.br SUBQ.B  #1,D3                    ;   Decrement sectors; all done?
    BNE.S   .lo                      ;   No, on to the next sector
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Return to caller

.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Ack quit intent
    RTS                              ; Back to caller

    ; _RANDOM -- Fill the data buffer with pseudo-random data
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
_RANDOM:
    ; First we ask the user for a random seed
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- RANDOM FILL ---'>
    LEA     s_RandomForm,A0          ; Prepare FORM args: address of template...
    LEA     s_RandomPrompts,A1       ; ...address of prompt pointer array...
    LEA     d_RandomInitialVals,A2   ; ...address of initial values array...
    LEA     d_RandomBounds,A3        ; ...address of value bounds array
    BSR     FORM                     ; Launch the form

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, go ahead with seeking
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Perform random fill and return to caller
.go MOVE.L  zFieldValues,D0          ; Copy random seed to D0
    NOT.W   D0                       ; Invert its bits
    LEA     zSectorTag,A0            ; Starting address for fill
    MOVE.B  z_BufferNumSectors,D4    ; Number of sectors to fill
.lp BSR     _SECTSIZED2              ;   Size of memory to fill in longs to D2
    LSL.W   #2,D2                    ;   Convert longwords to bytes
    BSR     _LFSRFILL                ;   Call random filler
    SUBQ.B  #1,D4                    ;   Decrement sectors; all done?
    BNE.S   .lp                      ;   No, on to the next sector
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    ; _LFSRFILL -- Fill a memory region with LFSR-generated random data
    ; Args:
    ;   D0: LFSR initial value; must not be $0000
    ;   D2: Word counting number of bytes to fill
    ;   A0: Points to start of memory region to fill
    ; Notes:
    ;   http://en.wikipedia.org/wiki/Linear-feedback_shift_register#Galois_LFSRs
    ;   When finished, A0 points just past the memory region filled
    ;   Trashes D0-D3/A0.
_LFSRFILL:
    TST.W   D2                       ; What if caller didn't want any bytes?
.lo BEQ.S   .rt                      ;   No bytes left to fill? Return

    MOVE.W  #9,D3                    ;   We want to get 8 random bits
.li SUBQ.B  #1,D3                    ;     Decrement bits-left counter
    BEQ.S   .nb                      ;     No more bits? On to the next byte
    LSL.B   #1,D1                    ;     Make room in accum for the next bit
    BTST.L  #0,D0                    ;     Is LFSR LSBit on?
    BEQ.S   .no                      ;     No, skip ahead to end of loop
    ORI.B   #1,D1                    ;     Yes, set next accumulator bit on
    LSR.W   #1,D0                    ;     Shift LFSR one bit right
    EORI.W  #$B400,D0                ;     XOR it with the taps and set MSBit
    BRA.S   .li                      ;     Back to top of loop for next bit
.no LSR.W   #1,D0                    ;     Shift LFSR one bit right
    BRA.S   .li                      ;     Back to top of loop for next bit

.nb MOVE.B  D1,(A0)+                 ;   Copy new random byte to buffer
    SUBQ.W  #1,D2                    ;   Decrement bytes-left counter
    BRA.S   .lo                      ;   And back up to top of loop

.rt RTS                              ; Back to caller

    ; _RESIZE -- Change buffer sizing for these memory manipulation subroutines
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
_RESIZE:
    MOVE.B  z_BufferNumSectors,(3+z_ResizeInitialVals)     ; Current settings...
    MOVE.B  z_BufferTagLongs,(7+z_ResizeInitialVals)       ; ...go into form...
    MOVE.B  z_BufferSectorLongs,(11+z_ResizeInitialVals)   ; ...initial values
    LEA     s_ResizeForm,A0          ; Prepare FORM args: address of template...
    LEA     s_ResizePrompts,A1       ; ...address of prompt pointer array...
    LEA     z_ResizeInitialVals,A2   ; ...address of initial values array...
    SUBA.L  A3,A3                    ; ...and no upper bounds on sizing
    BSR     FORM                     ; Launch the form

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, go ahead with seeking
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Copy values from form to sizing settings
.go MOVE.L  (zFieldValues),D0        ; Copy tag size to D0
    BEQ.S   .zr                      ; Abort if tag size is nonzero
    MOVE.L  (4+zFieldValues),D1      ; Copy tag size to D1
    BEQ.S   .zr                      ; Abort if tag size is nonzero
    MOVE.L  (8+zFieldValues),D2      ; Copy sector size to D2
    BEQ.S   .zr                      ; Abort if sector size is nonzero
    MOVE.L  (8+zFieldValues),D2      ; Copy sector size to D2
    BEQ.S   .zr                      ; Abort if sector size is nonzero
    MOVE.B  D0,z_BufferNumSectors    ; Put number of sectors in place
    MOVE.B  D1,z_BufferTagLongs      ; Put tag size in place
    MOVE.B  D2,z_BufferSectorLongs   ; Put sector size in place
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS

.zr mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SIZES MUST BE NONZERO.'>
    RTS

    ; _SECTSIZED2 -- Load sector size in longwords into D2
    ; Args:
    ;   (none)
    ; Notes:
    ;   Sector size is only according to the way the user configured the buffer,
    ;       not according to the drive itself.
    ;   "Trashes" D2.
_SECTSIZED2:
    MOVE.W  D0,-(A7)                 ; Save D0 so we can use it as a temporary
    CLR.W   D2                       ; Sector size in longwords is...
    MOVE.B  z_BufferTagLongs,D2      ; ...tag size in longwords...
    CLR.W   D0                       ; ...plus...
    MOVE.B  z_BufferSectorLongs,D0   ; ...sector size in longwords...
    ADD.W   D0,D2                    ; ...making this total
    MOVE.W  (A7)+,D0                 ; Restore D0 from stack
    RTS                              ; Back to caller

    ; _SECTSUFFIX -- Print sector (in buffer) being displayed/edited
    ; Args:
    ;   D5: Sector being displayed/edited, counting up from 1
    ; Notes:
    ;   Printed string is the kind of thing you'd print just after printing
    ;       "RAW TAG DATA", e.g., hence "SUFFIX".
    ;   Also shows buffer size in sectors.
_SECTSUFFIX:
    MOVE.B  z_BufferNumSectors,-(A7)   ; Number of sectors to stack
    MOVE.B  D5,-(A7)                 ; Current sector number to stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' - SECTOR '>,hhx,<' OF '>,hhx
    RTS                              ; Back to RAWPRINT


    PAGE
* NeoWidEx disk data buffer numerical data =================
    SECTION kSecData

    DS.W    0                        ; Force even alignment for what follows
dBufferMenuHandlers:                 ; Addresses of handlers for each of the...
    DC.L    (1+GOBACK)               ; ...menu items in sBufferMenu
    DC.L    _RAWSHOW                 ; 1+ means don't print a newline before...
    DC.L    _SPARESHOW               ; ...calling this handler; the LSBit...
    DC.L    _EDIT                    ; ...will be cleared before the call
    DC.L    _PATTERN
    DC.L    _RANDOM
    DC.L    _RESIZE
    DC.L    $00000000                ; Null terminator

d_RandomInitialVals:
    DC.L    $00001337                ; An elite default random seed
d_RandomBounds:
    DC.L    $0000FFFE                ; FFFF will become 0, a seed we can't use

d_LongsToEditBounds:
    DC.L    $00000004                ; Max is four at a time


    PAGE
* NeoWidEx disk data buffer scratch data allocation ========
    SECTION kSecScratch

z_BufferNumSectors:
    DC.B    $1                       ; Default number of sectors: 1
z_BufferTagLongs:
    DC.B    $5                       ; Default tag size: 5 longwords
z_BufferSectorLongs:
    DC.B    $80                      ; Default sector size: 128 longwords

    DS.W    0
z_EditPrompts:                       ; Form prompts for editing. NOTE: the...
    DC.L    .p1,.p2,.p3,.p4          ; ..."xxxx" portions will be replaced...
.p1 DC.B    'FROM xxxx',0            ; ...by offsets from start of tag or...
.p2 DC.B    'FROM xxxx',0            ; ...sector; but the substitution works...
.p3 DC.B    'FROM xxxx',0            ; ...by memory position, not by finding...
.p4 DC.B    'FROM xxxx',0            ; ...the x's themselves

    DS.W    0
z_LongsToEdit:
    DC.L    $00000004                ; Number of longwords to edit/fill

    DS.W    0
z_PatternInitialVals:                ; We will remember the user's previous...
    DC.L    $55555555                ; ...fill patterns
    DC.L    $AAAAAAAA
    DC.L    $55555555
    DC.L    $AAAAAAAA

    DS.W    0
z_ResizeInitialVals:                 ; We will remember the user's previous...
    DC.L    $00000000                ; tag and sector data buffer sizes
    DC.L    $00000000
    DC.L    $00000000


    PAGE
* NeoWidEx disk data buffer strings ========================
    SECTION kSecStrings

s_RandomForm:                        ; User form for specifying random seed
    DC.B    $0D,'RANDOM SEED-ab__',0

    DS.W    0
s_RandomPrompts:                     ; Form prompts for random seed
    DC.L    .p1
.p1 DC.B    'SEED',0

s_LongsToEditForm:                   ; User form for specifying pattern size
    DC.B    $0D,'PATTERN LENGTH IN LONGWORDS? aa',0

    DS.W    0
s_LongsToEditPrompts:                ; Form prompts for pattern size
    DC.L    .p1
.p1 DC.B    'LENGTH',0

    DS.W    0
s_LongsForms:                        ; Forms for different numbers of longwords
    DC.L    .f1,.f2,.f3,.f4
.f1 DC.B    $0D,'   ad______',0
.f2 DC.B    $0D,'   ad______-bd______',0
.f3 DC.B    $0D,'   ad______-bd______-cd______',0
.f4 DC.B    $0D,'   ad______-bd______-cd______-dd______',0

    DS.W    0
s_LongsPrompts:                      ; Form prompts for entering longwords
    DC.L    .p1,.p2,.p3,.p4
.p1 DC.B    'LONGWORD 1',0
.p2 DC.B    'LONGWORD 2',0
.p3 DC.B    'LONGWORD 3',0
.p4 DC.B    'LONGWORD 4',0

s_AbortEdit:
    DC.B    $0D,'...ABORTED -- BUT ANY EDITS UP TO NOW ARE SAVED...',0

s_ResizeForm:                        ; User form for buffer sizing
    DC.B    $0D,'  -- CHANGE BUFFER SIZING --'
    DC.B    $0D,'NOTE--SIZING ONLY AFFECTS THESE BUFFER MANIPULATION COMMANDS.'
    DC.B    $0D,'   NUMBER OF SECTORS-aa'
    DC.B    $0D,'   LONGWORDS IN SECTOR TAG-ba   IN SECTOR DATA-ca',0

    DS.W    0
s_ResizePrompts:                     ; Form prompts for buffer sizing
    DC.L    .p1,.p2,.p3
.p1 DC.B    'SECTORS',0
.p2 DC.B    'TAG LONGWORDS',0
.p3 DC.B    'DATA LONGWORDS',0

s_ShowAsSprTblForm:
    DC.B    $0D,'DECODE PROFILE FORMAT INSTEAD OF WIDGET FORMAT? a'

    DS.W    0
s_ShowAsSprTblPrompts:               ; Form prompts for spare table type
    DC.L    .p1
.p1 DC.B    'PROFILE',0

sBufferMenu:
    DC.B    'DATA BUFFER',0          ; Menu title
    DC.B    'GO BACK...    1',0
    DC.B    'SHOW CONTENTS 2',0
    DC.B    '...AS SPR TBL 3',0
    DC.B    'EDIT CONTENTS 4',0
    DC.B    'PATTERN FILL  5',0
    DC.B    'RANDOM FILL   6',0
    DC.B    'RESIZE BUFFER 7',0
    DC.B    0                        ; End of menu
    DC.B    $01                      ; Divider after item 1
    DC.B    $03                      ; Divider after item 3
    DC.B    $06                      ; Divider after item 6
    DC.B    0                        ; No more dividers


** (Back to the code section) **
    SECTION kSecCode



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
