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
    ORG     $7000                    ; Various numerical data items live here
    SECTION kSecScratch
    ORG     $7100                    ; Structured scratch space
    SECTION kSecStrings
    ORG     $7200                    ; Program strings bring up the rear
    SECTION kSecCode


    PAGE
* NeoWidEx macros ==========================================

    INCLUDE NeoWidEx_MACROS.X68


    PAGE
* NeoWidEx code ============================================
    OPT     NOMEX                    ; Expand no macros in listings
  ; OPT     MEX                      ; Expand all macros in listings

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
    BEQ     .m1                      ; ...to menu-option handling routines
    CMPI.B  #kKeyCode2,D0
    BEQ     .m2
    CMPI.B  #kKeyCode3,D0
    BEQ     .m3
    CMPI.B  #kKeyCode4,D0
    BEQ     .m4
    CMPI.B  #kKeyCode5,D0
    BEQ     .m5
    CMPI.B  #kKeyCode6,D0
    BEQ     .m6
    CMPI.B  #kKeyCode7,D0
    BEQ     .m7
    CMPI.B  #kKeyCode8,D0
    BEQ     .m8
    CMPI.B  #kKeyCode9,D0
    BEQ     .m9
    CMPI.B  #kKeyCodeA,D0
    BEQ     .ma
    CMPI.B  #kKeyCodeB,D0
    BEQ     .mb
    CMPI.B  #kKeyCodeC,D0
    BEQ     .mc
    CMPI.B  #kKeyCodeD,D0
    BEQ     .md
    CMPI.B  #kKeyCodeE,D0
    BEQ     .me

    BRA     UILOOP                   ; Unrecognised choice; wait for user again

    ; Main loop option 1: Show the status bytes from the last command
.m1 BSR     _UINEWLINE
    BSR     STATUSPRINT
    BRA     UILOOP

    ; Main loop option 2: Print raw tag and sector data
.m2 BSR     _UINEWLINE
    BSR     RAWPRINT
    BRA     UILOOP

    ; Main loop option 3: Get Widget info
.m3 BSR     _UINEWLINE
    BSR     WINFOPRINT
    BRA     UILOOP

    ; Main loop option 4: Print full Widget controller status
.m4 BSR     _UINEWLINE
    BSR     CMD_Read_Controller_Status
    BRA     UILOOP

    ; Main loop option 5: Print full Widget servo status
.m5 BSR     _UINEWLINE
    BSR     CMD_Read_Servo_Status
    BRA     UILOOP

    ; Main loop option 6: Print spare table
.m6 BSR     _UINEWLINE
    BSR     SPAREPRINT
    BRA     UILOOP

    ; Main loop option 7: Toggle recovery state
.m7 BSR     _UINEWLINE
    BSR     CMD_Set_Recovery
    BRA     UILOOP

    ; Main loop option 8: Perform a surface scan
.m8 BSR     _UINEWLINE
    BSR     CMD_Scan
    BRA     UILOOP

    ; Main loop option 9: Soft-reset the Widget
.m9 BSR     _UINEWLINE
    BSR     CMD_Soft_Reset
    BRA     UILOOP

    ; Main loop option 10: Reset the servo
.ma BSR     _UINEWLINE
    BSR     CMD_Reset_Servo
    BRA     UILOOP

    ; Main loop option 11: Park heads
.mb BSR     _UINEWLINE
    BSR     CMD_Send_Park
    BRA     UILOOP

    ; Main loop option 12: Show thanks
.mc BSR     _UINEWLINE
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sThanks
    BRA     UILOOP

    ; Main loop option 12: Quit and return to the ROM
.md mFail   #0,<'THANKS FOR USING NEOWIDEX...'>

.me BRA     UILOOP

    ; ## 4. Subroutines etc. ##

    ; _UINEWLINE -- Just prints a newline
    ; Args:
    ;   (none)
    ; Notes:
    ;   Because BSR _UINEWLINE is smaller than a macro.
_UINEWLINE:
    mPrtCr  kCrtRow,kCrtCol,#kFirstCol   ; Print newline to space output
    RTS                              ; Back to caller

    ; RAWPRINT -- Display hex dump of data from last read
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes A0.
RAWPRINT:
    mResetP                          ; Reset paging
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- DATA FROM LAST READ ---'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'RAW TAG DATA'>
    LEA     zSectorTag,A0
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A0,#5,endl
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'RAW SECTOR DATA'>
    LEA     zSectorData,A0
    mDump.L kCrtRow,kCrtCol,#kFirstCol,A0,#128,endl
    RTS                              ; Back to caller

    INCLUDE NeoWidEx_WIDGETINFO.X68

    INCLUDE NeoWidEx_UI.X68

    INCLUDE NeoWidEx_UI_FORMS.X68

    INCLUDE NeoWidEx_IO.X68

    INCLUDE NeoWidEx_CMD_Read_Controller_Status.X68

    INCLUDE NeoWidEx_CMD_Read_Servo_Status.X68

    INCLUDE NeoWidEx_CMD_Set_Recovery.X68

    INCLUDE NeoWidEx_CMD_Soft_Reset.X68

    INCLUDE NeoWidEx_CMD_Send_Park.X68

    INCLUDE NeoWidEx_CMD_Reset_Servo.X68

    INCLUDE NeoWidEx_CMD_Scan.X68

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
    DC.B    'DRIVE INFO    3',0
    DC.B    'FULL STATUS   4',0
    DC.B    'SERVO STATUS  5',0
    DC.B    'SPARE TABLE   6',0
    DC.B    'FLIP RECOVERY 7',0
    DC.B    'SCAN          8',0
    DC.B    'SOFT RESET    9',0
    DC.B    'RESET SERVO   A',0
    DC.B    'PARK HEADS    B',0
    DC.B    'THANKS        C',0
    DC.B    'QUIT          D',0
    DC.B    'FORMTEST      E',0
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
