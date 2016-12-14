*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*-----------------------------------------------------------

; NOTES TO SELF:
;   Stack: from $480 to $3E8 --- that's 152 bytes, or 38 longs!


    PAGE
* NeoWidEx Equates =========================================

    INCLUDE NeoWidEx_DEFS.X68


    PAGE
* NeoWidEx section definitions =============================

    SECTION kSecCode
    ORG     $800                     ; Program code starts here
    SECTION kSecData
    ORG     $5000                    ; Various numerical data items live here
    SECTION kSecScratch
    ORG     $5100                    ; Structured scratch space
    SECTION kSecStrings
    ORG     $5200                    ; Program strings bring up the rear


    PAGE
* NeoWidEx macros ==========================================

    INCLUDE NeoWidEx_MACROS.X68


    PAGE
* NeoWidEx code ============================================
    OPT     NOMEX                    ; Expand no macros in listings
  ; OPT     MEX                      ; Expand all macros in listings
    SECTION kSecCode

NEOWIDEX:
    ; ## 0. Eject the floppy disk ##
    LEA     kDiskMem,A0              ; Disk shared memory into A0
    JSR     kEjectDisk               ; Eject the disk

    ; ## 1. Check the boot ROM version ##
ROMCHECK:
    MOVE.W  dTargetRom,D0            ; Copy target ROM version to D0
    CMP.W   kRomVWord,D0             ; Compare actual ROM version with target
    BEQ.S   INIT                     ; It's a match, so initialise NeoWidEx
    mFail   #0,<'SORRY... THIS NEOWIDEX WAS BUILT FOR BOOT ROM '>,kBootRom

    ; ## 2. Set up the user interface ##
INIT:
    JSR     MAKEWORLD                ; Draw the UI; say hello

    ; ## 3. Main user-interface loop ##
UILOOP:
    LEA     sMainMenu,A3             ; Point A3 to main menu strings
    JSR     MENU                     ; Draw menu and get the user's choice

    CMPI.B  #kKeyCode1,D0            ; Recognised key codes trigger jumps...
    BEQ.S   .m1                      ; ...to menu-option handling routines
    CMPI.B  #kKeyCode2,D0
    BEQ.S   .m2
    CMPI.B  #kKeyCode3,D0
    BEQ.S   .m3
    CMPI.B  #kKeyCode4,D0
    BEQ.S   .m4
    CMPI.B  #kKeyCode5,D0
    BEQ.S   .m5
    CMPI.B  #kKeyCode6,D0
    BEQ.S   .m6
    CMPI.B  #kKeyCode7,D0
    BEQ.S   .m7
    CMPI.B  #kKeyCode8,D0
    BEQ.S   .m8

    BRA.S   UILOOP                   ; Get next user command

    ; Main loop option 1: Show the status bytes from the last command
.m1 BSR     STATUSPRINT
    BRA.S   UILOOP

    ; Main loop option 2: Print raw tag and sector data
.m2 BSR     RAWPRINT
    BRA.S   UILOOP

    ; Main loop option 3: Print full Widget controller status
.m3 BSR     CMD_Read_Controller_Status
    BRA.S   UILOOP

    ; Main loop option 4: Get Widget info.
.m4 BSR     WINFOPRINT
    BRA.S   UILOOP

    ; Main loop option 5: Print spare table.
.m5 BSR     SPAREPRINT
    BRA.S   UILOOP

    ; Main loop option 6: Reset the servo.
.m6 BSR     CMD_Reset_Servo
    BRA.S   UILOOP

    ; Main loop option 7: Show thanks.
.m7 mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sThanks
    BRA     UILOOP

    ; Main loop option 8: Quit and return to the ROM.
.m8 mFail   #0,<'THANKS FOR USING NEOWIDEX...'>

    ; ## 4. Subroutines etc. ##

    INCLUDE NeoWidEx_WIDGETINFO.X68

    INCLUDE NeoWidEx_UI.X68

    INCLUDE NeoWidEx_IO.X68

    INCLUDE NeoWidEx_CMD_Reset_Servo.X68

    INCLUDE NeoWidEx_CMD_Read_Controller_Status.X68

RAWPRINT:
    mResetP                          ; Reset paging
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- DATA FROM LAST READ ---'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,endl,<'RAW TAG DATA'>,endl
    LEA     zSectorTag,A0
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A0,#5,endl
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'RAW SECTOR DATA'>,endl
    LEA     zSectorData,A0
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A0,#128,endl
    RTS

    PAGE
* NeoWidEx numerical data ==================================
    SECTION kSecData

dTargetRom:                          ; ROM version expected by this build
    DC.B    $02                      ; First byte of expected ROM version
    DC.B    kBootRom                 ; Second byte of expected ROM version


    PAGE
* NeoWidEx scratch data allocation =========================
    SECTION kSecScratch

zReturnCode:
    DC.B    $00                      ; Return code for various subroutines


    PAGE
* NeoWidEx strings =========================================
    SECTION kSecStrings

sMainMenu:
    DC.B    'COMMANDS',0             ; Menu title
    DC.B    'LAST STATUS   1',0
    DC.B    'LAST RAW DATA 2',0
    DC.B    'FULL STATUS   3',0
   ;DC.B    'SERVO STATUS  4',0
    DC.B    'DRIVE INFO    4',0
    DC.B    'SPARE TABLE   5',0
    DC.B    'RESET SERVO   6',0
    DC.B    'THANKS        7',0
    DC.B    'QUIT          8',0
    DC.B    0                        ; End of menu.


    PAGE
* Loaded disk sector storage area ==========================

    DS.W    0                        ; Force even word alignment
zSectorTag:
    DS.B    20                       ; Space for sector tag
zSectorData:
    ; No further program data should be placed from this point on.


* End of NeoWidEx source ===================================

    ; Designates NEOWIDEX as the beginning of the program.
    END    NEOWIDEX



*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
