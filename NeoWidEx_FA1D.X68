*-----------------------------------------------------------
* Title      : NeoWidEx_FA1D
* Written by : Tom Stepleton
* Date       : 29 March 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: unidimensional aperiodic system
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*-----------------------------------------------------------


* NeoWidEx FA1D code =======================================

    ; FA1D -- Display a 1-D finite automaton
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D3/A0-A1.
FA1D:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- RULE 30 ---'>

    ; Initialise bitstring buffer, which is 62 characters with two zero padding
    ; bytes at either end.
    mMemSet #0,#zSectorData,#64      ; Zero out the buffer
    MOVE.B  #$1,(31+zSectorData)     ; Put a 1 bit right in the centre

.lp MOVEA.L kScreen,A1               ; Screen addr to A1; + bottom text 1st byte
    ADDA.W  #((kLastRow+kCharHeight)*kRowBytes+kFirstCol),A1
    mMemCpy #(zSectorData+1),A1,#62  ; Copy finite automaton state to screen

    JSR     QUITPOLL                 ; Did the user type 'q'?
    BEQ.S   .ok                      ; If so, jump ahead to exit
    BSR.S   _FA1D_Step               ; Compute next automaton state
    BSR.S   _FA1D_Scroll             ; Scroll up one pixel row
    BRA.S   .lp                      ; Back to top of loop

.ok MOVE.W  #kLastRow,kCrtRow        ; Move cursor to last row
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller


    ; _FA1D_Scroll -- Scroll service mode text window by a single line
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0/A0-A1.
_FA1D_Scroll:
    MOVEA.L kScreen,A1               ; Screen addr to A1; + top text first byte
    ADDA.W  #((kFirstRow+kCharHeight+2)*kRowBytes+kFirstCol),A1
    MOVEA.L A1,A0                    ; Copy to A0
    ADDA.W  #kRowBytes,A0            ; Advance A0 to next pixel row
    MOVE.W  #(kLastRow-(kFirstRow+2)-1),D0   ; Number-1 of rows to copy

.lp mMemCpy A0,A1,#(kSvcWidth-2)     ; Copy pixels to prior row
    MOVEA.L A0,A1                    ; Advance A1 by one pixel row
    ADDA.W  #kRowBytes,A0            ; Advance A2 by one pixel row
    DBRA    D0,.lp                   ; Loop again to copy remaining rows

    RTS                              ; Back to caller


    ; _FA1D_Step -- Advance finite automaton in zSectorData one iteration
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D3/A0.
_FA1D_Step:
    ; Outer loop: apply Rule 30 update to the buffer.
    ; Registers (more named at inner loop):
    ;   D0: rolling window over original bits in buffer
    ;   D1: counter counting down the 62 bytes we'll modify
    ;   A0: byte whose bits we're modifying now
    ; First, preparation for outer loop:
    LEA     zSectorData,A0           ; Start of buffer into A0
    MOVE.B  (A0)+,D0                 ; Left padding byte into D0 and advance
    LSL.W   #8,D0                    ; Shift padding byte into high-order bits
    MOVE.B  (A0),D0                  ; First byte we'll modify into D0
    ; The next three lines make sure that the pattern remains interesting once
    ; it hits the edges of the screen: it increments the left-side padding byte
    ; if the leftmost bit on the display is high.
    BTST.L  #7,D0                    ; Is the leftmost bit on the display high?
    BEQ.S   .go                      ; No, move on
    ADD.W   #$0100,D0                ; Yes, increment leftmost padding byte

.go MOVE.W  #61,D1                   ; Counts down bytes in the buffer
    ROR.W   #6,D0                    ; Rotate Rule 30 context bits to LSBits
    ; Top of outer loop is here:
.lo CLR.B   D3                       ; Clear scratch byte

    ; Inner loop: apply Rule 30 update to the byte pointed to by A0.
    ; Registers:
    ;   D2: count down bits in the byte pointed to by A0.
    ;   D3: replacement bits for the byte pointed to by A0.
    ; Now, preparation for inner loop:
    MOVEQ.L #7,D2                    ; Count downward from 7 through 0
    ; The implementation of Rule 30 itself. The rule works like this:
    ; Given Bit2, Bit1, Bit0, where Bit1 is the bit we wish to change and
    ; Bit2 and Bit0 are its neighbors,
    ;
    ;                             Bit1
    ;                          0 /    \ 1
    ;        Bit1 = Bit2 XOR Bit0      Bit1 = NOT Bit2.
    ;
    ; Top of inner loop is here:
.li BTST.L  #1,D0                    ; Is the bit above the current bit high?
    BEQ.S   .bl                      ; No, skip to left branch
    BTST.L  #2,D0                    ;   RIGHT BRANCH: Is bit 2 set?
    BEQ.S   .sb                      ;     No, so set the bit and move on
    BRA.S   .nx                      ;     Yes, just move on to the next bit
.bl BTST.L  #2,D0                    ;   LEFT BRANCH: Is bit 2 set?
    BEQ.S   .bx                      ;     No, go to other half of XOR
    BTST.L  #0,D0                    ;     Yes, is bit 0 set?
    BEQ.S   .sb                      ;       No, so set the bit and move on
    BRA.S   .nx                      ;       Yes, just move on to the next bit
.bx BTST.L  #0,D0                    ;     No, is bit 0 set?
    BNE.S   .sb                      ;       Yes, so set the bit and move on
    BRA.S   .nx                      ;       No, just move on to the next bit

.sb BSET.L  D2,D3                    ; Set bit on scratch byte
.nx CMPI.B  #7,D2                    ; Have we just updated the MSBit?
    BEQ.S   .bc                      ; Yes! Jump to copy next byte into window
    ROL.W   #1,D0                    ; No, rotate rolling window one bit
    DBRA    D2,.li                   ; Back to top of inner loop
    BRA.S   .cb                      ; Jump ahead to bottom of outer loop

.bc ROR.W   #2,D0                    ; Rotate rolling win prior byte into LSByte
    MOVE.B  1(A0),D0                 ; Copy next byte over it
    ROL.W   #3,D0                    ; Rotate rolling win back for next bit
    DBRA    D2,.li                   ; Back to top of inner loop

    ; Done with inner loop. In outer loop, move to next byte.
.cb MOVE.B  D3,(A0)+                 ; Copy scratch byte to A0 byte and advance
    DBRA    D1,.lo                   ; Repeat outer loop if bytes left to go

    RTS                              ; Back to caller


    PAGE
* NeoWidEx FA1D strings =====================================
    SECTION kSecStrings


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
