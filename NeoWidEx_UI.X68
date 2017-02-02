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

    ; UILOOP -- Drop-down-menu-driven UI loop
    ; Args:
    ;   zUiLoopMenu: Address of a menu string table (see MENU for details)
    ;   zUiLoopMenuHandlers: Address of a table of addresses of subroutine
    ;       handlers for each menu item. Ordinarily, a newline is printed before
    ;       a handler is called, but if the least significant bit of the
    ;       handler's address is 1, no newline is printed. (The bit will be
    ;       cleared prior to calling the handler, of course.)
    ; Notes:
    ;   Loops until zUiLoopBreak is nonzero, which should probably only be
    ;       caused by the GOBACK subroutine.
    ;   Not intended to be called directly often; instead, use the mMenuUi
    ;       macro if possible.
    ;   Uses a particular invocation convention to support nested submenus
    ;       without the use of a stack. (This convention is automated by
    ;       mMenuUi.) First, UILOOP should be called within a loop that
    ;       refreshes zUiLoopMenu and zUiLoopMenuHandlers prior to calling
    ;       UILOOP. When UILOOP returns, the caller should repeat the loop only
    ;       if the N flag is set; otherwise, it should negate zUiLoopBreak and
    ;       carry on with whatever it was doing. Prior to returning, if flags
    ;       have changed since the negation, the caller should restore the
    ;       flags by executing a TST.B zUiLoopBreak.
    ;   Why the convention? UILOOP exits whenever zUiLoopMenu is nonzero. This
    ;       can happen in two ways: either the user selected a menu option that
    ;       called GOBACK, or, if the convention is upheld, then a menu option
    ;       that itself called UILOOP ended via its own GOBACK call.
    ;   In the latter case, zUiLoopMenu is negative, the N flag is set, and so
    ;       we should stay in the current menu and restart UILOOP.
    ;   In the former case, zUiLoopMenu is positive, and so we should not
    ;       remain in the current menu.
    ;   Trashes (minimally) D0-D6/A1-A4, plus whatever the handlers trash.
UILOOP:
    MOVEA.L zUiLoopMenu,A3           ; Point A3 to buffer menu strings
    BSR     MENU                     ; Draw menu and get the user's choice
    MOVEA.L zUiLoopMenuHandlers,A3   ; Point A3 to buffer handler table
    BSR     MENUPICK                 ; Find menu handler for user's choice
    BEQ.S   UILOOP                   ; User's menu choice invalid; try again
    MOVE.L  (A3),A3                  ; Load handler address into A3
    EXG.L   A3,D0                    ; Swap it with D0 temporarily for this:
    BCLR.L  #0,D0                    ; Print a CR before we call? (Note CLR)
    BNE.S   .js                      ; No, skip straight to jump
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Yes, print a newline to space output
.js CLR.B   zUiLoopBreak             ; By default, UI loop should not terminate
    EXG.L   D0,A3                    ; Unswap D0 and A3 for the jump
    JSR     (A3)                     ; Call handler
    TST.B   zUiLoopBreak             ; Should UI loop terminate?
    BEQ.S   UILOOP                   ; No, around again for the next user choice
    RTS                              ; Yes, back to caller

    ; GOBACK -- Break out of a current submenu to a parent menu
    ; Args:
    ;   (none)
    ; Notes:
    ;   Will NOT work if the subroutine that called GOBACK places ANYTHING
    ;       on the stack prior to the BSR or JSR to GOBACK.
    ;   Main intended use is to implement a "back to main menu" option in
    ;       UILOOPs that present submenus to users.
GOBACK:
    ; A positive value (TODO...)
    MOVE.B  #$01,zUiLoopBreak        ; Mark that the current UI loop should stop
    RTS                              ; Return to caller's caller

    ; MENU -- Display and solicit (blocking) input from a drop-down menu
    ; Args:
    ;   A3: Address of the menu string table
    ; Notes:
    ;   Menu items will be given the hotkeys 1,2,...,9,A,B,...,Z.
    ;   The menu string table is expected to be a contiguous, null-terminated
    ;       sequence of null-terminated strings, followed by a contiguous,
    ;       null-terminated list of bytes indicating which menu items (counting
    ;       up from 1) should be followed by a halftone divider line.
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
    MOVE.L  #22,D0                   ; Blank an area 22 bytes wide
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

    ; Draw divider lines
    ADDQ.L  #1,A3                    ; Advance past menu null terminator
.dl TST.B   (A3)                     ;   Done with dividers?
    BEQ.S   .ui                      ;   Yes, skip ahead to get user input
    CLR.L   D1                       ;   We'll compute line screen address in D1
    MOVE.B  (A3)+,D1                 ;   Copy divider menu item to D1
    MULU.W  #(1+kCharHeight),D1      ;   Multiply by rows per char
    ADDQ.W  #1,D1                    ;   Add one more row for alignment
    MULU.W  #kRowBytes,D1            ;   Multiply by bytes per row
    ADD.L   #kMenuStart,D1           ;   Add offset of first byte of menu
    ADD.L   kScreen,D1               ;   Add absolute base of video memory
    MOVE.L  D1,A1                    ;   Completed address into A1
    MOVE.B  #$D5,(A1)+               ;   First divider byte keeps left edge dark
    MOVE.W  D0,D2                    ;   Copy menu width to D2
    SUBQ.B  #2,D2                    ;   Subtract 2 to make a loop iterator
.db MOVE.B  #$55,(A1)+               ;     Draw one byte's worth of divider
    DBRA    D2,.db                   ;     Loop until menu width complete
    BRA.S   .dl                      ;   On to next divider

    ; Get user input
.ui JSR     kCrsrDsply               ; Redisplay mouse cursor
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

    ; MENUPICK -- Select item from an array based on MENU choice
    ; Args:
    ;   A3: Top of a null-terminated longs array; usually subroutine addresses
    ;   D0: Keycode associated with the user's menu selection
    ; Notes:
    ;   Changes A3.
    ;   If the zero bit is cleared, A3 points to the array item corresponding to
    ;       the menu item selected by the user in MENU. If the zero bit is set,
    ;       no item in the list corresponds to the MENU result.
    ;   The A3 array must not be longer than the list of keys at dMenuIds.
MENUPICK:
    MOVE.L  A0,-(A7)                 ; Save A0 to stack
    LEA     dMenuIds,A0              ; Point A0 to table of menu item keys
.lp TST.L   (A3)+                    ;   Item list terminator? Also, increment
    BEQ.S   .rt                      ;   Yes, back to caller with Z=1
    CMP.B   (A0)+,D0                 ;   No, do keystrokes match?
    BNE.S   .lp                      ;   No, on to next item
    SUBQ.L  #4,A3                    ; Yes, rewind A3 to matching item
    ANDI.B  #$FB,CCR                 ; Clear zero bit to mark a match
.rt MOVEA.L (A7)+,A0                 ; Restore A0 without disrupting flags
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

    ; NEWLINE -- move to next line
    ; Args:
    ;   D4: character column of the next line's first character
    ;   D5: pixel row of the string's first line (will be updated)
    ;   D6: current character column (will be updated)
    ; Notes:
    ;   It seems the only reliable way to get a newline in the monitor is to
    ;       print an $0D. Manipulating in-memory cursor position directly (i.e.
    ;       simply changing the values in kCrtRow and kCrtCol) will move the
    ;       cursor as intended, but if the screen is already full, this action
    ;       will not scroll the screen up on its own. Only when new text is
    ;       printed do the boot ROM display routines discover that the row
    ;       argument is out-of-bounds and scroll the text to create a new,
    ;       empty line. This seems adequate at first blush, but the boot ROM
    ;       will only scroll the screen one line no matter how far
    ;       out-of-bounds the row argument is, so attempts to advance forward
    ;       two lines can only ever scroll the screen one line. So, we print
    ;       $0D instead.
NEWLINE:
    MOVE.L  A3,-(A7)                 ; Save A3 register
    MOVEA.L #.s0,A3                  ; Point A3 at "\r" string...
    JSR     kDispMsg                 ; ...and print it
    MOVEA.L (A7)+,A3                 ; Restore A3 register
    RTS                              ; Back to caller
.s0 DC.B    $0D,0

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
    BSR     NEWLINE                  ; Print newline
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
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'...STOPPED...'>
.rt RTS                              ; Back to caller or caller's caller...

    ; QUITPOLL -- Nonblocking poll to see if user has typed 'q'
    ; Args:
    ;   (none)
    ; Notes:
    ;   On return, the Z bit will be set iff the user has just typed 'q'.
QUITPOLL:
    ; Poll the COPS for a while, looking for a 'q'.
    MOVE.L  A0,-(A7)                 ; Save A0 on the stack
    MOVEM.L D0-D1,-(A7)              ; Save D0 and D1 on the stack
    MOVE.L  #kVia1Base,A0            ; Replace A0 with VIA 1 base address
    MOVE.W  #$100,D1                 ; Poll the COPS this many times
.ql MOVE.B  kVia1Ifr(A0),D0          ; Copy VIA 1 interrupt flags to D0
    BTST.L  #1,D0                    ; Is there input waiting?
    BNE.S   .p1                      ; Yes! Jump ahead to see what it was
.qb DBRA    D1,.ql                   ; Round to top for another loop
    ; If we fall through to here, no 'q' has been received.
    ANDI.B  #$FB,CCR                 ; Clear zero bit to mark "no 'q'"
.qt MOVEM.L (A7)+,D0-D1              ; Retore D0-D1 from stack; flags unchanged
    MOVEA.L (A7)+,A0                 ; Restore A0 from stack, flags unchanged
    RTS                              ; Back to caller

    ; Some input was waiting; what is it?
.p1 MOVE.B  kVia1OutA(A0),D0         ; Copy VIA 1 port A output register to D0
    BNE.S   .p2                      ; Was it mouse data? If not, skip ahead
    BSR.S   .rc                      ; It was mouse data. Skip delta-X
    BSR.S   .rc                      ; Skip delta-Y
    BRA.S   .qb                      ; Back to QUITPOLL main loop

.p2 CMPI.B  #kKeyCodeQ,D0            ; Was this the 'Q' key?
    BNE.S   .p3                      ; No, skip to see if this was a reset code
    BRA.S   .qt                      ; Yes! Return to caller with Z set

.p3 CMPI.B  #kResetCode,D0           ; Was this a reset code?
    BNE.S   .qb                      ; No, back to QUITPOLL main loop
    BSR.S   .rc                      ; Yes, what kind of reset code was it?

    CMPI.B  #$E0,D0                  ; Was it less than $E0?
    BLO.S   .qb                      ; Yes, back to QUITPOLL main loop
    CMPI.B  #$EF,D0                  ; Was it greater than $EF?
    BHI.S   .qb                      ; Yes, back to QUITPOLL main loop

    BSR.S   .rc                      ; It's clock data. Skip five bytes of it...
    BSR.S   .rc
    BSR.S   .rc
    BSR.S   .rc
    BSR.S   .rc
    BRA.S   .qb                      ; ...and back to QUITPOLL main loop

    ; Tiny helper that QUITPOLL uses for blocking reads from the COPS.
.rc MOVE.B  kVia1Ifr(A0),D0          ; Copy VIA 1 interrupt flags to D0
    BTST.L  #1,D0                    ; Is anything waiting for us?
    BEQ.S   .rc                      ; No, keep looping until there is
    MOVE.B  kVia1OutA(A0),D0         ; Copy VIA 1 port A output register to D0
    RTS                              ; Back to caller

    ; HEXB2STR -- Convert D0 byte to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D0: byte to turn into an ASCII hex string
    ; Notes:
    ;   Destroys A3. (But maybe in a useful way...)
    ;   Post-invocation, A3 will point to zNumToStr.
HEXB2STR:
    MOVEA.L #(zNumToStr+4),A3        ; Point A3 just past the end of the string
    CLR.B   -(A3)                    ; Null terminator at end of the string
    m_hb2s                           ; Invoke byte-printing macro
    RTS                              ; Back to caller

    ; HEXW2STR -- Convert D0 word to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D0: word to turn into an ASCII hex string
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

    ; HEX3B2STR --  Convert D0[:3] to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D0: long whose lower three bytes will be turned into an ASCII hex string
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

    ; HEXL2STR -- Convert D0 long to a null-terminated hex string at zNumToStr
    ; Args:
    ;   D0: long to turn into an ASCII hex string
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
    DC.B    kKeyCodeA                ; Same, for A
    DC.B    kKeyCodeB                ; Same, for B
    DC.B    kKeyCodeC                ; Same, for C
    DC.B    kKeyCodeD                ; Same, for D
    DC.B    kKeyCodeE                ; Same, for E
    DC.B    kKeyCodeF                ; Same, for F
    DC.B    kKeyCodeG                ; Same, for G
    DC.B    kKeyCodeH                ; Same, for H
    DC.B    kKeyCodeI                ; Same, for I
    DC.B    kKeyCodeJ                ; Same, for J
    DC.B    kKeyCodeK                ; Same, for K
    DC.B    kKeyCodeL                ; Same, for L
    DC.B    kKeyCodeM                ; Same, for M
    DC.B    kKeyCodeN                ; Same, for N
    
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

zUiLoopBreak:
    DC.B    0                        ; Current UI loop should terminate
    DS.W    0                        ; Force even alignment for following data
zUiLoopMenu:
    DC.B    '[UiM'                   ; Pointer to UI menu strings table
zUiLoopMenuHandlers:
    DC.B    'enu]'                   ; Pointer to UI menu handlers table


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
    DC.B    '        / ALL NUMBERS ARE HEXADECIMAL /',0

sThanks:
    DC.B    $0D
    DC.B    '                 --- THANKS ---',$0D,$0D
    DC.B    'DR. PATRICK SCHAEFER .. REVERSE ENGINEERING ETC.',$0D
    DC.B    'RAY ARACHELIAN ............ THE LISAEM EMULATOR',$0D
    DC.B    'STEVE CHAMBERLIN ................... FLOPPY EMU',$0D
    DC.B    'JAMES MACPHAIL ........................ BLU ETC.',$0D
    DC.B    'BITSAVERS.ORG ........... CRUCIAL DOCUMENTATION',$0D
    DC.B    'LISALIST ...................... FOR A COMMUNITY',$0D
    DC.B    $0D
    DC.B    'THEIR WORK MADE NEOWIDEX A LEISURE-TIME PROJECT',$0D
    DC.B    $0D
    DC.B    'YOU ............................. YOUR INTEREST',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
