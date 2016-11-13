*-----------------------------------------------------------
* Title      : NeoWidEx
* Written by : Tom Stepleton
* Date       : XX November 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: I/O subroutines.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_UI must be defined.
*-----------------------------------------------------------

    ; SECTOR -- Read a sector from the hard drive into memory
    ; Args:
    ;   D1: sector to read
    ; Notes:
    ;   Tag data is loaded to zSectorTag.
    ;   Sector data is loaded to zSectorData.
    ;   Trashes registers D0-D4/A0-A3.
    ;   On failure, the carry bit is set; an error word is in D0; and a
    ;       four-byte error byte string is in D1.
SECTOR:
    MOVEA.L #zSectorTag,A1           ; Load sector tag here
    MOVEA.L #zSectorData,A2          ; Load sector data here
    MOVE.L  #kSctrTime,D2            ; Sector read timeout
    MOVEQ.L #kSctrTries,D3           ; Sector read retries
    MOVEQ.L #kSctrThresh,D4          ; Sector read threshold count
    JSR     kProRead                 ; Read the sector
    BCS.S   .er                      ; Problem? Jump ahead to print error
    RTS                              ; No problem; back to caller
.er MOVE.L  D1,-(A7)                 ; Push error bytes for printing
    MOVE.W  D0,-(A7)                 ; Push error code for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'DRIVE READ ERROR -- CODE-'>
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<' BYTES-'>,lx,<$0D>
    ORI.B   #$1,CCR                  ; Reset carry bit to mark the error
    RTS                              ; Back to caller
