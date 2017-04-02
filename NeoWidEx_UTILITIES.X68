*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Date       : XX January 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: UI submenu for some utility subroutines.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_UI must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*-----------------------------------------------------------


* NeoWidEx assorted utilities code =========================

    ; UTILITIES -- UI for selecting from various utility subroutines
    ; Args:
    ;   (none)
    ; Notes:
    ;   A "sub-UI" with its own menu and everything.
    ;   Probably destroys most registers; depends on what user chooses to do.
    ;   Will not trash beyond D0-D4/A0-A4.
UTILITIES:
    mMenuUi #sUtilitiesMenu,#dUtilitiesMenuHandlers
    RTS                              ; ...and go back to main menu

    INCLUDE NeoWidEx_UTIL_Grep.X68

    INCLUDE NeoWidEx_UTIL_Exercise_Disk.X68

    INCLUDE NeoWidEx_UTIL_Track_Offsets.X68

    INCLUDE NeoWidEx_UTIL_Addressing.X68

    PAGE
* NeoWidEx assorted utilities numerical data ===============
    SECTION kSecData

    DS.W    0                        ; Force even alignment for what follows
dUtilitiesMenuHandlers:              ; Addresses of handlers for each of the...
    DC.L    (1+GOBACK)               ; ...menu items in sUtilitiesMenu
    DC.L    UTIL_Grep_Sectors        ; 1+ means don't print a newline before...
    DC.L    UTIL_Grep_Blocks         ; ...calling this handler; the LSBit...
    DC.L    UTIL_Exercise_Disk       ; ...will be cleared before the call
    DC.L    UTIL_Track_Offsets
    DC.L    _NOTYET
    DC.L    (1+UTIL_Addressing)
    DC.L    $00000000                ; Null terminator


    PAGE
* NeoWidEx assorted utilities strings ======================
    SECTION kSecStrings

sUtilitiesMenu:
    DC.B    'UTILITIES',0            ; Menu title
    DC.B    'GO BACK...    1',0
    DC.B    'GREP SECTORS  2',0
    DC.B    'GREP BLOCKS   3',0
    DC.B    'EXERCISE DISK 4',0
    DC.B    'TRACK OFFSETS 5',0
    DC.B    'FORMAT        6',0
    DC.B    'ADDRESSING... 7',0
    DC.B    0                        ; End of menu
    DC.B    $01                      ; Divider after item 1
    DC.B    $06                      ; Divider after item 6
    DC.B    0                        ; No more dividers


** (Back to the code section) **
    SECTION kSecCode



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
