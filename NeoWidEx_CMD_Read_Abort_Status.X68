*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Read_Abort_Status
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the read abort status command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Read_Abort_Status code ==========================

    ; CMD_Read_Abort_Status -- Attempt the Read_Abort_Status command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D2/A0-A1.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Read_Abort_Status:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- READ ABORT STATUS ---'>
    MOVE.B  #2,D0                    ; The command is two bytes long
    LEA     sCmdReadAbortStatus,A0   ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    MOVE.W  #$10,zWIOReadLen         ; The abort status result is 16 bytes long
    MOVE.L  #z_CmdReadAbortStatusData,zWIOReadPtr  ; It should be written here
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Print and interpret status
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS                              ; Back to caller

    ; First, print the abort status code.
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'ABORT STATUS CODE'>
    LEA     z_CmdReadAbortStatusData,A0  ; Address of data to dump
    mDump.B kCrtRow,kCrtCol,#kFirstCol,A0,#16,endl   ; Dump it
    SUBA.L  #16,A0                   ; Rewind A0 to top of abort status

    ; Next, interpret the data by trying to match the abort status reason
    ; (the last word in the buffer) with a table of error codes and
    ; interpretations from the Widget ERS document. The document may well be
    ; out-of-date for the latest Widget ROMs, so the interpretations may not
    ; be very useful.
    MOVE.W  $E(A0),D0                ; Copy the abort status reason word to D0
    LEA     s_CmdReadAbortStatusErrTbl,A1  ; Point A1 at top of table

.lo MOVE.W  (A1)+,D1                 ; Copy this table entry status reason to D1
    BEQ     .no                      ; End of the table? Print "unknown status"
    CMP.W   D1,D0                    ; Is this table entry for our abort status?
    BEQ.S   .pr                      ; Yes, print the information
.li ADDQ.L  #4,A1                    ; No, go past description string address
    TST.W   (A1)+                    ; Done with this table entry yet?
    BPL.S   .li                      ; No, back to top of inner loop
    BRA.S   .lo                      ; Back to outer loop for next table entry

.pr MOVE.L  (A1)+,-(A7)              ; Description to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D>,s   ; Print description
.lp MOVE.W  (A1)+,D1                 ; Copy status code index to D1
    BMI     .rt                      ; Negative? Table entry is over; exit
    MOVE.B  0(A0,D1.W),-(A7)         ; Stat. code byte @ index to stack to print
    MOVE.L  (A1)+,D2                 ; Field description pointer to D2
    BEQ     .pc                      ; No new description? Print code byte now
    MOVE.L  D2,-(A7)                 ; Field description to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  '>,s,<'-'>  ; Print description
.pc mPrint  kCrtRow,kCrtCol,#kFirstCol,hhx   ; Print status code byte
    BRA     .lp                      ; On to next field in this table entry

.no MOVE.W  D0,-(A7)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'NO KNOWN INTERPRETATION FOR '>,hx
.rt RTS                              ; Back to caller

    PAGE
* NeoWidEx Read_AbortStatus scratch data allocation ========
    SECTION kSecScratch

    DS.W    0                        ; Word-align the data for our convenience
z_CmdReadAbortStatusData:
    DS.B    16                       ; The 16-byte reward status data


    PAGE
* NeoWidEx Read_Abort_Status strings =======================
    SECTION kSecStrings

sCmdReadAbortStatus:
    DC.B    $10,$11                  ; Read_Abort_Status command (it's short!)

    DS.W    0
s_CmdReadAbortStatusErrTbl:
    DC.W    $02EA                    ; Reason for abort (word)
    DC.L    s_CmdReadAbortStatus02EA
    DC.W    $0009                    ; Print this byte with the following legend
    DC.L    s_CmdReadAbortStatus02EA_p1
    DC.W    $FFFF                    ; Negative means no more bytes to print

    DC.W    $03B8
    DC.L    s_CmdReadAbortStatus03B8
    DC.W    $0000
    DC.L    s_CmdReadAbortStatus03B8_p1
    DC.W    $FFFF

    DC.W    $0487
    DC.L    s_CmdReadAbortStatus0487
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus0487_p1
    DC.W    $FFFF

    DC.W    $04CB
    DC.L    s_CmdReadAbortStatus04CB
    DC.W    $0000
    DC.L    s_CmdReadAbortStatus04CB_p1
    DC.W    $FFFF

    DC.W    $0513
    DC.L    s_CmdReadAbortStatus0513
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus0513_p1
    DC.W    $000B
    DC.L    $00000000                ; This byte continues the prior byte
    DC.W    $FFFF

    DC.W    $1101
    DC.L    s_CmdReadAbortStatus1101
    DC.W    $0009
    DC.L    s_CmdReadAbortStatus1101_p1
    DC.W    $FFFF

    DC.W    $1203
    DC.L    s_CmdReadAbortStatus1203
    DC.W    $FFFF

    DC.W    $1217
    DC.L    s_CmdReadAbortStatus1217
    DC.W    $FFFF

    DC.W    $1310
    DC.L    s_CmdReadAbortStatus1310
    DC.W    $FFFF

    DC.W    $13E8
    DC.L    s_CmdReadAbortStatus13E8
    DC.W    $FFFF

    DC.W    $1513
    DC.L    s_CmdReadAbortStatus1513
    DC.W    $FFFF

    DC.W    $158D
    DC.L    s_CmdReadAbortStatus158D
    DC.W    $FFFF

    DC.W    $16B4
    DC.L    s_CmdReadAbortStatus16B4
    DC.W    $FFFF

    DC.W    $1919
    DC.L    s_CmdReadAbortStatus1919
    DC.W    $FFFF

    DC.W    $1B01
    DC.L    s_CmdReadAbortStatus1B01
    DC.W    $FFFF

    DC.W    $1B56
    DC.L    s_CmdReadAbortStatus1B56
    DC.W    $0000
    DC.L    s_CmdReadAbortStatus1B56_p1
    DC.W    $FFFF

    DC.W    $1BAB
    DC.L    s_CmdReadAbortStatus1BAB
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus1BAB_p1
    DC.W    $FFFF

    DC.W    $1BD2
    DC.L    s_CmdReadAbortStatus1BD2
    DC.W    $FFFF

    DC.W    $1C15
    DC.L    s_CmdReadAbortStatus1C15
    DC.W    $FFFF

    DC.W    $1C24
    DC.L    s_CmdReadAbortStatus1C24
    DC.W    $0009
    DC.L    s_CmdReadAbortStatus1C24_p1
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus1C24_p2
    DC.W    $FFFF

    DC.W    $1C78
    DC.L    s_CmdReadAbortStatus1C78
    DC.W    $FFFF

    DC.W    $1CFF
    DC.L    s_CmdReadAbortStatus1CFF
    DC.W    $FFFF

    DC.W    $1E4A
    DC.L    s_CmdReadAbortStatus1E4A
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus1E4A_p1
    DC.W    $FFFF

    DC.W    $1F2F
    DC.L    s_CmdReadAbortStatus1F2F
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus1F2F_p1
    DC.W    $FFFF

    DC.W    $2021
    DC.L    s_CmdReadAbortStatus2021
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus2021_p1
    DC.W    $FFFF

    DC.W    $21F7
    DC.L    s_CmdReadAbortStatus21F7
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus21F7_p1
    DC.W    $000B
    DC.L    $00000000                ; This byte continues the prior byte
    DC.W    $000C
    DC.L    $00000000                ; This byte continues the prior byte
    DC.W    $FFFF

    DC.W    $2370
    DC.L    s_CmdReadAbortStatus2370
    DC.W    $FFFF

    DC.W    $2493
    DC.L    s_CmdReadAbortStatus2493
    DC.W    $FFFF

    DC.W    $24B3
    DC.L    s_CmdReadAbortStatus24B3
    DC.W    $FFFF

    DC.W    $2522
    DC.L    s_CmdReadAbortStatus2522
    DC.W    $0009
    DC.L    s_CmdReadAbortStatus2522_p1
    DC.W    $FFFF

    DC.W    $265E
    DC.L    s_CmdReadAbortStatus265E
    DC.W    $FFFF

    DC.W    $26B8
    DC.L    s_CmdReadAbortStatus26B8
    DC.W    $FFFF

    DC.W    $29E0
    DC.L    s_CmdReadAbortStatus29E0
    DC.W    $000A
    DC.L    s_CmdReadAbortStatus29E0_p1
    DC.W    $FFFF

    DC.W    $2A10
    DC.L    s_CmdReadAbortStatus2A10
    DC.W    $FFFF

    DC.W    $2D13
    DC.L    s_CmdReadAbortStatus2D13
    DC.W    $FFFF

    DC.W    $0000                    ; End of table

s_CmdReadAbortStatus02EA:
    DC.B    'ILLEGAL INTERFACE RESPONSE OR HOST NAK',0
s_CmdReadAbortStatus02EA_p1:
    DC.B    'RESPONSE BYTE FROM HOST',0

s_CmdReadAbortStatus03B8:
    DC.B    'ILLEGAL RAM BANK SELECT',0
s_CmdReadAbortStatus03B8_p1:
    DC.B    'BANK NUMBER OF ATTEMPTED SELECT',0

s_CmdReadAbortStatus0487:
    DC.B    'FORMAT ERROR-ILLEGAL STATE MACHINE STATE',0
s_CmdReadAbortStatus0487_p1:
    DC.B    'STATE WHEN ERROR OCCURRED',0

s_CmdReadAbortStatus04CB:
    DC.B    'ILLEGAL BANK SWITCH AT CALL OR RETURN',0
s_CmdReadAbortStatus04CB_p1:
    DC.B    'TRIED TO SELECT THIS BANK',0

s_CmdReadAbortStatus0513:
    DC.B    'ILLEGAL INTERRUPT OR DEAD MAN TIMEOUT',0
s_CmdReadAbortStatus0513_p1:
    DC.B    'ADDRESS OF ROUTINE AT TIMEOUT',0

s_CmdReadAbortStatus1101:
    DC.B    'ILLEGAL INTERRUPT OR DEAD MAN TIMEOUT',0
s_CmdReadAbortStatus1101_p1:
    DC.B    'ADDRESS OF ROUTINE AT TIMEOUT',0

s_CmdReadAbortStatus11EA:
    DC.B    'COMMAND CHECKSUM ERROR',0

s_CmdReadAbortStatus1203:
    DC.B    'NON-DIAG COMMAND ATTEMPTED AFTER SELF-TEST ERROR',0

s_CmdReadAbortStatus1217:
    DC.B    'ILLEGAL INTERFACE INSTRUCTION',0

s_CmdReadAbortStatus1310:
    DC.B    'UNRECOVERABLE SERVO ERROR DURING READ',0

s_CmdReadAbortStatus13E8:
    DC.B    'TRIED TO SPARE ON NON-EXISTENT SPARE BLOCK',0

s_CmdReadAbortStatus1513:
    DC.B    'TRIED TO SPARE BUT SPARE TABLE WAS FULL',0

s_CmdReadAbortStatus158D:
    DC.B    'TRIED TO DELETE NON-EXISTENT BAD BLOCK',0

s_CmdReadAbortStatus16B4:
    DC.B    'ILLEGAL EXCEPTION INSTRUCTION',0

s_CmdReadAbortStatus1919:
    DC.B    'UNRECOVERABLE SERVO ERROR DURING WRITE',0

s_CmdReadAbortStatus1B01:
    DC.B    'SERVO STATUS REQUEST SENT AS SERVO COMMAND',0

s_CmdReadAbortStatus1B56:
    DC.B    'RESTORE ERROR-INVALID RECALIBRATION PARAMETER-',0
s_CmdReadAbortStatus1B56_p1:
    DC.B    'THE WEIRD PARAMETER',0

s_CmdReadAbortStatus1BAB:
    DC.B    'STORE MAP ERROR-PARAMETER BIGGER THAN SECTOR COUNT',0
s_CmdReadAbortStatus1BAB_p1:
    DC.B    'THE WEIRD PARAMETER',0

s_CmdReadAbortStatus1BD2:
    DC.B    'ILLEGAL PASSWORD FOR WRITE SPARE TABLE',0

s_CmdReadAbortStatus1C15:
    DC.B    'ILLEGAL PASSWORD FOR FORMAT',0

s_CmdReadAbortStatus1C24:
    DC.B    'ILLEGAL PARAMETERS FOR FORMAT',0
s_CmdReadAbortStatus1C24_p1:
    DC.B    'OFFSET',0
s_CmdReadAbortStatus1C24_p2:
    DC.B    'INTERLEAVE',0

s_CmdReadAbortStatus1C78:
    DC.B    'ILLEGAL PASSWORD FOR FORMAT',0

s_CmdReadAbortStatus1CFF:
    DC.B    'ZERO BLOCK COUNT FOR MULTI-BLOCK TRANSFER',0

s_CmdReadAbortStatus1E4A:
    DC.B    'WRITE ERROR-ILLEGAL STATE MACHINE STATE',0
s_CmdReadAbortStatus1E4A_p1:
    DC.B    'STATE WHEN ERROR OCCURRED',0

s_CmdReadAbortStatus1F2F:
    DC.B    'READ ERROR-ILLEGAL STATE MACHINE STATE',0
s_CmdReadAbortStatus1F2F_p1:
    DC.B    'STATE WHEN ERROR OCCURRED',0

s_CmdReadAbortStatus2021:
    DC.B    'READ HEADER ERROR-ILLEGAL STATE MACHINE STATE',0
s_CmdReadAbortStatus2021_p1:
    DC.B    'STATE WHEN ERROR OCCURRED',0

s_CmdReadAbortStatus21F7:
    DC.B    'ILLEGAL LOGICAL BLOCK SPECIFIED',0
s_CmdReadAbortStatus21F7_p1:
    DC.B    'LOGICAL BLOCK',0

s_CmdReadAbortStatus2370:
    DC.B    'SEARCH FOR SPARE TABLE FAILED',0

s_CmdReadAbortStatus2493:
    DC.B    'SPARE TABLE STRUCTURE NOT FOUND IN SPARE TABLE',0

s_CmdReadAbortStatus24B3:
    DC.B    'SPARE TABLE UPDATE FAILED',0

s_CmdReadAbortStatus2522:
    DC.B    'ILLEGAL SPARE COUNT INSTRUCTION',0
s_CmdReadAbortStatus2522_p1:
    DC.B    'INSTRUCTION',0

s_CmdReadAbortStatus265E:
    DC.B    'UNRECOVERABLE SERVO ERROR DURING OVERLAPPED SEEK',0

s_CmdReadAbortStatus26B8:
    DC.B    'UNRECOVERABLE SERVO ERROR DURING SEEK',0

s_CmdReadAbortStatus29E0:
    DC.B    'SERVO ERROR AFTER SERVO RESET',0
s_CmdReadAbortStatus29E0_p1:
    DC.B    'CONTROLLER STATUS PORT',0

s_CmdReadAbortStatus2A10:
    DC.B    'SERVO COMMUNICATION ERROR AFTER SERVO RESET',0

s_CmdReadAbortStatus2D13:
    DC.B    'SCAN ATTEMPTED WITHOUT SPARE TABLE',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
