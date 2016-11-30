*-----------------------------------------------------------
* Title      : NeoWidEx_UI
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: UI subroutines, data, and scratch areas.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*-----------------------------------------------------------


* NeoWidEx UI code =========================================

    ; MAKEWORLD -- Draw desktop, set up display window, print welcome message
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes registers: A1-A2,A6/D0-D1, and likely many others (study of
    ;       the ROM routines called here would be required to know which).
MAKEWORLD:
    JSR     kClearDesk               ; Clear the desktop
    MOVEA.L #kSvcStart,A1            ; Address of window top left corner
    MOVEQ   #kSvcWidth,D0            ; Window width in bytes
    MOVE.L  #kSvcHeight,D1           ; Window height in lines
    LEA     sNeoWidEx,A3             ; Window title, 'NEOWIDEX'
    JSR     kMakeWindow              ; Draw service mode window

    ; Print welcome message.
    MOVE.W  #kFirstRow,kCrtRow       ; Set starting text row
    MOVE.W  #kFirstCol,kCrtCol       ; Set starting text column
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sWelcome

    ; Draw cute icons from the ROM.
    LEA     kIconLisa,A2             ; Address for the ROM's Lisa icon
    MOVEA.L kScreen,A6               ; Screen start address
    ADDA.L  #kIcn1Offset,A6          ; Now the address for icon's NW corner
    JSR     kDispIcon                ; Show the icon
    LEA     kIconUpper,A2            ; Address for the upper drive
    MOVEA.L kScreen,A6               ; Screen start address
    ADDA.L  #kIcn2Offset,A6          ; Now the address for icon's NW corner
    JSR     kDispIcon                ; Show the icon

    RTS                              ; Back to caller

    ; MENU -- Display and solicit (blocking) input from a drop-down menu
    ; Args:
    ;   A3: Address of the menu string table
    ; Notes:
    ;   Menu items will be given the hotkeys 1,2,...,9,A,B,...,Z.
    ;   The menu string table is expected to be a contiguous, null-terminated
    ;       sequence of null-terminated strings.
    ;   The first string in the table is the menu title and is not considered
    ;       when finding the number and max width of menu items
    ;   Places the number of menu items onto the stack, followed by the width
    ;       of the longest menu item.
    ;   ID of the selected menu item will be placed in D0. The LSByte is the
    ;       Lisa keycode of the selected item; the adjacent byte is something
    ;       having to do with rectangles that I haven't figured out yet.
    ;   Trashes registers: D0-D6/A1-A4.
MENU:
    ; Blank out any prior menu by painting one line at the time
    MOVEA.W #kDeskLine,A2            ; The top line to blank out
    MOVE.L  #$AAAA5555,D2            ; Pattern to paint; words will alternate

.gr SWAP    D2                       ; Alternate the pattern for this line
    MOVE.L  #22,D0                   ; Blank an area 18 bytes wide
    MOVEQ.L #1,D1                    ; Paint only one line at a time
    MOVEA.L A2,A1                    ; Line starts at this screen offset
    JSR     kPaintBox                ; Paint the line

    ADDA.W  #kRowBytes,A2            ; On to the next line
    CMPA.W  #kDeskLimit,A2           ; Are we at the end of the screen?
    BLO.S   .gr                      ; If not, paint another line

    ; Count items in the menu.
    CLR.L   -(A7)                    ; Make stack space for item count and width
    BSR.W   MENUCOUNT                ; Count the items in that menu

    ; Compute menu geometry based on item count..
    CLR.W   kRectCount               ; There are no active rectangles
    ANDI.B  #$0F,kStatFlags          ; Various status flags are also cleared
    MOVE.W  (A7)+,D0                 ; Move widest menu item width to D0
    ADDQ.W  #3,D0                    ; Plus 3 rounded down to nearest even...
    ANDI.B  #$FE,D0                  ; ...is the width of the menu itself
    MOVE.W  (A7),D1                  ; Copy number of menu items to D1
    MULU.W  #11,D1                   ; Times 11 is the menu length

    ; Draw menu box. kDispMnuBox trashes A3, so we have to save it. We also
    ; have to overwrite the ROM's keyboard ID byte with 0 temporarily so that
    ; kDispMnuBox doesn't try to use locale-specific menu title strings.
    MOVE.L  A3,-(A7)                 ; Save main menu strings address to stack
    MOVE.B  kKeyId,-(A7)             ; Save keyboard ID byte
    CLR.B   kKeyId                   ; Clear keyboard ID byte
    JSR     kDispMnuBox              ; Draw the menu box
    MOVE.B  (A7)+,kKeyId             ; Restore keyboard ID byte
    MOVE.L  (A7)+,A3                 ; Restore main menu strings address

    ; Advance A3 past the menu title to the first menu item.
.mt TST.B   (A3)+                    ; Was this the null terminator?
    BNE.S   .mt                      ; No, keep looking

    ; Draw menu items
    MOVE.W  (A7)+,D4                 ; Move number of menu items to D4
    MOVEA.L #kMenuStart,A1           ; Starting address for menu box
    MOVEA.L #kMenu1Msg,A2            ; Starting address for menu option message
    LEA     dMenuIds,A4              ; Main menu IDs
    JSR     kMakeMenu                ; Draw the menu items

    ; Get user input
    JSR     kCrsrDsply               ; Redisplay mouse cursor
    CLR.L   D0                       ; Clear kGetInput result
    JSR     kGetInput                ; Get user input
    BCC.S   .ok                      ; No problems; process user input
    JMP     kGetError                ; Error; bail to ROM
.ok JSR     kCrsrHide                ; Hide mouse cursor
    RTS                              ; Back to caller

    ; MENUCOUNT -- Find the number and max width of items in a drop-down menu
    ; Args:
    ;   A3: Address of the menu string table.
    ; Notes:
    ;   The menu string table is expected to be a contiguous, null-terminated
    ;       sequence of null-terminated strings.
    ;   The first string in the table is the menu title and is not considered
    ;       when finding the number and max width of menu items
    ;   Places the number of menu items onto the stack, followed by the width
    ;       of the longest menu item.
MENUCOUNT:
    MOVEM.L D0-D2/A3,-(A7)           ; Save registers we'll overwrite

.tl TST.B   (A3)+                    ; End of the menu title string yet?
    BNE.S   .tl                      ; Not yet, keep looking

    CLR.W   D0                       ; Number of menu items seen so far
    CLR.W   D1                       ; Width of the current menu item
    CLR.W   D2                       ; Width of the widest menu item

.lp TST.B   (A3)+                    ; Is this byte a null terminator?
    BEQ.S   .n0                      ; It's a null terminator; handle it
    ADDQ.W  #1,D1                    ; It's not. This item is one char wider
    BRA.S   .lp                      ; On to the next character

.n0 ADDQ.W  #1,D0                    ; Increment number of menu items seen
    CMP.W   D1,D2                    ; Was this menu item wider than any before?
    BHS.S   .n1                      ; No, carry on
    MOVE.W  D1,D2                    ; Yes, save the new champion
.n1 TST.B   (A3)                     ; Is this byte a null terminator?
    BEQ.S   .dn                      ; It is; done with items; prepare to return
    CLR.W   D1                       ; It's not; start next menu item len at 0
    BRA.S   .lp                      ; Loop to examine this next menu item

.dn MOVE.W  D0,$16(A7)               ; Save menu item count to stack
    MOVE.W  D2,$14(A7)               ; Save menu item width to stack
    MOVEM.L (A7)+,D0-D2/A3           ; Restore saved registers
    RTS                              ; Back to caller

    ; BSUBDISPMSG -- Print a string, substituting bits from D1 where directed
    ; Args:
    ;   A3: memory address of string to print
    ;   D3: source of bits to substitute into the string specified by A3
    ;   D4: character column of the next lines' first characters
    ;   D5: pixel row of the string's first line
    ;   D5: character column of the first line's first character
    ; Notes:
    ;   Works the same as DSPMSG, but whenever an ASCII character in the range
    ;       '_'..'~' is encountered, the bit value of bit 0..31 (respectively)
    ;       of D1 is substituted in place of the character (as '0' or '1').
    ;   May trash A6 if scrolling is required (just like DSPMSG).
    ;   String can be multi-line, with lines split by carriage return ($0D).
BSUBDISPMSG:
    MOVE.L  D0,-(A7)                 ; Save D0 contents to stack
.lp CMPI.W  #kLastRow,D5             ; Check if cursor has gone below page
    BLE.S   .ns                      ; Skip ahead if not
    JSR     kScroll                  ; If so, scroll up a page
.ns CLR.L   D0                       ; Clear scratch space
    MOVE.B  (A3)+,D0                 ; Get next char to display
    BEQ.S   .rt                      ; Exit on null terminator
    CMPI.B  #'_',D0                  ; See if we need to substitute a bit here
    BLO.S   .dv                      ; No, skip ahead to print it
    SUBI.B  #'_',D0                  ; Change character to a bit index
    BTST.L  D0,D3                    ; See if the D3 bit at the index is set
    BNE.S   .p1                      ; It is, skip ahead to print a 1
    MOVE.B  #'0',D0                  ; It wasn't, here is the 0 we will print
    BRA.S   .dv                      ; Skip ahead to print that 0
.p1 MOVE.B  #'1',D0                  ; Here is the 1 we will print
.dv JSR     kDispVal                 ; Print the character
    BRA.S   .lp                      ; Loop to print the next character
.rt MOVE.L  (A7)+,D0                 ; Restore D0 contents
    RTS

    ; PAGEDNEWLINE -- move to next line, paging the display if necessary
    ; Args:
    ;   D4: character column of the next line's first character
    ;   D5: pixel row of the string's first line (will be updated)
    ;   D6: current character column
    ; Notes:
    ;   When called kPagerLines times, will print "--MORE--" on the new line and
    ;       await a keypress from the user. After the keypress, the "--MORE--"
    ;       is deleted.
    ;   The "countdown" to the paging event can be changed by altering the value
    ;       in the zLineCount byte.
    ;   If the user presses the 'Return' key, paging will go line-by-line. If
    ;       the user presses any other key, paging will go screen-by-screen.
    ;   If the user presses 'q' during a paging event, the byte at zStopPaging
    ;       will be nonzero; otherwise it will be set to 0. The PAGEDRTS
    ;       "subroutine" may be of use in dealing with this.
    ;   The ROM's kDispMsg routine will not scroll the Service Mode window
    ;       immediately if the new current row is out-of-bounds. Scrolling only
    ;       occurs when a character is printed on an out-of-bounds row.
    ;       Additionally and for this reason, two invocations in sequence will
    ;       not yield a blank line if the screen is already full---but the
    ;       paging behaviour carries on as if it did anyway. To force a blank
    ;       line, the most effective way is maybe to call this subroutine and
    ;       then `mPrtLit kCrtRow,kCrtCol,#kFirstCol,no_export,<' '>`.
PAGEDNEWLINE:
    MOVEM.L D0/A3,-(A7)              ; Save registers we might use
    ADDI.W  #kCharHeight,D5          ; Advance row to the next line
    MOVE.W  D4,D6                    ; Reset column to the left margin
    CLR.B   zStopPaging              ; Clear "user pressed q" byte
    SUBQ.B  #1,zLineCount            ; Decrement lines left until time to pause
    BHI.S   .rt                      ; Still have some? Skip ahead to return
    MOVEA.L #.s0,A3                  ; Point A3 at "Press any key" string...
    JSR     kDispMsg                 ; ...and print it...
    MOVE.W  D4,D6                    ; Reset column to the left margin
.lp JSR     kWait4Input              ;   Get an event from the COPS
    TST.B   D0                       ;   Was it a keyboard event?
    BPL.S   .lp                      ;   No, wait again
    MOVEA.L #.s1,A3                  ; Point A3 at blanking string...
    JSR     kDispMsg                 ; ...and print it
    MOVE.W  D4,D6                    ; Reset column to the left margin
    CMPI.B  #$F5,D0                  ; Did the user press the 'Q' key?
    SEQ.B   zStopPaging              ; Mark in memory if so
    MOVE.B  #kPagerLines,zLineCount  ; Reset lines left
    CMPI.B  #$C8,D0                  ; But wait, did the user press Return?
    BNE.S   .rt                      ; No, nevermind, go a full screen at a time
    MOVE.B  #1,zLineCount            ; Yes! So only advance one line
.rt MOVEM.L (A7)+,D0/A3              ; Restore saved registers
    RTS                              ; Back to caller
.s0 DC.B    '--MORE--',0             ; "Any key to continue" string
.s1 DC.B    '        ',0             ; String to blank out the above

    ; PAGEDRTS -- Return to caller's caller if user pressed 'q' while paging
    ; Args:
    ;   (none)
    ; Notes:
    ;   Checks the value stored at zStopPaging; if nonzero, the return address
    ;       for the call to PAGEDRTS is dropped from the stack and RTS is
    ;       executed, returning to the caller's caller.
    ;   Will NOT work if the subroutine that called PAGEDRTS places ANYTHING
    ;       on the stack prior to the BSR or JSR to PAGEDRTS.
PAGEDRTS:
    TST.B   zStopPaging              ; Did the user once press 'q' while paging?
    BEQ.S   .rt                      ; No, skip ahead to return
    ADDQ.L  #4,A7                    ; Yes, drop caller's return address
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'...STOPPED...'>,endl
.rt RTS                              ; Back to caller or caller's caller...

    ; HEXB2STR -- Convert D1 byte to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D1: byte to turn into an ASCII hex string
    ; Notes:
    ;   Destroys A3. (But maybe in a useful way...)
    ;   Post-invocation, A3 will point to zNumToStr.
HEXB2STR:
    MOVEA.L #(zNumToStr+4),A3        ; Point A3 just past the end of the string
    CLR.B   -(A3)                    ; Null terminator at end of the string
    m_hb2s                           ; Invoke byte-printing macro
    RTS                              ; Back to caller

    ; HEXB2STR -- Convert D1 word to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D1: word to turn into an ASCII hex string
    ; Notes:
    ;   Destroys A3. (But maybe in a useful way...)
    ;   Post-invocation, A3 will point to zNumToStr.
HEXW2STR:
    MOVEA.L #(zNumToStr+6),A3        ; Point A3 just past the end of the string
    CLR.B   -(A3)                    ; Null terminator at end of the string
    m_hb2s                           ; Byte-printing macro for low-order byte
    ROR.W   #8,D0                    ; Rotate high-order byte to low-order
    m_hb2s                           ; Byte-printing macro for high-order byte
    ROR.W   #8,D0                    ; Rotate low-order byte back to low-order
    RTS                              ; Back to caller

    ; HEX3B2STR --  Convert D1[:3] to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D1: long whose lower three bytes will be turned into an ASCII hex string
    ; Notes:
    ;   Destroys A3. (But maybe in a useful way...)
    ;   Post-invocation, A3 will point to zNumToStr.
HEX3B2STR:
    MOVEA.L #(zNumToStr+8),A3        ; Point A3 just past the end of the string
    CLR.B   -(A3)                    ; Null terminator at end of the string
    ; Print low-order word first
    m_hb2s                           ; Byte-printing macro for low-order byte
    ROR.W   #8,D0                    ; Rotate high-order byte to low-order
    m_hb2s                           ; Byte-printing macro for high-order byte
    ROR.W   #8,D0                    ; Rotate low-order byte back to low-order
    ; Print low byte of the high-order word next
    SWAP    D0                       ; Swap low-order word for high-order word
    m_hb2s                           ; Byte-printing macro for low-order byte
    SWAP    D0                       ; Swap low-order word back to low-order
    RTS                              ; Back to caller

    ; HEXL2STR -- Convert D1 long to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D1: long to turn into an ASCII hex string
    ; Notes:
    ;   Destroys A3. (But maybe in a useful way...)
    ;   Post-invocation, A3 will point to zNumToStr.
HEXL2STR:
    MOVEA.L #(zNumToStr+$A),A3       ; Point A3 just past the end of the string
    CLR.B   -(A3)                    ; Null terminator at end of the string
    ; Print low-order word first
    m_hb2s                           ; Byte-printing macro for low-order byte
    ROR.W   #8,D0                    ; Rotate high-order byte to low-order
    m_hb2s                           ; Byte-printing macro for high-order byte
    ROR.W   #8,D0                    ; Rotate low-order byte back to low-order
    ; Print high-order word next
    SWAP    D0                       ; Swap low-order word for high-order word
    m_hb2s                           ; Byte-printing macro for low-order byte
    ROR.W   #8,D0                    ; Rotate high-order byte to low-order
    m_hb2s                           ; Byte-printing macro for high-order byte
    ROR.W   #8,D0                    ; Rotate low-order byte back to low-order
    SWAP    D0                       ; Swap low-order word back to low-order
    RTS                              ; Back to caller


    PAGE
* NeoWidEx UI numerical data ================================
    SECTION kSecData

    ; We assume menu keys for all menu items count up through 1-9,A-Z.
    ; All menus use this table.
dMenuIds:
    DC.B    kKeyCode1                ; Lisa keyboard key code for 1
    DC.B    kKeyCode2                ; Same, for 2
    DC.B    kKeyCode3                ; Same, for 3
    DC.B    kKeyCode4                ; Same, for 4
    DC.B    kKeyCode5                ; Same, for 5
    DC.B    kKeyCode6                ; Same, for 6
    DC.B    kKeyCode7                ; Same, for 7
    DC.B    kKeyCode8                ; Same, for 8
    DC.B    kKeyCode9                ; Same, for 9
    
    DS.W    0                        ; Force even alignment for following data


    PAGE
* NeoWidEx UI scratch data allocation =======================
    SECTION kSecScratch

zNumToStr:
    DCB.B   16,'n'                   ; 16 bytes for turning numbers to strings
zLineCount:
    DC.B    kPagerLines              ; PAGEDNEWLINE calls till scrolling pauses
zStopPaging:
    DC.B    0                        ; If the user hit 'q' to abort the pager

    DS.W    0                        ; Force even alignment for following data


    PAGE
* NeoWidEx UI strings =======================================
    SECTION kSecStrings

sNeoWidEx:
    DC.B    'NEOWIDEX',0             ; That's our name, don't wear it out!

sWelcome:                            ; Welcome text for NeoWidEx
    DC.B    $0D
    DC.B    '                --- NEOWIDEX ---',$0D,$0D
    DC.B    '     FORMATTER AND DIAGNOSTICS FOR WIDGET',$0D
    DC.B    'FORFEITED TO THE PUBLIC DOMAIN WITH NO WARRANTY',$0D
    DC.B    'VERSION 0.0 BY STEPLETON AT GMAIL.COM... LONDON',$0D
    DC.B    $0D
    DC.B    'THIS SOFTWARE MAY CAUSE UNRECOVERABLE DAMAGE TO',$0D
    DC.B    'SOFTWARE HARDWARE AND DATA ON THIS COMPUTER. IF',$0D
    DC.B    'THIS RISK IS UNACCEPTABLE TO YOU---QUIT AT ONCE',$0D
    DC.B    $0D
    DC.B    'OTHERWISE... WELCOME... PLEASE SELECT A COMMAND',$0D
    DC.B    $0D
    DC.B    '        / ALL NUMBERS ARE HEXADECIMAL /',$0D,0

sThanks:
    DC.B    $0D
    DC.B    '                 --- THANKS ---',$0D,$0D
    DC.B    'DR. PATRICK SCHAEFER .. REVERSE ENGINEERING ETC.',$0D
    DC.B    'RAY ARACHELIAN ............ THE LISAEM EMULATOR',$0D
    DC.B    'JAMES MACPHAIL ........................ BLU ETC.',$0D
    DC.B    'BITSAVERS.ORG ........... CRUCIAL DOCUMENTATION',$0D
    DC.B    'LISALIST ...................... FOR A COMMUNITY',$0D
    DC.B    $0D
    DC.B    'THEIR WORK MADE NEOWIDEX A LEISURE-TIME PROJECT',$0D
    DC.B    $0D
    DC.B    'YOU ............................. YOUR INTEREST',$0D,0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
