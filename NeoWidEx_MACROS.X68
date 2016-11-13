*-----------------------------------------------------------
* Title      : NeoWidEx_MACROS
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: macros.
*      Display subroutines from NeoWidEx_UI must be defined.
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
      MOVEM.L D0/D4-D6,-(A7)         ; Save register contents
              IFNC '\1','D5'
      MOVE.W \1,D5                   ; First line row (pixels)
              ENDC
              IFNC '\2','D6'
      MOVE.W \2,D6                   ; First line first column (chars/bytes)
              ENDC
              IFNC '\3','D4'
      MOVE.W \3,D4                   ; Next line first column (chars/bytes)
              ENDC
              IFNC '\5','A3'
      MOVEM.L A3,-(A7)               ; Save A3 contents
      MOVEA.L \5,A3                  ; Memory address of string to print
              ENDC
      JSR     kDispMsg               ; Print the message
              IFC '\4','export'
      MOVE.W D5,\1                   ; Export new first line row if desired
      MOVE.W D6,\2                   ; Export new first line column if desired
              ENDC
              IFNC '\5','A3'
      MOVEM.L (A7)+,A3               ; Restore A3 contents
              ENDC
      MOVEM.L (A7)+,D0/D4-D6         ; Restore register contents
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
      ADDA.W  #2,A7                  ; Drop byte from stack
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
      ADDA.W  #2,A7                  ; Drop byte from stack
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
      ADDA.W  #4,A7                  ; Drop byte from stack
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
      ADDA.W  #4,A7                  ; Drop byte from stack
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
      ADDA.W  #4,A7                  ; Drop address from stack
            ENDM

    ; mPrtCr -- "Print" a carriage return, i.e. move to the next line.
    ; Args:
    ;   \1: where to store new pixel row of the string's first line
    ;   \2: where to store character column of the next line's first character
    ;   \3: character column of the next line's first character
    ; Notes:
    ;   The "position export" keyword "export" (see mPrtMem notes) is implied.
    ;   The ROM's kDispMsg routine will not scroll the Service Mode window
    ;       immediately if the new current row is out-of-bounds. Scrolling only
    ;       occurs when a character is printed on an out-of-bounds row.
    ;       Additionally and for this reason, two endls in sequence will not
    ;       yield a blank line if the screen is already full. To force a blank
    ;       line, print a $0D character instead.
mPrtCr      MACRO
      ADDI.W  #kCharHeight,\1
      MOVE.W  \3,\2
            ENDM

    ; mPrtX -- Print a variety of different things to the display
    ; args:
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
    ;       hhx - pop a byte from the stack and print its hex representation
    ;       hx - pop a word from the stack and print its hex representation
    ;       3x - pop a long from the stack and print the hex representation of
    ;            its lower three bytes
    ;       lx - pop a long from the stack and print its hex representation
    ;       s - pop an address and print the null-terminated string there
    ;   After an endl/"carriage return", no display scrolling will occur until
    ;       a character is printed on the new line. Additionally and for this
    ;       reason, two endls in sequence will not yield a blank line if the
    ;       screen is already full. To force a blank line, print a $0D
    ;       character instead.
mPrtX       MACRO
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
              IFNC <'\5'>,<'endl'>   ; A proper else clause would be nice...
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
            ENDM

    ; mPrint -- The closest thing we have to printf
    ; args:
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
    ;       hhx - pop a byte from the stack and print its hex representation
    ;       hx - pop a word from the stack and print its hex representation
    ;       3x - pop a long from the stack and print the hex representation of
    ;            its lower three bytes
    ;       lx - pop a long from the stack and print its hex representation
    ;       s - pop an address and print the null-terminated string there
    ;   After an endl/"carriage return", no display scrolling will occur until
    ;       a character is printed on the new line. Additionally and for this
    ;       reason, two endls in sequence will not yield a blank line if the
    ;       screen is already full. To force a blank line, print a $0D
    ;       character instead.
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

    ; mMemCpy -- Copy bytes from one memory location to another
    ; Args:
    ;   \0: Starting source address
    ;   \1: Starting destination address
    ;   \2: Number of bytes to copy
    ; Notes:
    ;   Behaviour is undefined if source and destination memory regions overlap.
mMemCpy     MACRO
      MOVEM.L  A0-A1,-(A7)           ; Save address registers
      MOVEM.W  D0,-(A7)              ; Save data register
            IFNC '\1','A0'
      MOVEA.L  \1,A0                 ; Copy source address to A0
            ENDC
            IFNC '\2','A1'
      MOVEA.L  \2,A1                 ; Copy destination address to A1
            ENDC
            IFNC '\3','D0'
      MOVE.L   \3,D0                 ; Copy byte count to D0
            ENDC
      SUBQ.L   #1,D0                 ; Decrement byte count by 1
.c\@  MOVE.B   (A0)+,(A1)+           ; Copy next byte from source to dest
      DBEQ     D0,.c\@               ; Loop until done
      MOVEM.W  (A7)+,D0              ; Restore data register
      MOVEM.L  (A7)+,A0-A1           ; Restore address register
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
