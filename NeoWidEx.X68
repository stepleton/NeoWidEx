*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*-----------------------------------------------------------


    PAGE
* NeoWidEx Equates =========================================

    INCLUDE NeoWidEx_DEFS.X68


    PAGE
* NeoWidEx section definitions =============================

    ; For faster loading from floppy, these sections are fairly tightly packed.
    ; If you add more code or strings, you may need to allocate more space.

    SECTION kSecCode
    ORG     $800                     ; Program code starts here
    SECTION kSecData
    ORG     $C500                    ; Various numerical data items live here
    SECTION kSecScratch
    ORG     $C800                    ; Structured scratch space
    SECTION kSecStrings
    ORG     $CD00                    ; Program strings bring up the rear
    SECTION kSecCode


    PAGE
* NeoWidEx macros ==========================================

    INCLUDE NeoWidEx_MACROS.X68


    PAGE
* NeoWidEx code ============================================

NEOWIDEX:
    ; ## 0. Eject the floppy disk ##
    LEA     kDiskMem,A0              ; Disk shared memory into A0
    JSR     kEjectDisk               ; Eject the disk

    ; ## 1. Check the boot ROM version ##
    MOVE.W  dTargetRom,D0            ; Copy target ROM version to D0
    CMP.W   kRomVWord,D0             ; Compare actual ROM version with target
    BEQ.S   .go                      ; It's a match, so initialise NeoWidEx
    mFail   #0,<'SORRY... THIS NEOWIDEX WAS BUILT FOR BOOT ROM '>,kBootRom

    ; ## 2. Set up the user interface ##
.go BSR     MAKEWORLD                ; Draw the UI; say hello

    ; ## 3. Main user-interface loop ##
    mMenuUi #sMainMenu,#dMainMenuHandlers   ; Main menu UI loop
    mFail   #0,<'THANKS FOR USING NEOWIDEX...'>   ; User has quit!

    ; ## 4. Subroutines etc. ##

    ; _THANKS -- Print acknowledgement message.
    ; Args:
    ;   (none)
    ; Notes:
    ;   (none)
_THANKS:
    ADDQ.B  #1,zIterations
    CMPI.B  #4,zIterations
    BGE.S   .fa
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#sThanks
    RTS
.fa CLR.B   zIterations
    JMP     FA1D

    ; _NOTYET -- Placeholder for as-yet unimplemented code
    ; Args:
    ;   (none)
    ; Notes:
    ;   TODO: Delete this when no longer in use.
_NOTYET:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SORRY... NOT IMPLEMENTED YET'>
    RTS

    INCLUDE NeoWidEx_UI.X68

    INCLUDE NeoWidEx_UI_FORMS.X68

    INCLUDE NeoWidEx_IO.X68

    INCLUDE NeoWidEx_BUFFER.X68

    INCLUDE NeoWidEx_WIDGETINFO.X68

    INCLUDE NeoWidEx_CMD_ProFile_Read.X68

    INCLUDE NeoWidEx_CMD_ProFile_Write.X68

    INCLUDE NeoWidEx_CMD_Diag_Read.X68

    INCLUDE NeoWidEx_CMD_Diag_ReadHeader.X68

    INCLUDE NeoWidEx_CMD_Diag_Write.X68

    INCLUDE NeoWidEx_CMD_Sys_Read.X68

    INCLUDE NeoWidEx_CMD_Initialize_SpareTable.X68

    INCLUDE NeoWidEx_CMD_Format_Track.X68

    INCLUDE NeoWidEx_CMD_Read_Controller_Status.X68

    INCLUDE NeoWidEx_CMD_Read_Servo_Status.X68

    INCLUDE NeoWidEx_CMD_Read_Abort_Status.X68

    INCLUDE NeoWidEx_CMD_Set_Recovery.X68

    INCLUDE NeoWidEx_CMD_Soft_Reset.X68

    INCLUDE NeoWidEx_CMD_Send_Park.X68

    INCLUDE NeoWidEx_CMD_Send_Seek.X68

    INCLUDE NeoWidEx_CMD_Set_AutoOffset.X68

    INCLUDE NeoWidEx_CMD_Send_Restore.X68

    INCLUDE NeoWidEx_CMD_Reset_Servo.X68

    INCLUDE NeoWidEx_CMD_Scan.X68

    INCLUDE NeoWidEx_UTILITIES.X68

    INCLUDE NeoWidEx_FA1D.X68

    PAGE
* NeoWidEx numerical data ==================================
    SECTION kSecData

dTargetRom:                          ; ROM version expected by this build
    DC.B    $02                      ; First byte of expected ROM version
    DC.B    kBootRom                 ; Second byte of expected ROM version

    DS.W    0                        ; Force even alignment for what follows
dMainMenuHandlers:                   ; Addresses of handlers for each of the...
    DC.L    STATUSPRINT              ; ...menu items in sMainMenu
    DC.L    (1+BUFFER)               ; 1+ means don't print a newline before...
    DC.L    WINFOPRINT               ; ...calling this handler; the LSBit...
    DC.L    SPAREPRINT               ; ...will be cleared before the call
    DC.L    CMD_Read_Ctrlr_Status
    DC.L    CMD_Read_Servo_Status
    DC.L    CMD_Read_Abort_Status
    DC.L    CMD_Set_Recovery
    DC.L    CMD_ProFile_Read
    DC.L    CMD_ProFile_Write
    DC.L    _NOTYET                  ; CMD_Sys_Read, once it's perfected
    DC.L    _NOTYET                  ; CMD_Sys_Write, once it's implemented
    DC.L    CMD_Send_Restore
    DC.L    CMD_Send_Seek
    DC.L    CMD_Set_AutoOffset
    DC.L    CMD_Diag_Read
    DC.L    CMD_Diag_Write
    DC.L    CMD_Diag_ReadHeader
    DC.L    CMD_Scan
    DC.L    CMD_Soft_Reset
    DC.L    CMD_Reset_Servo
    DC.L    CMD_Send_Park
    DC.L    CMD_Initialize_SpareTable
    DC.L    CMD_Format_Track
    DC.L    (1+UTILITIES)
    DC.L    (1+GOBACK)
    DC.L    _THANKS
    DC.L    $00000000                ; Null terminator


    PAGE
* NeoWidEx scratch data allocation =========================
    SECTION kSecScratch

zIterations:
    DC.B    $00


    PAGE
* NeoWidEx strings =========================================
    SECTION kSecStrings

sMainMenu:
    DC.B    'MENU',0                 ; Menu title
    DC.B    'LAST STATUS   1',0
    DC.B    'BUFFER...     2',0
    DC.B    'DRIVE INFO    3',0
    DC.B    'SPARE TABLE   4',0
    DC.B    'FULL STATUS   5',0
    DC.B    'SERVO STATUS  6',0
    DC.B    'ABORT STATUS  7',0
    DC.B    'SET RECOVERY  8',0
    DC.B    'GENERIC READ  9',0
    DC.B    'GENERIC WRITE A',0
    DC.B    'WIDGET READ   B',0
    DC.B    'WIDGET WRITE  C',0
    DC.B    'SEND RESTORE  D',0
    DC.B    'SEEK          E',0
    DC.B    'AUTOOFFSET    F',0
    DC.B    'READ AT SEEK  G',0
    DC.B    'WRITE AT SEEK H',0
    DC.B    'READ HEADER   I',0
    DC.B    'SCAN          J',0
    DC.B    'SOFT RESET    K',0
    DC.B    'RESET SERVO   L',0
    DC.B    'PARK HEADS    M',0
    DC.B    'INIT SPR TBL  N',0
    DC.B    'FORMAT TRACK  O',0
    DC.B    'UTILITIES...  P',0
    DC.B    'QUIT          Q',0
    DC.B    'THANKS        R',0 
    DC.B    0                        ; End of menu
    DC.B    $07                      ; Divider after item 6
    DC.B    $08                      ; Divider after item 7
    DC.B    $0C                      ; Divider after item B
    DC.B    $12                      ; Divider after item H
    DC.B    $16                      ; Divider after item L
    DC.B    $18                      ; Divider after item N
    DC.B    $19                      ; Divider after item O
    DC.B    0                        ; No more dividers


    PAGE
* Loaded disk sector storage area ==========================

    DS.W    0                        ; Force even word alignment at tag start
    DS.B    1                        ; This byte is unused
zSectorHeader:
    DS.B    13                       ; Space for Diag_ReadHeader header
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
