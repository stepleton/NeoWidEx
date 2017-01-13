*-----------------------------------------------------------
* Title      : NeoWidEx_MACROS
* Written by : Tom Stepleton
* Date       : XX January 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: macros.
*      Resources from NeoWidEx_UI must be defined.
*-----------------------------------------------------------

    ; mFail -- Fail to ROM monitor
    ; Args:
    ;   \1: Error word to show as a decimal number, or 0 for none
    ;   \2 and on to \5: Error strings to concatenate into a message (optional)
    ; Notes:
    ;   Will not return!
mFail       MACRO
      BRA.S   .p\@                   ; Jump past string constant
      ; Assemble error string constant
              IFARG 2
.s\@  DC.B    \2                     ; Start of string constant
              ENDC
              IFARG 3
      DC.B    \3
              ENDC
              IFARG 4
      DC.B    \4
              ENDC
              IFARG 5
      DC.B    \5
              ENDC
      DC.B    0                      ; Null terminator
      DS.W    0                      ; Force even word alignment
      ; Prepare monitor arguments and call the monitor
.p\@  SUBA.L  A2,A2                  ; No icon to show
              IFNC '\1','D0'
      MOVE.W  \1,D0                  ; Place error code (or 0) into D0.
              ENDC
              IFARG 2
      LEA     .s\@,A3                ; Display this message (if one was given)
              ENDC
              IFC <>,<\2>
      SUBA.L  A3,A3                  ; Display no message (none was given)
              ENDC
      JMP     kInitMon               ; Jump to the monitor
            ENDM

    ; mPrtMem -- Print a string in memory to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see below)
    ;   \5: memory address of the string to print
    ; Notes:
    ;   String can be multi-line, with lines split by carriage return ($0D).
    ;   If the "position export" keyword is equal to "export" (no quotes), the
    ;       row and column positions where a hypothetical character after the
    ;       last character in 5 would have been printed are copied back to
    ;       \1 and \2. Will not work correctly if \1 or \2 are in D4-D6.
    ;   If any of your arguments are in D4-D6, it is advisable to permute them
    ;       such that \1 is D5, \2 is D6, and \3 is D4.
mPrtMem     MACRO
      MOVEM.L D4-D6/A6,-(A7)         ; Save register contents
              IFNC '\1','D5'
      MOVE.W  \1,D5                  ; First line row (pixels)
              ENDC
              IFNC '\2','D6'
      MOVE.W  \2,D6                  ; First line first column (chars/bytes)
              ENDC
              IFNC '\3','D4'
      MOVE.W  \3,D4                  ; Next line first column (chars/bytes)
              ENDC
              IFNC '\5','A3'
      MOVEM.L A3,-(A7)               ; Save A3 contents
      MOVEA.L \5,A3                  ; Memory address of string to print
              ENDC
      JSR     kDispMsg               ; Print the message
              IFC '\4','export'
      MOVE.W  D5,\1                  ; Export new first line row if desired
      MOVE.W  D6,\2                  ; Export new first line column if desired
              ENDC
              IFNC '\5','A3'
      MOVEM.L (A7)+,A3               ; Restore A3 contents
              ENDC
      MOVEM.L (A7)+,D4-D6/A6         ; Restore register contents
            ENDM

    ; mPrtBts -- Print a string in memory, substituting bits where directed
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see below)
    ;   \5: memory address of the string to print
    ;   \6: source of bits to substitute into the string
    ; Notes:
    ;   Works the same as mPrtMem, but whenever an ASCII character in the range
    ;       '_'..'~' is encountered, the bit value of bit 0..31 (respectively)
    ;       of \6 is substituted in place of the character (as '0' or '1').
    ;   String can be multi-line, with lines split by carriage return ($0D).
    ;   If the "position export" keyword is equal to "export" (no quotes), the
    ;       row and column positions where a hypothetical character after the
    ;       last character in 5 would have been printed are copied back to
    ;       \1 and \2. Will not work correctly if \1 or \2 are in D4-D6.
    ;   If any of your arguments are in D4-D6, it is advisable to permute them
    ;       such that \1 is D5, \2 is D6, and \3 is D4.
mPrtBts     MACRO
      MOVEM.L D3-D6/A6,-(A7)         ; Save register contents
              IFNC '\1','D5'
      MOVE.W  \1,D5                  ; First line row (pixels)
              ENDC
              IFNC '\2','D6'
      MOVE.W  \2,D6                  ; First line first column (chars/bytes)
              ENDC
              IFNC '\3','D4'
      MOVE.W  \3,D4                  ; Next line first column (chars/bytes)
              ENDC
              IFNC '\5','A3'
      MOVEM.L A3,-(A7)               ; Save A3 contents
      MOVEA.L \5,A3                  ; Memory address of string to print
              ENDC
              IFNC '\6','D3'
      MOVE.L  \6,D3                  ; Source of bits to substitute into string
              ENDC
      BSR     BSUBDISPMSG            ; Print the message
              IFC '\4','export'
      MOVE.W  D5,\1                  ; Export new first line row if desired
      MOVE.W  D6,\2                  ; Export new first line column if desired
              ENDC
              IFNC '\5','A3'
      MOVEM.L (A7)+,A3               ; Restore A3 contents
              ENDC
      MOVEM.L (A7)+,D3-D6/A6         ; Restore register contents
            ENDM

    ; mPrtLit -- Print a string literal to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ;   \5: string literal to print <'which you should specify like this'>
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
mPrtLit     MACRO
      BRA.S   .p\@                   ; Jump past string constant
.s\@  DC.B    \5,0                   ; String constant
      DS.W    0                      ; Force even word alignment
.p\@  mPrtMem \1,\2,\3,\4,#.s\@      ; Print string constant
            ENDM

    ; mPrtHxB -- Print a hexadecimal representation of a byte to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ; (A7): Byte to print to the display
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
    ;   Pops the byte off of the stack.
mPrtHxB     MACRO
      MOVEM.L D0/A3,-(A7)            ; Save register contents
      MOVE.B  8(A7),D0               ; Copy argument byte from stack to D0
      BSR.W   HEXB2STR               ; Convert byte to a string at zNumToStr
      mPrtMem \1,\2,\3,\4,A3         ; Print the converted string
      MOVEM.L (A7)+,D0/A3            ; Restore register contents
      ADDQ.L  #2,A7                  ; Drop byte from stack
            ENDM

    ; mPrtHxW -- Print a hexadecimal representation of a word to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ; (A7): Word to print to the display
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
    ;   Pops the word off of the stack.
mPrtHxW     MACRO
      MOVEM.L D0/A3,-(A7)            ; Save register contents
      MOVE.W  8(A7),D0               ; Copy argument word from stack to D0
      BSR.W   HEXW2STR               ; Convert word to a string at zNumToStr
      mPrtMem \1,\2,\3,\4,A3         ; Print the converted string
      MOVEM.L (A7)+,D0/A3            ; Restore register contents
      ADDQ.L  #2,A7                  ; Drop word from stack
            ENDM

    ; mPrtHx3 -- Print a hexadecimal representation of a 3-byte int to display
    ; Args
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ; (A7): Long whose lower three bytes are to print to the display
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
    ;   Pops the long off of the stack.
mPrtHx3     MACRO
      MOVEM.L D0/A3,-(A7)            ; Save register contents
      MOVE.L  8(A7),D0               ; Copy argument long from stack to D0
      BSR.W   HEX3B2STR              ; Convert long to a string at zNumToStr
      mPrtMem \1,\2,\3,\4,A3         ; Print the converted string
      MOVEM.L (A7)+,D0/A3            ; Restore register contents
      ADDQ.L  #4,A7                  ; Drop long from stack
            ENDM

    ; mPrtHxL -- Print a hexadecimal representation of a long to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ; (A7): Long to print to the display
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
    ;   Pops the long off of the stack.
mPrtHxL     MACRO
      MOVEM.L D0/A3,-(A7)            ; Save register contents
      MOVE.L  8(A7),D0               ; Copy argument long from stack to D0
      BSR.W   HEXL2STR               ; Convert long to a string at zNumToStr
      mPrtMem \1,\2,\3,\4,A3         ; Print the converted string
      MOVEM.L (A7)+,D0/A3            ; Restore register contents
      ADDQ.L  #4,A7                  ; Drop long from stack
            ENDM

    ; mPrtStr -- Print a string pointed to by the top stack value to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ; (A7): Address of a null-terminated string to print to the display
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
    ;   Pops the address off of the stack.
mPrtStr     MACRO
      MOVEM.L A3,-(A7)               ; Save register contents
      MOVEA.L 4(A7),A3               ; Copy address from stack to A3
      mPrtMem \1,\2,\3,\4,A3         ; Print the string at the address
      MOVEM.L (A7)+,A3               ; Restore register contents
      ADDQ.L  #4,A7                  ; Drop address from stack
            ENDM

    ; mPrtCr -- "Print" a carriage return, i.e. move to the next line.
    ; Args:
    ;   \1: where to get/(store new) pixel row of the string's first line
    ;   \2: where to get/(store new) character column
    ;   \3: character column of the next line's first character
    ; Notes:
    ;   The "position export" keyword "export" (see mPrtMem notes) is implied.
    ;   The ROM's kDispMsg routine will not scroll the Service Mode window
    ;       immediately if the new current row is out-of-bounds. Scrolling only
    ;       occurs when a character is printed on an out-of-bounds row.
    ;       Additionally and for this reason, two invocations in sequence will
    ;       not yield a blank line if the screen is already full. To force a
    ;       blank line, print a $0D character instead.
mPrtCr      MACRO
      MOVEM.L D4-D6/A6,-(A7)         ; Save register contents
      MOVE.W \1,D5                   ; First line row (pixels)
      MOVE.W \2,D6                   ; First line first column (chars/bytes)
              IFNC '\3','D4'
      MOVE.W \3,D4                   ; Next line first column (chars/bytes)
              ENDC
      BSR.W   NEWLINE                ; Invoke newline printer
      MOVE.W  D5,\1                  ; Copy new row to row storage
      MOVE.W  D6,\2                  ; Copy new column to column storage
      MOVEM.L (A7)+,D4-D6/A6         ; Restore register contents
            ENDM

    ; mPrtCrP -- Like mPrtCr, but pauses after each full screen
    ; Args:
    ;   \1: where to get/(store new) pixel row of the string's first line
    ;   \2: where to get/(store new) character column
    ;   \3: character column of the next line's first character
    ; Notes:
    ;   Will NOT work correctly if \1 or \2 are in D4-D6.
    ;   The "position export" keyword "export" (see mPrtMem notes) is implied.
    ;   When called kPagerLines times, will print "--MORE--" on the new line and
    ;       await a keypress from the user. After the keypress, the "--MORE--"
    ;       is deleted.
    ;   The ROM's kDispMsg routine will not scroll the Service Mode window
    ;       immediately if the new current row is out-of-bounds. Scrolling only
    ;       occurs when a character is printed on an out-of-bounds row.
    ;       Additionally and for this reason, two invocations in sequence will
    ;       not yield a blank line if the screen is already full---but the
    ;       paging behaviour carries on as if it did anyway. To force a blank
    ;       line, the most effective way is maybe to invoke this macro and then
    ;       `mPrtLit kCrtRow,kCrtCol,#kFirstCol,no_export,<' '>`.
    ;   The "countdown" to the paging event can be changed by altering the value
    ;       in the zLineCount byte, or reset by invoking the `mResetP` macro.
    ;   See the PAGEDNEWLINE subroutine for further information.
mPrtCrP     MACRO
      MOVEM.L D4-D6/A6,-(A7)         ; Save register contents
      MOVE.W \1,D5                   ; First line row (pixels)
      MOVE.W \2,D6                   ; First line first column (chars/bytes)
              IFNC '\3','D4'
      MOVE.W \3,D4                   ; Next line first column (chars/bytes)
              ENDC
      BSR.W   PAGEDNEWLINE           ; Invoke paging newline printer
      MOVE.W  D5,\1                  ; Copy new row to row storage
      MOVE.W  D6,\2                  ; Copy new column to column storage
      MOVEM.L (A7)+,D4-D6/A6         ; Restore register contents
            ENDM

    ; mResetP -- Reset the countdown to the pager event triggered by mPrtCrP
    ; Args:
    ;   (none)
    ; Notes:
    ;   Post-invocation, kPagerLines invocations of PAGEDNEWLINE (e.g. via
    ;       mPrtCrP) will be necessary to trigger another paging event.
mResetP     MACRO
      MOVE.B  #kPagerLines,zLineCount  ; Reset lines remaining
            ENDM

    ; mPrtX -- Print a variety of different things to the display
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: "position export" keyword (see mPrtMem notes)
    ;   \5: what to print (see notes)
    ; Notes:
    ;   All notes of mPrtMem apply here as well.
    ;   \5 can be any of the following:
    ;       <'A literal string'> - print this string
    ;       endl - "carriage return": skip to the next line's first character
    ;       pendl - like endl, but pauses for user keystroke on full screen
    ;       qpendl - like pendl, but issues an RTS if the user types a 'q' at a
    ;                pause---make sure there's nothing else on the stack!
    ;       hhx - pop a byte from the stack and print its hex representation
    ;       hx - pop a word from the stack and print its hex representation
    ;       3x - pop a long from the stack and print the hex representation of
    ;            its lower three bytes
    ;       lx - pop a long from the stack and print its hex representation
    ;       s - pop an address and print the null-terminated string there
    ;   After an (p)endl/"carriage return", no display scrolling will occur
    ;       until a character is printed on the new line. Additionally and for
    ;       this reason, two endls in sequence will not yield a blank line if
    ;       the screen is already full. To force a blank line, print a $0D
    ;       character instead, or if paging, perhaps follow `pendl`s with
    ;       `mPrtLit kCrtRow,kCrtCol,#kFirstCol,no_export,<' '>`.
    ;   The "countdown" to the paging event that occurs after enough `pendl`s
    ;       can be changed by altering the value in the zLineCount byte, or
    ;       reset by invoking the `mResetP` macro.
    ;   See the PAGEDNEWLINE subroutine for further information on `pendl`.
    ;   See PAGEDNEWLINE and PAGEDRTS for further information on `qpendl`.
mPrtX       MACRO
              IFC <'\5'>,<'qpendl'>
      mPrtCrP \1,\2,\3               ; Move to the next line, with paging
      BSR     PAGEDRTS               ; Break out of current subroutine on 'q'
              ENDC
              IFC <'\5'>,<'pendl'>
      mPrtCrP \1,\2,\3               ; Move to the next line, with paging
              ENDC
              IFC <'\5'>,<'endl'>
      mPrtCr  \1,\2,\3               ; Move to the next line
              ENDC
              IFC <'\5'>,<'hhx'>
      mPrtHxB \1,\2,\3,\4            ; Print a hex byte on the stack
              ENDC
              IFC <'\5'>,<'hx'>
      mPrtHxW \1,\2,\3,\4            ; Print a hex word on the stack
              ENDC
              IFC <'\5'>,<'3x'>
      mPrtHx3 \1,\2,\3,\4            ; Print a 3-byte int on the stack
              ENDC
              IFC <'\5'>,<'lx'>
      mPrtHxL \1,\2,\3,\4            ; Print a hex long on the stack
              ENDC
              IFC <'\5'>,<'s'>
      mPrtStr \1,\2,\3,\4            ; Print a string at an address on the stack
              ENDC
              IFNC <'\5'>,<'qpendl'>
              IFNC <'\5'>,<'pendl'>  ; A proper else clause would be nice...
              IFNC <'\5'>,<'endl'>
              IFNC <'\5'>,<'hhx'>
              IFNC <'\5'>,<'hx'>
              IFNC <'\5'>,<'3x'>
              IFNC <'\5'>,<'lx'>
              IFNC <'\5'>,<'s'>
      mPrtLit \1,\2,\3,\4,<\5>       ; Print a literal string
              ENDC
              ENDC
              ENDC
              ENDC
              ENDC
              ENDC
              ENDC
              ENDC
            ENDM

    ; mPrint -- The closest thing we have to printf
    ; Args:
    ;   \1: pixel row of the string's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4 and optionally up to \9: what to print (see notes)
    ; Notes:
    ;   This macro behaves as if the "position export" keyword to mPrtMem is
    ;       always "export"; that is, \1 and \2 are always updated with the
    ;       cursor location post-printing.
    ;   All other notes of mPrtMem apply here as well; take note of those
    ;       pertaining to the "position export" keyword and registers.
    ;   \4 to \9 can be any of the following:
    ;       <'A literal string'> - print this string
    ;       endl - "carriage return": skip to the next line's first character
    ;       pendl - like endl, but pauses for user keystroke on full screen
    ;       qpendl - like pendl, but issues an RTS if the user types a 'q' at a
    ;                pause---make sure there's nothing else on the stack!
    ;       hhx - pop a byte from the stack and print its hex representation
    ;       hx - pop a word from the stack and print its hex representation
    ;       3x - pop a long from the stack and print the hex representation of
    ;            its lower three bytes
    ;       lx - pop a long from the stack and print its hex representation
    ;       s - pop an address and print the null-terminated string there
    ;   After an endl/"carriage return", no display scrolling will occur until
    ;       a character is printed on the new line. Additionally and for this
    ;       reason, two endls in sequence will not yield a blank line if the
    ;       character instead, or if paging, perhaps follow `pendl`s with
    ;       `mPrtLit kCrtRow,kCrtCol,#kFirstCol,no_export,<' '>`.
    ;   The "countdown" to the paging event that occurs after enough `pendl`s
    ;       can be changed by altering the value in the zLineCount byte, or
    ;       reset by invoking the `mResetP` macro.
    ;   See the PAGEDNEWLINE subroutine for further information on `pendl`.
    ;   See PAGEDNEWLINE and PAGEDRTS for further information on `qpendl`.
mPrint      MACRO
              IFARG 4
      mPrtX   \1,\2,\3,export,<\4>
              ENDC
              IFARG 5
      mPrtX   \1,\2,\3,export,<\5>
              ENDC
              IFARG 6
      mPrtX   \1,\2,\3,export,<\6>
              ENDC
              IFARG 7
      mPrtX   \1,\2,\3,export,<\7>
              ENDC
              IFARG 8
      mPrtX   \1,\2,\3,export,<\8>
              ENDC
              IFARG 9
      mPrtX   \1,\2,\3,export,<\9>
              ENDC
            ENDM

    ; mMenuUi -- Execute a drop-down-menu-driven based UI loop
    ; Args:
    ;   \1: Address of a menu string table (see MENU for details)
    ;   \2: Address of a table of addresses of subroutine handlers for each
    ;       menu item. Ordinarily, a newline is printed before a handler is
    ;       called, but if the least significant bit of the handler's address
    ;       is 1, no newline is printed. (The bit will be cleared prior to
    ;       calling the handler, of course.)
    ; Notes:
    ;   Will loop until a user selects a menu option that executes GOBACK.
    ;   Unless you know what you're doing, both arguments should probably be
    ;       literal memory locations (as they will be expected to persist
    ;       through multiple invocations of UILOOP and the handlers. See the
    ;       definition of UILOOP for more details.
    ;   If the caller could have been invoked from another UILOOP menu, and if
    ;       it might change flags before RTSing, it should TST.B zUiLoopBreak
    ;       just before it actually does return.
    ;   Trashes (minimally) D0-D6/A1-A4, plus whatever the handlers trash.
mMenuUi     MACRO
.l\@  MOVE.L  \1,zUiLoopMenu         ; Load UI loop arguments
      MOVE.L  \2,zUiLoopMenuHandlers
      BSR     UILOOP                 ; Execute the UI loop indefinitely
      BMI.S   .l\@                   ; If a submenu exited, repeat the UI loop
      NEG.B   zUiLoopBreak           ; Otherwise, mark this menu as exiting
            ENDM

    ; mMemCpy -- Copy bytes from one memory location to another
    ; Args:
    ;   \1: Starting source address
    ;   \2: Starting destination address
    ;   \3: Number of bytes to copy
    ; Notes:
    ;   Behaviour is undefined if source and destination memory regions overlap.
    ;   Will not work if the destination address is A0.
mMemCpy     MACRO
      MOVEM.L A0-A1,-(A7)            ; Save address registers
      MOVEM.W D0,-(A7)               ; Save data register
            IFNC '\1','A0'
      MOVEA.L \1,A0                  ; Copy source address to A0
            ENDC
            IFNC '\2','A1'
      MOVEA.L \2,A1                  ; Copy destination address to A1
            ENDC
            IFNC '\3','D0'
      MOVE.W  \3,D0                  ; Copy byte count to D0
            ENDC
      SUBQ.L  #1,D0                  ; Decrement byte count by 1
.c\@  MOVE.B  (A0)+,(A1)+            ; Copy next byte from source to dest
      DBRA    D0,.c\@                ; Loop until done
      MOVEM.W (A7)+,D0               ; Restore data register
      MOVEM.L (A7)+,A0-A1            ; Restore address registers
            ENDM

    ; mMemSet -- Set bytes in a contiguous memory region to one value
    ; Args:
    ;   \1: Byte to fill the memory region with
    ;   \2: Starting destination address
    ;   \3: Number of bytes to set
    ; Notes:
    ;   Behaviour undefined if destination memory region overlaps source byte.
mMemSet     MACRO
      MOVEM.L A0,-(A7)               ; Save address register
      MOVEM.W D0-D1,-(A7)            ; Save data registers
            IFNC '\1','D0'
      MOVE.B  \1,D0                  ; Copy source byte to D0
            ENDC
            IFNC '\2','A0'
      MOVEA.L \2,A0                  ; Copy destination address to A0
            ENDC
            IFNC '\3','D1'
      MOVE.W  \3,D1                  ; Copy byte count to D1
            ENDC
      SUBQ.L  #1,D1                  ; Decrement byte count by 1
.c\@  MOVE.B  D0,(A0)+               ; Copy next byte from source to dest
      DBRA    D1,.c\@                ; Loop until done
      MOVEM.W (A7)+,D0-D1            ; Restore data register
      MOVEM.L (A7)+,A0               ; Restore address register
            ENDM

    ; mDump -- Print contiguous bytes, words, or longs, separated by spaces
    ; Args:
    ;   \1: pixel row of the dump text's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: address register pointing to the first data item to print
    ;   \5: number of data items to print---must be a byte
    ;   \6: mPrtX/mPrint symbol for generating newlines; must be either
    ;       `endl`, `pendl`, or `qpendl`
    ; Notes:
    ;   A data length suffix (.B, .W, .L) MUST be present after `mDump`.
    ;   This macro behaves as if the "position export" keyword to mPrtMem is
    ;       always "export"; that is, \1 and \2 are always updated with the
    ;       cursor location post-printing.
    ;   Prior contents of D0 will be destroyed. If you choose to save D0 on
    ;       the stack prior to invoking mDump, you must not specify the `qpendl`
    ;       symbol for newline generation.
    ;   The address register specified in \4 will not be restored to its
    ;       original value after invoking mDump.
mDump       MACRO
      mPrint  kCrtRow,kCrtCol,#kFirstCol,\6,<'  '>
            IFNC '\5','D0'
      CLR.W   D0                     ; Clear D0 word in prep to be an iterator
      MOVE.B  \5,D0                  ; Number of items to dump into D0
            ENDC
      SUBQ.B  #1,D0                  ; Minus 1 to make it a loop counter
            IFC '\0','B'
      m_dlp.B \1,\2,\3,\4,\6,60      ; Inner loop (for bytes)
            ENDC
            IFC '\0','W'
      m_dlp.W \1,\2,\3,\4,\6,58      ; Inner loop (for words)
            ENDC
            IFC '\0','L'
      m_dlp.L \1,\2,\3,\4,\6,56      ; Inner loop (for longs)
            ENDC
            ENDM

    ; m_dlp -- Implements the loop inside mDump
    ; Args:
    ;   \1: pixel row of the dump text's first line
    ;   \2: character column of the first line's first character
    ;   \3: character column of the next lines' first characters
    ;   \4: address register pointing to the first data item to print
    ;   \5: mPrtX/mPrint symbol for generating newlines; must be either
    ;       `endl`, `pendl`, or `qpendl`
    ;   \6: item display should move on to the next line whenever the cursor
    ;       advances to or beyond this column
    ; Notes:
    ;   A helper macro for mDump; not intended for use elsewhere.
    ;   All notes from mDump apply here as well.
    ;   D0 must already be set up as a loop counter for counting the number of
    ;       items to print.
m_dlp       MACRO
.l\@  CMPI.W  #(kFirstCol+\6),\2     ; Do we need a new line?
      BLO.S   .p\@                   ; No, print the item
      mPrint  \1,\2,\3,\5,<'  '>     ; Yes, new line, indent
.p\@  MOVE.\0 (\4)+,-(A7)            ; Next item onto stack to print
            IFC '\0','B'
      mPrint  \1,\2,\3,<' '>,hhx     ; Print space and item (for bytes)
            ENDC
            IFC '\0','W'
      mPrint  \1,\2,\3,<' '>,hx      ; Print space and item (for words)
            ENDC
            IFC '\0','L'
      mPrint  \1,\2,\3,<' '>,lx      ; Print space and item (for longs)
            ENDC
      DBRA    D0,.l\@                ; Loop to next item
            ENDM

    ; m_hb2s -- Helper code core for converting bytes to ASCII hex digits
    ; Args:
    ;   D2: byte to turn into two ASCII hex digits
    ;   A3: points just beyond the two bytes that will hold the two hex digits
    ; Notes:
    ;   A helper macro for HEX_2STR procedures; not intended for use elsewhere.
m_hb2s      MACRO
      ; Lower nibble of byte
      MOVE.B  D0,-(A3)               ; Copy byte to string digit
      ANDI.B  #$0F,(A3)              ; Isolate lower nibble
      CMPI.B  #$0A,(A3)              ; Is it less than $A?
      BLO.S   .a1\@                  ; Yes, skip to ASCII-fication
      ADDQ.B  #7,(A3)                ; No, add ASCII 'A'-'9'-1 to the byte
.a1\@ ADDI.B  #$30,(A3)              ; Add ASCII '0' to the byte

      ; Upper nibble of byte
      ROR.B   #4,D0                  ; Rotate upper nibble to lower
      MOVE.B  D0,-(A3)               ; Copy byte to string digit
      ROR.B   #4,D0                  ; Rotate lower nibble back to lower
      ANDI.B  #$0F,(A3)              ; Isolate lower nibble
      CMPI.B  #$0A,(A3)              ; Is it less than $A?
      BLO.S   .a2\@                  ; Yes, skip to ASCII-fication
      ADDQ.B  #7,(A3)                ; No, add ASCII 'A'-'9'-1 to the byte
.a2\@ ADDI.B  #$30,(A3)              ; Add ASCII '0' to the byte
            ENDM

    ; m_cp3b -- Helper code for copying three bytes into a data register
    ; Args:
    ;   \1: Location of the three bytes to copy
    ;   \2: Data register receiving the three bytes
    ; Notes:
    ;   Most-significant byte of the register will be cleared.
m_cp3b      MACRO
      MOVEM.L A0,-(A7)               ; Save A0 on the stack
      CLR.L   \2                     ; Clear \0
            IFNC '\1','A0'
      MOVEA.L \1,A0                  ; Memory location of the three bytes
            ENDC
      MOVE.B  (A0)+,\2               ; Copy first device number byte
      LSL.W   #8,\2                  ; Shift byte for next device number byte
      MOVE.B  (A0)+,\2               ; Copy second device number byte
      LSL.L   #8,\2                  ; Shift word for next device number byte
      MOVE.B  (A0)+,\2               ; Copy third device number byte
      MOVEM.L (A7)+,A0               ; Restore A0
            ENDM

    ; m_iOff -- Disable interrupts
    ; Args:
    ;   (none)
    ; Notes:
    ;   Saves current value of the status register to the stack.
m_iOff      MACRO
      MOVE.W  SR,-(A7)
      ORI.W   #$0700,SR
            ENDM

    ; m_iOn -- Restore status register from stack, usually reenabling interrupts
    ; Args:
    ;   (none)
    ; Notes:
    ;   Usually used in tandem with `m_iOff`.
m_iOn       MACRO
      MOVE.W  (A7)+,SR
            ENDM
