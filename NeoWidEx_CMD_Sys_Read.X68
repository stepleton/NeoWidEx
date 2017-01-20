*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Sys_Read
* Written by : Tom Stepleton
* Date       : XX January 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: issues the Sys_Read command.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Sys_Read code ===================================

    ; CMD_Sys_Read -- Attempt Sys_Read command
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Sys_Read:
  ; BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
  BSR WINFOMAYBE
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- WIDGET READ ---'>

    ; Set form bounds based on drive information
    CLR.L   D0                       ; Assemble start block bound in D0
    MOVE.L  zNumBlocks,D0            ; This parameter can't exceed the number...
    SUBQ.L  #1,D0                    ; ...of blocks minus 1
    MOVE.L  D0,z_CSysReadBounds      ; Copy to bounds array
   
    ; Query user for initialisation parameters
    LEA     s_CSysReadForm,A0        ; Prepare FORM args: address of template...
    LEA     s_CSysReadPrompts,A1     ; ...address of prompt pointer array...
    LEA     z_CSysReadInitialVals,A2   ; ...address of initial values array...
    LEA     z_CSysReadBounds,A3      ; ...address of value bounds array
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .cp                      ; No, go ahead and issue the read command
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Copy parameters into the read command
.cp mMemCpy #(1+zFieldValues),#(3+zSysReadCmd),#3  ; Copy starting block
    MOVE.B  (7+zFieldValues),(2+zSysReadCmd)   ; Copy block count
    BNE.S   .sv                      ; Was it 0? Bail; otherwise move along
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'COUNT MUST BE NONZERO.'>
    RTS                              ; Back to caller

    ; Save parameters to be the default for next time
.sv mMemCpy #zFieldValues,#z_CSysReadInitialVals,#8

    ; Execute the read
    MOVE.B  #6,D0                    ; The command is six bytes long
    LEA     zSysReadCmd,A0           ; Location of the command template in RAM
    BSR     WIDGETCMD                ; Construct actual command in RAM
    MOVE.W  zBlockSize,zWIOReadLen   ; Read blocks of this size from the Widget
    MOVE.L  #zSectorTag,zWIOReadPtr  ; Read into this memory location
    CLR.W   zWIOWriteLen             ; No command in this file writes bytes
    BSR     WIDGETIO                 ; Issue command
    BSR     WINFOSTATUSCHECK         ; Force info refresh if spares have changed
    TST.B   zWIOError                ; Did the read command go ok?
    BEQ     .ex                      ; Yes, go check read exception register
    BSR     WIDGETPERROR             ; Error! Print error message
    MOVE.L  kStdStatus,-(A7)         ; Raw standard status to stack
    ; We go ahead and print the standard status because we are going to
    ; overwrite it in investigations to follow. This way the user can still
    ; inspect it for clues.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  RAW STANDARD STATUS-'>,lx

    ; Get exception registers from Widget
.ex MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSysReadStatusExp,A0   ; Location of the command template in RAM
    CLR.W   zWIOReadLen              ; Remaining cmds in this file read no bytes
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .rx                      ; All OK? Examine read exception register
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSysReadStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    BRA     .ss                      ; Skip ahead to get standard status

    ; Examine read exception register for errors
.rx CMPI.W  #$2000,kStdStatus        ; A nominal read has register value $2000
    BEQ     .ss                      ; Looks good, skip ahead to get std. status
    MOVE.W  kStdStatus,-(A7)         ; Error! Read-exception register onto stack
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSysReadExceptionErr
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx,<$0D,'SEE FULL STATUS FOR DETAILS.'>

    ; Restore standard status in kStdStatus.
.ss MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSysReadStatusStd,A0   ; Command: get standard controller status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ok                      ; All OK? Advance to return to caller
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO GET STANDARD STATUS.'>
    BSR     WIDGETPERROR             ; Error! Print error message
    RTS
.ok mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    PAGE
* NeoWidEx Sys_Read scratch data allocation ================
    SECTION kSecScratch

zSysReadCmd:
    DC.B    $20,$00,$00,$00,$00,$00  ; Command; last four bytes are alterable
    DS.W    0                        ; Force even alignment for following data

z_CSysReadInitialVals:
    DC.L    $00000000                ; Initial field values for the form
    DC.L    $00000001
z_CSysReadBounds:
    DC.B    'SyRd'                   ; Bounds for command parameters
    DC.L    $00000014


    PAGE
* NeoWidEx Sys_Read strings ================================
    SECTION kSecStrings

s_CSysReadStatusExp:
    DC.B    $10,$01,$06              ; Command to read exception registers
s_CSysReadStatusStd:
    DC.B    $10,$01,$00              ; Command to read standard status

s_CSysReadStatusErr0:
    DC.B    $0D,'FAILED TO RETRIEVE EXCEPTION REGISTERS.',0
s_CSysReadExceptionErr:
    DC.B    $0D,'READ EXCEPTION DETECTED. EXCEPTION REGISTER-',0

s_CSysReadForm:                      ; User form for command parameters
    DC.B    $0D,'FROM BLOCK ac____ READ ba BLOCKS',0

    DS.W    0
s_CSysReadPrompts:                   ; Form prompts for command parameters
    DC.L    .p1,.p2
.p1 DC.B    'BLOCK',0
.p2 DC.B    'COUNT',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
