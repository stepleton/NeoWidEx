*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Send_Seek
* Written by : Tom Stepleton
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: Seek to a particular cylinder/head/sector.
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Send_Seek code ==================================

    ; CMD_Send_Seek -- Seek to a particular cylinder/head/sector
    ; Args:
    ;   (none)
    ; Notes:
    ;   Trashes D0-D4/A0-A4.
    ;   If WIDGETINFO runs, has all of WIDGETINFO's side-effects.
CMD_Send_Seek:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- SEEK ---'>
CMD_Send_Seek_nobanner:
    CLR.W   zWIOReadLen              ; No command we use reads any data
    CLR.W   zWIOWriteLen             ; No command we use writes any data

    ; Set form bounds based on drive information
    CLR.L   D0                       ; Prepare to compute cylinder field bound
    MOVE.W  zCylinders,D0            ; Number of cylinders
    SUBQ.W  #1,D0                    ; Largest addressable cylinder...
    MOVE.L  D0,z_CSndSkBounds        ; ...is upper bound for first form field
    CLR.W   D0                       ; Prepare to compute head field bound
    MOVE.B  zHeads,D0                ; Number of heads
    SUBQ.B  #1,D0                    ; Largest addressable head...
    MOVE.L  D0,(4+z_CSndSkBounds)    ; ...is upper bound for second form field
    MOVE.B  zSectors,D0              ; Number of sectors
    SUBQ.B  #1,D0                    ; Largest addressable sector...
    MOVE.L  D0,(8+z_CSndSkBounds)    ; ...is upper bound for third form field

    ; Query current seek status from controller internal status info.
    MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSndSkStatusSeek,A0    ; Command: get int status, curr seek addr
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .fm                      ; All OK? Advance to fill and show form
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSndSkStatusErr0
    BSR     WIDGETPERROR             ; Error! Print error message
    CLR.L   kStdStatus               ; Clear std. stat; seek will init to 0/0/0

    ; Fill form initial values
.fm CLR.L   D0                       ; Prepare to hold initial cylinder value
    MOVE.W  kStdStatus,D0            ; Current seek cylinder...
    MOVE.L  D0,z_CSndSkInitialVals   ; ...is initial value for cylinder field
    CLR.W   D0                       ; Prepare to hold initial head value
    MOVE.B  (2+kStdStatus),D0        ; Current seek head...
    MOVE.L  D0,(4+z_CSndSkInitialVals)   ; ...is initial value for head field
    MOVE.B  (3+kStdStatus),D0        ; Current seek sector...
    MOVE.L  D0,(8+z_CSndSkInitialVals)   ; ...is initial value for sector field

    ; Query user for seek parameters
    LEA     s_CSndSkForm,A0          ; Prepare FORM args: address of template...
    LEA     s_CSndSkPrompts,A1       ; ...address of prompt pointer array...
    LEA     z_CSndSkInitialVals,A2   ; ...address of initial values array...
    LEA     z_CSndSkBounds,A3        ; ...address of value bounds array
    BSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE.S   .go                      ; No, go ahead with seeking
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>   ; Yes, ack user
    RTS                              ; Back to caller

    ; Perform user-specified seek.
.go MOVEA.L #(2+zFieldValues),A0     ; Copy parameters from form values...
    MOVEA.L #(2+zSendSeekCmd),A1     ; ...to the command
    MOVE.B  (A0)+,(A1)+              ; Cylinder high byte
    MOVE.B  (A0)+,(A1)+              ; Cylinder low byte
    ADDQ.L  #3,A0                    ; Skip ahead to field's head value
    MOVE.B  (A0)+,(A1)+              ; Head
    ADDQ.L  #3,A0                    ; Skip ahead to field's sector value
    MOVE.B  (A0)+,(A1)+              ; Sector
    MOVE.B  #6,D0                    ; This command is six bytes long
    LEA     zSendSeekCmd,A0          ; Point A0 to the seek command template
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .is                      ; All OK? Advance to reload internal status
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO SEEK.'>
    BSR     WIDGETPERROR             ; Error! Print error message

    ; Query new seek address from controller internal status info.
.is MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSndSkStatusSeek,A0    ; Command: get int status, curr seek addr
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .ps                      ; All OK? Advance to print seek address
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSndSkStatusErr1
    BSR     WIDGETPERROR             ; Error! Print error message
    BRA     .iy                      ; Skip ahead to get current cylinder

    ; Report Widget's new seek address
.ps MOVE.B  (3+kStdStatus),-(A7)     ; Seek address sector onto stack
    MOVE.B  (2+kStdStatus),-(A7)     ; Seek address head onto stack
    MOVE.W  kStdStatus,-(A7)         ; Seek address cylinder onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  SEEK ADDRESS IS CYLINDER-'>,hx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' HEAD-'>,hhx,<' SECTOR-'>,hhx

    ; Query new current cylinder from controller internal status info.
.iy MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSndSkStatusCyl,A0     ; Command: get int status, curr seek pos
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .py                      ; All OK? Advance to print current cylinder
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_CSndSkStatusErr2
    BSR     WIDGETPERROR             ; Error! Print error message
    BRA     .ss                      ; Skip ahead to get standard status

    ; Report Widget's current cylinder
.py MOVE.W  kStdStatus,-(A7)         ; Current cylinder onto stack
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'          CURRENT CYLINDER-'>,hx

    ; Restore standard status in kStdStatus.
.ss MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_CSndSkStatusStd,A0     ; Command: get standard controller status
    BSR     WIDGETCMD                ; Construct actual command in RAM
    BSR     WIDGETIO                 ; Issue command
    BEQ     .rt                      ; All OK? Advance to return to caller
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO GET STANDARD STATUS.'>
    BSR     WIDGETPERROR             ; Error! Print error message

.rt RTS                              ; Back to caller


    PAGE
* NeoWidEx Send_Seek scratch data allocation ===============
    SECTION kSecScratch

zSendSeekCmd:
    DC.B    $10,$04,$00,$00,$00,$00  ; Command; last four bytes are alterable
    DS.W    0                        ; Force even alignment for following data

z_CSndSkInitialVals:
    DC.B    'Send'                   ; Initial field values for the form
    DC.B    'Seek'
    DC.B    'Init'
z_CSndSkBounds:
    DC.B    'Send'                   ; Bounds for Send_Seek parameters
    DC.B    'Seek'
    DC.B    'Bnds'


    PAGE
* NeoWidEx Send_Seek strings ===============================
    SECTION kSecStrings

s_CSndSkStatusSeek:
    DC.B    $10,$01,$02              ; Command to get current seek address
s_CSndSkStatusCyl:
    DC.B    $10,$01,$03              ; Command to get current cylinder
s_CSndSkStatusStd:
    DC.B    $10,$01,$00              ; Command to read standard status

s_CSndSkStatusErr0:
    DC.B    $0D,'FAILED TO GET WIDGET SEEK ADDRESS.',0
s_CSndSkStatusErr1:
    DC.B    $0D,'FAILED TO GET NEW WIDGET SEEK ADDRESS.',0
s_CSndSkStatusErr2:
    DC.B    $0D,'FAILED TO GET CURRENT CYLINDER.',0

s_CSndSkForm:                        ; User form for specifying seek parameters
    DC.B    $0D,'SEEK TO CYLINDER-ab__ HEAD-ba SECTOR-ca',0

    DS.W    0
s_CSndSkPrompts:                     ; Form prompts for seek parameters
    DC.L    .p1,.p2,.p3
.p1 DC.B    'CYLINDER',0
.p2 DC.B    'HEAD',0
.p3 DC.B    'SECTOR',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
