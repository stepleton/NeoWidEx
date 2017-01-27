*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_ProFile_Read
* Written by : Tom Stepleton
* Date       : 2 January 2016
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the ProFile read command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*      Resources from NeoWidEx_CMD_Send_Seek must be defined.
*-----------------------------------------------------------


* NeoWidEx ProFile_Read code ===============================

    ; CMD_ProFile_Read -- Attempt the ProFile_Read command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_ProFile_Read:
    BSR     WINFOMAYBE               ; Run WIDGETINFO if it hasn't been run yet
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- GENERIC READ ---'>

    ; Form field initial value can be copied from the command itself.
    MOVE.L  zProReadCmd,z_CProReadInitialVals  ; Copy initial value
    CLR.B   z_CProReadInitialVals    ; Don't have to since command is 0 anyway
    ; Set form field upper bound based on the size of the drive.
    MOVE.L  zNumBlocks,D0            ; Number of blocks into D0
    SUBQ.L  #1,D0                    ; Subtract 1 to get form upper bound
    MOVE.L  D0,z_CProReadBounds      ; Copy into form bounds array
    ; Ask user which block they'd like to read from.
    LEA     s_CProReadForm,A0        ; Prepare FORM args: address of template...
    LEA     s_CProReadPrompts,A1     ; ...address of prompt pointer array...
    LEA     z_CProReadInitialVals,A2   ; ...address of initial values array...
    LEA     z_CProReadBounds,A3      ; ...and address of value bounds
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, see if the user wanted to seek
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Perform the read
.go MOVE.L  zFieldValues,zProReadCmd   ; Copy desired block to command
    CLR.B   zProReadCmd              ; Reset actual command byte to 0
    MOVE.B  #4,zWIOCmdLen            ; This command is four bytes long
    mMemCpy #zProReadCmd,#zWIOCmd,#4   ; We copy it to the command buffer
    MOVE.W  zBlockSize,zWIOReadLen   ; Read a whole block from the Widget
    MOVE.L  #zSectorTag,zWIOReadPtr  ; Read into this memory location
    CLR.W   zWIOWriteLen             ; No command in this file writes bytes
    BSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the read command go ok?
    BEQ     .ok                      ; Yes, jump to exit
    BSR     WIDGETPERROR             ; Error! Print error message
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<$0D,'SEE STATUSES FOR DETAILS.'>
    RTS                              ; Back to caller
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    PAGE
* NeoWidEx ProFile_Read scratch data allocation ============
    SECTION kSecScratch

    DS.W    0                        ; (Alignment makes copying easier.)
zProReadCmd:
    DC.B    $00,$00,$00,$00          ; Read command; bytes 2-4 are alterable

    DS.W    0
z_CProReadInitialVals:               ; Initial values array for block form
    DC.L    $00000000

z_CProReadBounds:                    ; Upper bounds array for block form
    DC.L    $00000000


    PAGE
* NeoWidEx ProFile_Read strings ============================
    SECTION kSecStrings

s_CProReadForm:                      ; User form asking which block to read
    DC.B    $0D,'READ LOGICAL BLOCK ac____',0

    DS.W    0
s_CProReadPrompts:                   ; Prompt strings array for block form
    DC.L    .p1
.p1 DC.B    'BLOCK',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
