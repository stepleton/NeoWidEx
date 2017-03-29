*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: NeoWidEx config and equates.
*-----------------------------------------------------------

    ; ### Configuration flags ###

    ; Set the following EQU nonzero to enable additional test and debugging
    ; code for use with the EASy68K 68000 simulator. Code compiled with this
    ; flag enabled is not usable on a Lisa.
kEASy68K    EQU  0

    ; Set the target boot ROM version for this build of NeoWidEx. Valid values
    ; are single-char strings from 'A' to 'H' (although there may be other
    ; versions as well, I suppose).
kBootRom    EQU  'H'

    ; ### Constants ###

kSctrSize   EQU  $200                ; Disk sectors are 512 bytes
kSctrTime   EQU  $1200000            ; Widget sector read timeout: ~3 minutes
kSctrTries  EQU  $10                 ; Widget sector read retry count
kSctrThresh EQU  $3                  ; Widget sparing threshold count

kHeaderSize EQU  $D                  ; Widget sector header size: 13 bytes

kKeyCodeClr EQU  $A0                 ; Key code for the keypad clear key
kKeyCodeLft EQU  $A2                 ; Key code for the keypad left key
kKeyCodeRgt EQU  $A3                 ; Key code for the keypad right key
kKeyCodeBsp EQU  $C5                 ; Key code for the backspace key
kKeyCodeEnt EQU  $C6                 ; Key code for the enter key
kKeyCodeRet EQU  $C8                 ; Key code for the return key
kKeyCodeSpc EQU  $DC                 ; Key code for the space bar
kKeyCodeTab EQU  $F8                 ; Key code for the tab key
kKeyCode1   EQU  $F4                 ; Key code for the main keyboard 1 key
kKeyCode2   EQU  $F1                 ; Key code for the main keyboard 2 key
kKeyCode3   EQU  $F2                 ; Key code for the main keyboard 3 key
kKeyCode4   EQU  $F3                 ; Key code for the main keyboard 4 key
kKeyCode5   EQU  $E4                 ; Key code for the main keyboard 5 key
kKeyCode6   EQU  $E1                 ; Key code for the main keyboard 6 key
kKeyCode7   EQU  $E2                 ; Key code for the main keyboard 7 key
kKeyCode8   EQU  $E3                 ; Key code for the main keyboard 8 key
kKeyCode9   EQU  $D0                 ; Key code for the main keyboard 9 key
kKeyCode0   EQU  $D1                 ; Key code for the main keyboard 0 key
kKeyCodePd1 EQU  $CD                 ; Key code for the keypad 1 key
kKeyCodePd2 EQU  $AD                 ; Key code for the keypad 2 key
kKeyCodePd3 EQU  $AE                 ; Key code for the keypad 3 key
kKeyCodePd4 EQU  $A8                 ; Key code for the keypad 4 key
kKeyCodePd5 EQU  $A9                 ; Key code for the keypad 5 key
kKeyCodePd6 EQU  $AA                 ; Key code for the keypad 6 key
kKeyCodePd7 EQU  $A4                 ; Key code for the keypad 7 key
kKeyCodePd8 EQU  $A5                 ; Key code for the keypad 8 key
kKeyCodePd9 EQU  $A6                 ; Key code for the keypad 9 key
kKeyCodePd0 EQU  $C9                 ; Key code for the keypad 0 key
kKeyCodeA   EQU  $F0                 ; Key code for the A key
kKeyCodeB   EQU  $EE                 ; Key code for the B key
kKeyCodeC   EQU  $ED                 ; Key code for the C key
kKeyCodeD   EQU  $FB                 ; Key code for the D key
kKeyCodeE   EQU  $E0                 ; Key code for the E key
kKeyCodeF   EQU  $E9                 ; Key code for the F key
kKeyCodeG   EQU  $EA                 ; Key code for the G key
kKeyCodeH   EQU  $EB                 ; Key code for the H key
kKeyCodeI   EQU  $D3                 ; Key code for the I key
kKeyCodeJ   EQU  $D4                 ; Key code for the J key
kKeyCodeK   EQU  $D5                 ; Key code for the K key
kKeyCodeL   EQU  $D9                 ; Key code for the L key
kKeyCodeM   EQU  $D8                 ; Key code for the M key
kKeyCodeN   EQU  $EF                 ; Key code for the N key
kKeyCodeO   EQU  $DF                 ; Key code for the O key
kKeyCodeP   EQU  $C4                 ; Key code for the P key
kKeyCodeQ   EQU  $F5                 ; Key code for the Q key
kKeyCodeR   EQU  $E5                 ; Key code for the R key
kKeyCodeS   EQU  $F6                 ; Key code for the S key
kKeyCodeT   EQU  $E6                 ; Key code for the T key
kKeyCodeU   EQU  $D2                 ; Key code for the U key
kKeyCodeV   EQU  $EC                 ; Key code for the V key
kKeyCodeW   EQU  $F7                 ; Key code for the W key
kKeyCodeX   EQU  $FA                 ; Key code for the X key
kKeyCodeY   EQU  $E7                 ; Key code for the Y key
kKeyCodeZ   EQU  $F9                 ; Key code for the Z key
kKeyCodeSla EQU  $CC                 ; Key code for the / key

kResetCode  EQU  $80                 ; COPS reset code

kWIONoDisk  EQU  $01                 ; WIDGETIO error: no disk present
kWIOBusy    EQU  $02                 ; WIDGETIO error: disk won't deassert BSY
kWIOHello   EQU  $03                 ; WIDGETIO error: initial handshake failed
kWIOCmdAck  EQU  $05                 ; WIDGETIO error: disk didn't ack command
kWIODataAck EQU  $06                 ; WIDGETIO error: disk didn't ack data

kVia1Ifr    EQU  $1A                 ; VIA 1 interrupt flags, rel. to kVia1Base
kVia1OutA   EQU  $02                 ; VIA 1 output port A, rel. to kVia1Base

kVia2InA    EQU  $08                 ; VIA 2 input port A, relative to kVia2Base
kVia2InB    EQU  $00                 ; VIA 2 input port B, relative to kVia2Base
kVia2OutA   EQU  $08                 ; VIA 2 output port A, rel. to kVia2Base
kVia2OutB   EQU  $00                 ; VIA 2 output port B, rel. to kVia2Base
kVia2DirA   EQU  $18                 ; VIA 2 port A dir., relative to kVia2Base

    ; Screen geometry (note: ROM chars are 8 bits wide)
kRowBytes   EQU  90                  ; Screen width in chars/bytes

kCharWidth  EQU  1                   ; Display font char width in chars/bytes
kCharHeight EQU  10                  ; Display font inter-line height in lines

kDeskLine   EQU  1530                ; Upper left desktop corner byte (-offset)
kDeskLimit  EQU  32760               ; Lower left desktop corner byte (-offset)

kMenuLine   EQU  1440
kMenuStart  EQU  kMenuLine+2
kMenu1Msg   EQU  kMenuStart+182
kMenuWidth  EQU  18                  ; Pull-down menu width in chars/bytes

kDboxHeight EQU  20                  ; Height of dialog box in chars/bytes
kDboxLeft   EQU  kMenuWidth+2
kDboxTop    EQU  4*kRowBytes
kDboxStart  EQU  kMenuStart+kDboxLeft+kDboxTop
kDboxRow    EQU  (kDboxStart/90)+4   ; Dialog box prompt text row (pixels)
kDboxColumn EQU  kMenuWidth+6        ; Dialog box prompt text first col. (chars)

kSvcHeight  EQU  320                 ; Service mode window height in pixels
kSvcTop     EQU  (kDboxHeight+2)*kRowBytes
kSvcStart   EQU  kDboxStart+kSvcTop
kSvcWidth   EQU  84-kMenuWidth       ; Service mode window width in chars/bytes

kFirstRow   EQU  (kSvcStart/90)+20   ; First service mode text row (pixels)
kFirstCol   EQU  kMenuWidth+6        ; First service mode text column (chars)
kLastRow    EQU  (kSvcHeight-50)+kFirstRow   ; Last svc. mode text row (pixels)

kPagerLines EQU  ((kLastRow-kFirstRow)/10)-1   ; Lines to show before --MORE--

                                     ; Screen offsets for "splash" icon displays
kIcn1Offset EQU  (((kFirstRow+30)*kRowBytes)+kFirstCol+52)  ; Must be even!
kIcn2Offset EQU  (((kFirstRow+70)*kRowBytes)+kFirstCol+52)  ; Must be even!

    ; ### Addresses ###

    ; Data addresses
kKeyId      EQU  $01B2               ; Keyboard identifier byte
kRomVWord   EQU  $00FE3FFC           ; ROM version word
kScreen     EQU  $0110               ; ROM-set pointer to bottom of video memory
kStdStatus  EQU  $01B4               ; ROM-alloc'd space for 4-byte disk status

    ; Device addresses
kDiskMem    EQU  $00FCC001           ; Shared disk controller memory
kVia1Base   EQU  $00FCDD81           ; VIA handling parallel port resets
kVia2Base   EQU  $00FCD901           ; VIA handling parallel port data+handshake

    ; ROM public routines
kConvRtd5   EQU  $00FE0088           ; Display a string on the screen
kInitMon    EQU  $00FE0084           ; Boot ROM monitor
kProRead    EQU  $00FE0090           ; Read hard disk sector
kTwgRead    EQU  $00FE0094           ; Read floppy disk sector

    ; ROM private resources we use anyway, since they're not making new ROMs :-)
kSetRomDefs SET  0                   ; ROM resources are as-yet undefined

            IFEQ (kBootRom-'H')
kCrtRow     EQU  $00000300           ; Scratch location for text display row
kCrtCol     EQU  $00000302           ; Scratch location for text display column
kStatFlags  EQU  $000002A2           ; Various ROM status flags
kRectCount  EQU  $0000053A           ; Count of "active rectangles"

kClearDbox  EQU  $00FE2C28           ; Erase "dialogue box" (input window)
kClearDesk  EQU  $00FE30DA           ; Clear desktop
kCrsrDsply  EQU  $00FE300E           ; Redisplay the mouse cursor
kCrsrHide   EQU  $00FE2FEA           ; Hide the mouse cursor
kDispIcon   EQU  $00FE35E2           ; Display a compressed icon from the ROM
kDispMnuBox EQU  $00FE27D0           ; Display a menu box
kDispMsg    EQU  $00FE3700           ; Print a message
kDispVal    EQU  $00FE373A           ; Print a single character
kEjectDisk  EQU  $00FE1E56           ; Eject floppy disk
kFindD2     EQU  $00FE20BC           ; ProFile/Widget handshake
kGetError   EQU  $00FE26E6           ; kGetInput error bailout routine
kGetInput   EQU  $00FE2C46           ; Get keyboard/mouse input
kMakeDbox   EQU  $00FE31B2           ; Make a "dialogue box" (input window)
kMakeMenu   EQU  $00FE336A           ; Make a drop-down menu
kMakeWindow EQU  $00FE31C6           ; Make a window
kPaintBox   EQU  $00FE3128           ; Draw a rectangle tiled with a word
kProInit    EQU  $00FE1FF0           ; Initialise parallel I/O
kScroll     EQU  $00FE2B08           ; Scroll service mode text up one line
kWait4Input EQU  $00FE2D38           ; Wait for input from kbd/mouse COPS

kIconLisa   EQU  $00FE3D54           ; Apple Lisa icon (compressed)
kIconUpper  EQU  $00FE3ADA           ; "Upper" drive icon (compressed)

kSetRomDefs SET  1                   ; ROM resources are defined for version H
            ENDC

            IFEQ kSetRomDefs         ;
            FAIL 'ROM resources are undefined for the kBootRom ROM version'
            ENDC

    ; ### Miscellaneous ###

kSecCode    EQU  0                   ; Section identifier for code
kSecData    EQU  1                   ; Section identifier for numerical data
kSecScratch EQU  2                   ; Section identifier for scratch space
kSecStrings EQU  3                   ; Section identifier for strings
