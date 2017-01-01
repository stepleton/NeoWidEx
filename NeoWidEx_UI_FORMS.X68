*-----------------------------------------------------------
* Title      : NeoWidEx_UI
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Form subroutines, data, and scratch areas.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*-----------------------------------------------------------


* NeoWidEx UI FORMS code ===================================

    ; FORM -- Present a form with up to four numerical fields to the user
    ; Args:
    ;   A0: Address of form template
    ;   A1: Address of an array of prompt strings for the four fields
    ;   A2: If nonzero, address of an array of initial field values
    ;   A3: If nonzero, address of an array of upper bounds (inclusive)
    ; Notes:
    ;   Trashes D0-D4/A0-A4
    ;   TODO: add notes: format, warning about initial values and bounds
FORM:
    ; First, prepare all "temporaries" used by this subroutine.
    mMemCpy A1,#z_FPromptAddrs,#(4*4)  ; Copy field prompt addresses

    MOVE.L  A2,D0                    ; Just to test: init. field vals supplied?
    BNE.S   .c0                      ; Yes, skip ahead to copy them
    mMemSet #0,#zFieldValues,#(4*4)  ; No, fill it with zeros
    mMemSet #0,#z_FFieldResets,#(4*4)  ; Same for the default/reset values
    BRA.S   .cb                      ; Skip ahead to copy upper bounds
.c0 mMemCpy A2,#zFieldValues,#(4*4)  ; Copy initial field values
    mMemCpy A2,#z_FFieldResets,#(4*4)  ; Also to the default/reset values

.cb MOVE.L  A3,D0                    ; Just to test: upper bounds specified?
    BNE.S   .c1                      ; Yes, skip ahead to copy them
    mMemSet #$FF,#z_FFieldBounds,#(4*4)  ; No, fill it with maxuints
    BRA.S   .c2                      ; Skip ahead to scan the form template
.c1 mMemCpy A3,#z_FFieldBounds,#(4*4)  ; Copy upper bounds

.c2 CLR.L   z_FFieldSizes            ; All zeros into field sizes

    ; Next, scan the form template to find the locations and sizes of the
    ; fields. We also count the number of rows the template has as one plus
    ; the number of $0D characters inside.
    ; TODO: save registers
    MOVE.L  A0,-(A7)                 ; Save form template address to stack
    CLR.B   D0                       ; Row count accumulates in D0
    CLR.B   D1                       ; Current column accumulates in D1
    CLR.W   D2                       ; Prepare D2 for use as a table index

.sl CMPI.B  #$0D,(A0)                ;   Top of loop; is this a carriage return?
    BNE.S   .s0                      ;   No, skip ahead to next check
    ADDQ.B  #1,D0                    ;   Yes, increment row count...
    CLR.B   D1                       ;   ...zero out current column...
    BRA.S   .s3                      ;   ...and go to bottom of loop (for incr.)

.s0 CMPI.B  #'a',(A0)                ;   Is this byte less than ASCII 'a'?
    BLO.S   .s2                      ;   Yes, skip ahead to the next character
    CMPI.B  #'d',(A0)                ;   Is this byte greater than ASCII 'd'?
    BHI.S   .s2                      ;   Yes, skip ahead to the next character

    MOVE.B  (A0)+,D2                 ;   Copy field ID to D2, move to next char
    SUBI.B  #'a',D2                  ;   Turn D2 into a 0-based index
    LEA     z_FFieldRows,A1          ;   Rows table base into A1
    MOVE.B  D0,0(A1,D2.W)            ;   Save row into row table
    LEA     z_FFieldCols,A1          ;   Columns table base into A1
    MOVE.B  D1,0(A1,D2.W)            ;   Save column into columns table
    ADDQ.B  #1,D1                    ;   Increment column (since we bumped A0)

    MOVE.B  (A0),D3                  ;   Copy field size to D3
    SUBI.B  #'0',D3                  ;   Turn ASCII into a number
    LEA     z_FFieldSizes,A1         ;   Field sizes base into A1
    MOVE.B  D3,0(A1,D2.W)            ;   Save field size into field sizes table

    LSL.B   #1,D3                    ;   D3 *= 2 for field size in chars
    SUBQ.B  #2,D3                    ;   D3 -= 2 for chars already used
.s1 TST.B   D3                       ;   Any chars left in field to skip?
    BEQ.S   .s2                      ;   No, skip ahead
    ADDQ.L  #1,A0                    ;   Yes, increment current char
    ADDQ.B  #1,D1                    ;   And increment current column as well
    SUBQ.B  #1,D3                    ;   Decrement characters left in field
    BRA.S   .s1                      ;   Keep skipping chars in field if needed

.s2 ADDQ.B  #1,D1                    ;   Next char; increment column
.s3 TST.B   (A0)+                    ;   But was last char the end? (Note incr.)
    BNE.S   .sl                      ;   No, back to top of loop

    MOVE.L  (A7)+,A0                 ; Recover form address from top of stack

    ; If no fields were discovered, exit now to avoid an infinite loop.
    TST.L   z_FFieldSizes            ; Are there any fields?
    BNE.S   .o0                      ; Yes, continue
    RTS                              ; No, return to caller

    ; Collected field rows are all offset from the first row of the template.
    ; We want offsets from the template's last row: numbers <= 0.
.o0 SUB.B   D0,z_FFieldRows
    SUB.B   D0,(z_FFieldRows+1)
    SUB.B   D0,(z_FFieldRows+2)
    SUB.B   D0,(z_FFieldRows+3)

    ; Display form template in the console window
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,A0

    ; Initialise UI
    CLR.W   D0                       ; Start off editing the first field
    LEA     zFieldValues,A0          ; Field values array into A0
    LEA     z_FFieldRows,A1          ; Field rows array into A1
    LEA     z_FFieldCols,A2          ; Field columns array into A2
    LEA     z_FFieldSizes,A3         ; Field sizes array into A3
    BSR     _REFRESHFORM             ; Fill in current field values
    CLR.B   zFormIntent              ; By default, user's intent is to cancel

    ; At last, the main UI loop!
.ui TST.B   0(A3,D0.W)               ;   Does this field exist in the form?
    BEQ     .u4                      ;   No, so on to the next field

    ; 1. Set up the display and cursor position for the current field; also,
    ;    cache the current value of the field (prior to any user modification)
    JSR     kMakeDbox                ;   Show dialogue box
    BSR     _FIELDPOS                ;   Position of current field into D1,D2
    BSR     _BLANKFIELD              ;   Overlay ?-blocks onto current field

    MOVE.W  #kDboxRow,D1             ;   Dialog box pixel row to D1
    MOVE.W  #kDboxColumn,D2          ;   Dialog box character column to D2
    LEA     z_FPromptAddrs,A4        ;   Field prompt pointer array into A4
    LSL.W   #2,D0                    ;   D0 *= 4 for field indirect addressing
    MOVE.L  0(A4,D0.W),-(A7)         ;   Prompt string pointer onto stack
    mPrint  D1,D2,#kFirstCol,s,<'? '>    ; Print prompt into dialog box
    MOVE.L  0(A0,D0.W),z_FPriorValue   ; Cache current value of this field
    LSR.W   #2,D0                    ;   Restore D0: D0 /= 4
    BSR     _FILLFIELD               ;   Print field contents into dialog box

    CLR.W   D3                       ;   Prepare D3 to hold cursor position
    MOVE.B  0(A3,D0.W),D3            ;   Twice the field width minus one goes...
    LSL.B   #1,D3                    ;   ...into D3, which means we start the...
    SUBQ.B  #1,D3                    ;   ...cursor under the leftmost nibble
    JSR     _CURSOR                  ;   Show the cursor

    ; 2. Obtain keyboard input
.u0 BSR     _GETKEY                  ;     Retrieve a keypress into D4

    ; 3a. Test for special keys first
    CMPI.B  #kKeyCodeLft,D4          ;     User typed keypad left?
    BEQ     .kl                      ;       Move cursor left (with wrapping)
    CMPI.B  #kKeyCodeBsp,D4          ;     User typed backspace?
    BEQ     .kl                      ;       Move cursor left (with wrapping)
    CMPI.B  #kKeyCodeRgt,D4          ;     User typed keypad right?
    BEQ     .kr                      ;       Move cursor right (with wrapping)
    CMPI.B  #kKeyCodeSpc,D4          ;     User typed space?
    BEQ     .kr                      ;       Move cursor right (with wrapping)
    CMPI.B  #kKeyCodeClr,D4          ;     User typed clear?
    BEQ     .kz                      ;       Reset field to its initial value
    CMPI.B  #kKeyCodeZ,D4            ;     User typed Z?
    BEQ     .kz                      ;       Reset field to its initial value
    CMPI.B  #kKeyCodeEnt,D4          ;     User typed enter?
    BEQ     .u1                      ;       Check bounds and submit form
    CMPI.B  #kKeyCodeX,D4            ;     User typed X?
    BEQ     .u1                      ;       Check bounds and submit form
    CMPI.B  #kKeyCodeRet,D4          ;     User typed return?
    BEQ     .u2                      ;       Check bounds and on to next field
    CMPI.B  #kKeyCodeTab,D4          ;     User typed tab?
    BEQ     .u2                      ;       Check bounds and on to next field
    CMPI.B  #kKeyCodeQ,D4            ;     User typed Q?
    BEQ     .kq                      ;       Reset form and quit
    CMPI.B  #kKeyCodeSla,D4          ;     User typed /? (or ?)
    BEQ     .kh                      ;       Show help

    ; 3b. Not a special key; see if user has typed a hex digit
    MOVE.L  A0,-(A7)                 ;     Save A0 to stack
    MOVE.W  D0,-(A7)                 ;     Save D0 to stack
    LEA     d_FKeyToNibble,A0        ;     Key-to-nibble table to A0
.hl MOVE.B  (A0)+,D0                 ;       Copy key-to-compare to D0
    BEQ.S   .hx                      ;       Quit if it was the null terminator
    CMP.B   D0,D4                    ;       Did we type this key?
    BEQ.S   .hc                      ;       Yes, jump ahead to get its nibble
    ADDQ.L  #1,A0                    ;       No, move to next table entry
    BRA.S   .hl                      ;       Loop again to deal with that entry
.hc MOVE.B  (A0)+,D4                 ;     Copy corresponding hex digit to D4
    ANDI.B  #$FB,CCR                 ;     Clear zero bit to mark valid input
.hx MOVEM.W (A7)+,D0                 ;     Recover D0 from stack
    MOVEM.L (A7)+,A0                 ;     Recover A0 from stack

    ; 3c. Hex digit or no, deal with it
    BEQ     .u0                      ;     User typed nonsense? Wait for new key
    BSR     _SETNIBBLE               ;     Update form value with user nibble
    BSR     _FILLFIELD               ;     Refresh form value display
    BSR     _CURSORRIGHT             ;     Advance cursor
    BRA     .u0                      ;     Wait for a new key

.u1 ; 4. User has pressed the enter key; mark form intent to execute
    MOVE.B  #$FF,zFormIntent         ;   User now wants to submit this form

    ; 5. Before we move on from this field, see if the new value is in bounds;
    ;    if not, admonish the user and restore the prior field value
.u2 LEA     z_FFieldBounds,A4        ;   Field bounds array base into A4
    MOVE.W  D0,-(A7)                 ;   Save D0 onto stack
    LSL.W   #2,D0                    ;   D0 *= 4 for field indirect addressing
    MOVE.L  0(A0,D0.W),D4            ;   Copy new value to D4
    CMP.L   0(A4,D0.W),D4            ;   Compare with inclusive upper bound
    MOVEM.W (A7)+,D0                 ;   Restore D0 without changing flags
    BLS.S   .u3                      ;   New value is in range, so move ahead
    CLR.B   zFormIntent              ;   It's not; cancel submit just in case
    JSR     kMakeDbox                ;   Clear dialog box for err message
    MOVE.W  #kDboxRow,D1             ;   Dialog box pixel row to D1
    MOVE.W  #kDboxColumn,D2          ;   Dialog box character column to D2
    BSR     _FILLFIELD               ;   Show bad value at front of the error
    ADD.B   0(A3,D0.W),D2            ;   Add twice the field width to D2...
    ADD.B   0(A3,D0.W),D2            ;   ...to advance column position for the:
    mPrtMem D1,D2,#kFirstCol,export,#sFormOutOfBounds  ; Out-of-bounds message
    EXG     A0,A4                    ;   A0 to bounds array; A4 to values array
    BSR     _FILLFIELD               ;   Show bound at end of the error
    EXG     A4,A0                    ;   Unswap A0 and A4
    BSR     _GETKEY                  ;   Wait for user keypress
    LSL.W   #2,D0                    ;   D0 *= 4 for field indirect addressing
    MOVE.L  z_FPriorValue,0(A0,D0.W)   ; Restore prior value of this field
    LSR.W   #2,D0                    ;   D0 /= 4 to return it to being an index
    BRA     .ui                      ;   User, try again with this field

    ; 6. Fill the new value into the field
.u3 BSR     _FIELDPOS                ;   Position of current field into D1,D2
    BSR     _FILLFIELD               ;   Fill in current field value

    ; 7. Either exit if the user intends to submit, or move on to the next field
    TST.B   zFormIntent              ;   Does the user want to quit?
    BNE.S   .rt                      ;   Yes, jump to exit
.u4 ADDQ.W  #1,D0                    ;   Advance to next field
    CMPI.W  #4,D0                    ;   Or do we need to rewind to field 0?
    BLO     .ui                      ;   No, so back to top of UI loop
    CLR.W   D0                       ;   Yes, so rewind to field 0
    BRA     .ui                      ;   And back to top of UI loop

    ; Finally, cleanup
.rt JSR     kClearDbox               ; Delete dialogue box
    RTS                              ; Return to caller

    ; Special key handlers:
    ;    Move the cursor left (with wrapping)
.kl BSR     _CURSORLEFT              ; Move the cursor one position left
    BRA     .u0                      ; Back to keyboard scanning

    ;    Move the cursor right (with wrapping)
.kr BSR     _CURSORRIGHT             ; Move the cursor one position right
    BRA     .u0                      ; Back to keyboard scanning

    ;    Reset the current field to its initial value
.kz LEA     z_FFieldResets,A4        ; Initial field values into A4
    BSR     _RESETVALUE              ; Reset current field to its initial value
    BRA     .ui                      ; Do complete field redraw

    ;    Reset all field values and quit
.kq LEA     z_FFieldResets,A4        ; Initial field values into A4
    MOVE.W  #$03,D0                  ; Reset all fields, starting at the fourth
.q0 BSR     _RESETVALUE              ; Reset this field
    SUBQ.B  #1,D0                    ; On to the preceding field
    BPL.S   .q0                      ; Loop until done with fields
    BSR     _REFRESHFORM             ; Re-display form with original values
    BRA.S   .rt                      ; Go to cleanup and return to caller

    ;    Show help message
.kh JSR     kMakeDbox                ; Clear dialog box for help message
    MOVE.W  #kDboxRow,D1             ; Dialog box pixel row to D1
    MOVE.W  #kDboxColumn,D2          ; Dialog box character column to D2
    mPrtMem D1,D2,#kFirstCol,noexport,#sFormHelp   ; Show help message
    BSR     _GETKEY                  ; Wait for user keypress
    BRA     .ui                      ; Do complete field redraw


    ; _GETKEY -- FORM helper: get a key from the user, put keydown code into D4
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D4.
_GETKEY:
    MOVE.L  D0,-(A7)                 ; Save D0 to stack
.wk JSR     kWait4Input              ;   Get an event from the COPS
    TST.B   D0                       ;   Was it a keyboard event?
    BPL.S   .wk                      ;   No, wait again
    MOVE.B  D0,D4                    ; Yes, copy keyboard event to D4
    MOVE.L  (A7)+,D0                 ; And restore D0 from the stack
    RTS                              ; Back to caller


    ; _REFRESHFORM -- FORM helper: fill form with current values
    ; Args:
    ;   A0: Address of the field values array
    ;   A1: Address of the field rows array
    ;   A2: Address of the field columns array
    ;   A3: Address of the field sizes array
    ; Notes:
    ;   Will loop forever if a form has no fields.
_REFRESHFORM:
    MOVEM.W D0-D2,-(A7)              ; Save used data registers to stack
    CLR.W   D0                       ; DO: field index

.t0 TST.B   0(A3,D0.W)               ;   Does this field exist in the form?
    BEQ.S   .t1                      ;   No, so on to the next field
    BSR     _FIELDPOS                ;   Position of this field into D1,D2
    BSR     _FILLFIELD               ;   Show this field's value
.t1 ADDQ.B  #1,D0                    ;   Set index to the next field
    CMPI.B  #4,D0                    ;   Or have we finished them all?
    BLO.S   .t0                      ;   If not, on to the next field

    MOVEM.W (A7)+,D0-D2              ; Recover used data registers from stack
    RTS                              ; Back to caller


    ; _FIELDPOS -- FORM helper: screen position of a field into D1, D2
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   A1: Address of the field rows array
    ;   A2: Address of the field columns array
    ; Notes:
    ;   D1 is set to the field screen row for field (D0.W) in pixels; D2 is set
    ;       to the field screen column for field (D0.W) in character positions.
    ;   Trashes upper word of D1.
_FIELDPOS:
    MOVE.B  0(A1,D0.W),D1            ; Field's relative row into D1
    MOVE.B  0(A2,D0.W),D2            ; Field's column into D2
    EXT.W   D1                       ; Extend D1 from byte to word
    EXT.W   D2                       ; Extend D2 from byte to word
    MULS.W  #kCharHeight,D1          ; Convert rows from text to pixels
    ADD.W   kCrtRow,D1               ; Add current row (pixels) to D1
    ADD.W   #kFirstCol,D2            ; Add leftmost column to D2
    RTS                              ; Back to caller
 

    ; _FILLFIELD -- FORM helper: print field contents to a screen location
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   D1: field screen row, in pixels
    ;   D2: field screen column, in character positions
    ;   A0: Address of the field values array
    ;   A3: Address of the field sizes array
    ; Notes:
    ;   Does not alter contents of D1-D2.
_FILLFIELD:
    CMPI.B  #1,0(A3,D0.W)            ; Is this field a byte?
    BNE.S   .f0                      ; No, skip ahead
    LSL.W   #2,D0                    ; Yes, D0 *= 4 for indirect addressing...
    MOVE.B  3(A0,D0.W),-(A7)         ; ...and move byte onto stack
    mPrtHxB D1,D2,#kFirstCol,noexport  ; Print byte
    BRA     .f3                      ; Skip to end of loop

.f0 CMPI.B  #2,0(A3,D0.W)            ; Is this field a word?
    BNE.S   .f1                      ; No, skip ahead
    LSL.W   #2,D0                    ; Yes, D0 *= 4 for indirect addressing...
    MOVE.W  2(A0,D0.W),-(A7)         ; ...and move word onto stack
    mPrtHxW D1,D2,#kFirstCol,noexport  ; Print word
    BRA.S   .f3                      ; Skip to end of loop

.f1 CMPI.B  #3,0(A3,D0.W)            ; Is this field a three-byter?
    BNE.S   .f2                      ; No, skip ahead
    LSL.W   #2,D0                    ; Yes, D0 *= 4 for indirect addressing...
    MOVE.L  0(A0,D0.W),-(A7)         ; ...and move long holding it onto stack
    mPrtHx3 D1,D2,#kFirstCol,noexport  ; Print the three-byter
    BRA.S   .f3                      ; Skip to end of loop

.f2 LSL.W   #2,D0                    ; Must be a long, D0 *= 4 for addressing...
    MOVE.L  0(A0,D0.W),-(A7)         ; ...and move long onto stack
    mPrtHxL D1,D2,#kFirstCol,noexport  ; Print the long

.f3 LSR.W   #2,D0                    ; Restore D0: D0 /= 4
    RTS                              ; Back to caller


    ; _BLANKFIELD -- FORM helper: fill location of field contents with ?-blocks
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   D1: field screen row, in pixels
    ;   D2: field screen column, in character positions
    ;   A3: Address of the field sizes array
    ; Notes:
    ;   Does not alter contents of D1-D2.
    ;   Not fast at all, but simple...
_BLANKFIELD:
    MOVE.W  D3,-(A7)                 ; Save D3 to stack
    CLR.W   D3                       ; Clear D3 in preparation for...
    MOVE.B  0(A3,D0.W),D3            ; ...copying in the field size...
    LSL.B   #1,D3                    ; ...multiplying that by two...
    ADD.W   D2,D3                    ; ...adding the field's first column...
.b0 SUBQ.W  #1,D3                    ; ...and -1 to get last column/decrement
    mPrtLit D1,D3,#kFirstCol,noexport,<'!'>  ; Print ?-block
    CMP.W   D2,D3                    ; Have we reached the start of the field?
    BNE.S   .b0                      ; No, keep going
    MOVE.W  (A7)+,D3                 ; Yes, recover D3 from stack
    RTS                              ; Back to caller


    ; _CURSOR -- FORM helper: draw or clear a cursor underneath a field
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   D1: field screen row, in pixels
    ;   D2: field screen column, in character positions
    ;   D3: draw/clear cursor below this nibble in the field (counts from right)
    ;   A3: Address of the field sizes array
    ; Notes:
    ;   (none)
_CURSOR:
    MOVE.L  A0,-(A7)                 ; Save A0 to stack
    MOVE.W  D3,-(A7)                 ; Save D3 to stack

    ; D3 receives the cursor offset from the leftmost character of the field.
    NEG.B   D3                       ; First, negate D3...
    ADD.B   0(A3,D0.W),D3            ; ...then add twice the field width...
    ADD.B   0(A3,D0.W),D3
    SUBQ.B  #1,D3                    ; ...minus one, is the offset
    EXT.W   D3                       ; Sign-extend to a word

    ; Preload A0 with the number of bytes from first screen byte to the first
    ; byte of the cursor's first row.
    EXG.L   A0,D4                    ; We will do all of our arithmetic in D4
    CLR.L   D4                       ; First, clear it all out
    MOVE.W  D1,D4                    ; Copy in field screen row
    ADD.B   #(kCharHeight-1),D4      ; Add row height so cursor is under char
    MULU.W  #kRowBytes,D4            ; Multiply by bytes per row
    EXG.L   D4,A0                    ; Move result to A0

    ; Add column, screenbase, and offset to give A0 the top byte of the cursor.
    ADDA.L  kScreen,A0               ; Screenbase
    ADDA.W  D2,A0                    ; Column
    ADDA.W  D3,A0                    ; Offset

    ; XOR and advance A0 one row at a time to make a "fat underline".
    EORI.B  #$FF,(A0)
    ADDA.W  #kRowBytes,A0
    EORI.B  #$FF,(A0)
    ADDA.W  #kRowBytes,A0
    EORI.B  #$FF,(A0)

    ; All done, back to caller.
    MOVE.W  (A7)+,D3                 ; Recover D3 from stack
    MOVE.L  (A7)+,A0                 ; Recover A0 from stack
    RTS                              ; Back to caller


    ; _SETNIBBLE -- FORM helper: set a nibble in a field value
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   D3: nibble to change, counting up from the LSNibble
    ;   D4: new nibble value
    ;   A0: Address of the field values array
    ; Notes:
    ;   (none)
_SETNIBBLE:
    MOVEM.W D0/D3,-(A7)              ; Save words of D0/D3 to stack
    MOVE.L  D1,-(A7)                 ; Save all of D1 to stack
    LSL.W   #2,D0                    ; Field index to long offset
    MOVE.L  0(A0,D0.W),D1            ; Copy field value to D1
    EXT.W   D3                       ; Nibble index from byte to word
    LSL.W   #2,D3                    ; And convert to number of bits to rotate
    ROR.L   D3,D1                    ; Rotate nibble to change to LSnibble
    ANDI.B  #$F0,D1                  ; Blank out old value of nibble to change
    OR.B    D4,D1                    ; Add in new nibble value
    ROL.L   D3,D1                    ; Rotate nibble to change back in place
    MOVE.L  D1,0(A0,D0.W)            ; Copy D1 back to field value
    MOVE.L  (A7)+,D1                 ; Recover all of D1 from stack
    MOVEM.W (A7)+,D0/D3              ; Recover words of D0/D3 from stack
    RTS                              ; Back to caller


    ; _RESETVALUE -- FORM helper: reset a field value to its initial value
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   A0: Address of the field values array
    ;   A4: Address of the field initial values array
    ; Notes:
    ;   (none)
_RESETVALUE:
    MOVE.L  A0,-(A7)                 ; Save A0 on stack
    LSL.W   #2,D0                    ; Field index to table offset
    ADDA.W  D0,A0                    ; Point A0 to selected initial value
    MOVE.L  0(A4,D0.W),(A0)          ; Copy initial value to field value
    LSR.W   #2,D0                    ; Table offset back to field index
    MOVE.L  (A7)+,A0                 ; Recover A0 from stack
    RTS                              ; Back to caller


    ; _CURSORLEFT -- FORM helper: move a displayed cursor leftward
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   D1: field screen row, in pixels
    ;   D2: field screen column, in character positions
    ;   D3: draw/clear cursor below this nibble in the field (counts from right)
    ;   A3: Address of the field sizes array
    ; Notes:
    ;   Assumes cursor is already drawn; clears prior to move, then redraws.
    ;   Cursor will "wrap around" to the right side of the field.
_CURSORLEFT:
    JSR     _CURSOR                  ; Clear existing cursor
    MOVE.W  D1,-(A7)                 ; Save D1 on stack
    MOVE.B  0(A3,D0.W),D1            ; Copy field width to D1
    LSL.B   #1,D1                    ; Shift to get its width in nibbles
    ADDQ.W  #1,D3                    ; Increment current nibble
    CMP.B   D1,D3                    ; Is current nibble >= field size?
    BLO.S   .rt                      ; No, go ahead and draw the new cursor
    CLR.W   D3                       ; Yes, clear; current nibble=rightmost char
.rt MOVE.W  (A7)+,D1                 ; Restore D1 from stack
    JSR     _CURSOR                  ; Draw the new cursor
    RTS                              ; Back to caller


    ; _CURSORRIGHT -- FORM helper: move a displayed cursor rightward
    ; Args:
    ;   D0: field index, as a word in 0..3
    ;   D1: field screen row, in pixels
    ;   D2: field screen column, in character positions
    ;   D3: draw/clear cursor below this nibble in the field (counts from right)
    ;   A3: Address of the field sizes array
    ; Notes:
    ;   Assumes cursor is already drawn; clears prior to move, then redraws.
    ;   Cursor will "wrap around" to the left side of the field.
_CURSORRIGHT:
    JSR     _CURSOR                  ; Clear existing cursor
    SUBQ.W  #1,D3                    ; Decrement current nibble
    TST.W   D3                       ; Is current nibble < 0?
    BPL.S   .rt                      ; No, go ahead and draw the new cursor
    CLR.W   D3                       ; Yes, so clear current nibble
    MOVE.B  0(A3,D0.W),D3            ; Size into current nibble LSByte
    LSL.W   #1,D3                    ; Multiply size by two
    SUBQ.W  #1,D3                    ; Subtract 1; current nibble=leftmost char
.rt JSR     _CURSOR                  ; Draw the new cursor
    RTS                              ; Back to caller


    PAGE
* NeoWidEx UI FORMS numerical data =========================
    SECTION kSecData

    ; Table for converting key codes to hex nibbles.
d_FKeyToNibble:
    DC.B    kKeyCode0,$00
    DC.B    kKeyCode1,$01
    DC.B    kKeyCode2,$02
    DC.B    kKeyCode3,$03
    DC.B    kKeyCode4,$04
    DC.B    kKeyCode5,$05
    DC.B    kKeyCode6,$06
    DC.B    kKeyCode7,$07
    DC.B    kKeyCode8,$08
    DC.B    kKeyCode9,$09
    DC.B    kKeyCodeA,$0A
    DC.B    kKeyCodeB,$0B
    DC.B    kKeyCodeC,$0C
    DC.B    kKeyCodeD,$0D
    DC.B    kKeyCodeE,$0E
    DC.B    kKeyCodeF,$0F
    DC.B    kKeyCodePd0,$00
    DC.B    kKeyCodePd1,$01
    DC.B    kKeyCodePd2,$02
    DC.B    kKeyCodePd3,$03
    DC.B    kKeyCodePd4,$04
    DC.B    kKeyCodePd5,$05
    DC.B    kKeyCodePd6,$06
    DC.B    kKeyCodePd7,$07
    DC.B    kKeyCodePd8,$08
    DC.B    kKeyCodePd9,$09
    DC.B    0

    DS.W    0                        ; Force even alignment for following data


    PAGE
* NeoWidEx UI FORMS scratch data allocation ================
    SECTION kSecScratch

zFormIntent:                         ; User is done with the form; what now?
    DC.B    0                        ; 0-disregard, quit; Nonzero-execute

    DS.W    0                        ; Just to make sure we're even-aligned
zFieldValues:                        ; Will hold longs entered into fields
    DC.B    'Fiel'
    DC.B    'dVal'
    DC.B    'sGoH'
    DC.B    'ere;'

z_FFieldResets:                      ; Will hold the initial values of fields
    DC.B    'Defa'
    DC.B    'ults'
    DC.B    'GoHe'
    DC.B    're; '

z_FFieldBounds:                      ; Will hold upper-bounds for field values
    DC.B    'Boun'
    DC.B    'dsGo'
    DC.B    'Here'
    DC.B    ';and'

z_FPromptAddrs:                      ; Will hold pointers to prompt strings
    DC.B    'Prom'
    DC.B    'ptPt'
    DC.B    'rsGo'
    DC.B    'Here'

z_FFieldRows:                        ; Field rows relative to last row...
    DC.B    'Rows'                   ; ...that is, signed chars, all 0 or less
z_FFieldCols:                        ; Field columns, absolute
    DC.B    'Cols'
z_FFieldSizes:                       ; Field sizes, in bytes
    DC.B    'Lens'                   ; 0 means: this field is absent

z_FPriorValue:                       ; Temporary storage for an old field value
    DC.B    ';Old'

    DS.W    0                        ; Force even alignment for following data


    PAGE
* NeoWidEx UI FORMS strings =================================
    SECTION kSecStrings

sFormHelp:
    DC.B    'TAB/RET-NEXT FIELD. CLEAR-RESET FIELD. ENTER-SUBMIT. Q-CANCEL.',0
sFormOutOfBounds:
    DC.B    ' IS OUT OF BOUNDS. MAX VALUE HERE IS ',0

sFormTest:
    DC.B    $0D
    DC.B    '  --- SOME FORM ---',$0D
    DC.B    'THIS IS A FORM. HERE IS THE THIRD FIELD. c3____. COOL.',$0D
    DC.B    'LET US NOW HAVE FIELD TWO-b4______. HOW ABOUT THAT.',$0D
    DC.B    'FIELD FOUR IS ONE BYTE... d1... AND AT LAST...',$0D
    DC.B    'FIELD ONE IS a2__ ... TWO BYTES.',0

    DS.W    0
sFormTestPrompts:
    DC.L    .p1,.p2,.p3,.p4
.p1 DC.B    'FIELD 1',0
.p2 DC.B    'FIELD TWO',0
.p3 DC.B    'FIELD THREE',0
.p4 DC.B    'FIELD IV',0

    DS.W    0
sFormTestInitialVals:
    DC.L    $00001314,$21222324,$00323334,$00000044
sFormTestBounds:
    DC.L    $00007FFF,$7FFFFFFF,$007FFFFF,$0000007F


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
