*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_ProFile_Write
* Written by : Tom Stepleton
* Date       : 2 January 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the ProFile write command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Send_Seek must be defined.
*-----------------------------------------------------------


* NeoWidEx ProFile_Write code ==============================

    ; CMD_ProFile_Write -- Attempt the ProFile_Write command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_ProFile_Write:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if it hasn't been run yet
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- GENERIC WRITE ---'>

    ; Block form field initial value can be copied from the command itself.
    MOVE.L  zProWriteCmd,z_CProWriteInitialVals  ; Copy initial value
    CLR.B   z_CProWriteInitialVals   ; Clear the "write" command byte
    ; Set form field upper bound based on the size of the drive.
    MOVE.L  zNumBlocks,D0            ; Number of blocks into D0
    SUBQ.L  #1,D0                    ; Subtract 1 to get form upper bound
    MOVE.L  D0,z_CProWriteBounds     ; Copy into form bounds array
    ; Ask user which block they'd like to write to.
    LEA     s_CProWriteForm,A0       ; Prepare FORM args: address of template...
    LEA     s_CProWritePrompts,A1    ; ...address of prompt pointer array...
    LEA     z_CProWriteInitialVals,A2  ; ...address of initial values array...
    LEA     z_CProWriteBounds,A3     ; ...and address of value bounds
    BSR     FORM                     ; Display form; get user input
    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, jump ahead to quit
    MOVE.L  zFieldValues,zProWriteCmd  ; No, copy desired block to command

    ; Ask user if they *really* want to write.
    LEA     s_CProWriteConfForm,A0   ; Prepare FORM args: address of template...
    LEA     s_CProWriteConfPrompts,A1  ; ...address of prompt pointer array...
    SUBA.L  A2,A2                    ; ...with no initial values specified...
    SUBA.L  A3,A3                    ; ...or value bounds
    BSR     FORM                     ; Display form; get user input
    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .qt                      ; Yes, jump ahead to quit
    TST.B   (3+zFieldValues)         ; Did the user say "no"?
    BEQ     .qt                      ; They did, jump ahead to quit

    ; Perform the write
    MOVE.B  #1,zProWriteCmd          ; Reset actual command byte to 1
    MOVE.B  #4,zWIOCmdLen            ; This command is four bytes long
    mMemCpy #zProWriteCmd,#zWIOCmd,#4  ; We copy it to the command buffer
    CLR.W   zWIOReadLen              ; No command in this file reads bytes
    MOVE.W  zBlockSize,zWIOWriteLen  ; Write a whole block to the Widget
    MOVE.L  #zSectorTag,zWIOWritePtr   ; Write data at this memory location
    BSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the write command go ok?
    BEQ     .ok                      ; Yes, jump to exit
    BSR     WIDGETPERROR             ; Error! Print error message
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<$0D,'SEE STATUSES FOR DETAILS.'>
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

.qt mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Ack quit intent
    RTS                              ; Back to caller

    PAGE
* NeoWidEx ProFile_Write scratch data allocation ===========
    SECTION kSecScratch

    DS.W    0                        ; (Alignment makes copying easier)
zProWriteCmd:
    DC.B    $01,$00,$00,$00          ; Write command; bytes 2-4 are alterable

    DS.W    0
z_CProWriteInitialVals:              ; Initial values array for block form
    DC.L    $00000000

z_CProWriteBounds:                   ; Upper bounds array for block form
    DC.L    $00000000


    PAGE
* NeoWidEx ProFile_Write strings ===========================
    SECTION kSecStrings

s_CProWriteForm:                     ; User form asking which block to write
    DC.B    $0D,'WRITE TO LOGICAL BLOCK ac____',0

    DS.W    0
s_CProWritePrompts:                  ; Prompt strings array for block form
    DC.L    .p1
.p1 DC.B    'BLOCK',0

s_CProWriteConfForm:                 ; User form asking to confirm write
    DC.B    $0D,'REALLY WRITE BLOCK? a',0

    DS.W    0
s_CProWriteConfPrompts:              ; Prompt strings array for conf. form
    DC.L    .p1
.p1 DC.B    'WRITE',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
