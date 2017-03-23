*-----------------------------------------------------------
* Title      : NeoWidEx_CMD_Track_Offsets
* Written by : Tom Stepleton
* Date       : 16 March 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: 
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_BUFFER must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_CMD_Read_Servo_Status.X68 must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Track Offsets code ==============================

    ; UTIL_Track_Offsets -- Measure fine servo offsets at each track.
    ; Args:
    ;   (none)
    ; Notes:
    ;   This routine moves the head with servo commands, not controller
    ;       commands, except if the user carries out a seek first, and at the
    ;       beginning and end when it issues Send_Restore commands. This results
    ;       in the servo executing a data recalibration and the controller
    ;       synchronising its understanding of the servo's state with the true
    ;       servo state.
    ;   Trashes D0-D4/A0-A4.
UTIL_Track_Offsets:
    BSR     WIDGETCHECK              ; Is this a Widget? If not, bail
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- CYLINDER ATF OFFSETS ---'>

    ; See if the user wants to seek first. This gives Diag_ReadHeader commands
    ; we'll issue an idea of which head and sector to use on all of the tracks
    ; on the disk.
    LEA     s_UTrakOfstForm,A0       ; Prepare FORM args: address of template
    LEA     s_UTrakOfstFormPrompts,A1  ; ...address of prompt pointer array...
    LEA     s_UTrakOfstFormInitialVals,A2  ; ...address of init. values array...
    SUBA.L  A3,A3                    ; ...and no value bounds specified
    JSR     FORM                     ; Display form; get user input

    ; Back from form; did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BNE     .ws                      ; No, see if the user wanted to seek
    ; Did user want to seek first?
.ws TST.B   (3+zFieldValues)         ; Check user want-to-seek response
    BEQ.S   .go                      ; Looks like no; skip ahead to start
    BSR     CMD_Send_Seek_nobanner   ; Yes; jump into seek code

    ; Did user give up while seeking?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     .q0                      ; Yes, jump ahead to quit

    ; PART 1: Perform data recalibration, then seek to track 0.
.go BSR     _UTrakOfstRecal          ; Attempt data recalibration
    BNE     .q1                      ; Abort on error
    MOVE.W  #$01F6,z_UTrakOfstTrackMin   ; Afterward, heads must be in...
    MOVE.W  #$01F9,z_UTrakOfstTrackMax   ; ...this range
    BSR     _UTrakOfstCheckTrack     ; Check that this is so
    BNE     .q1                      ; If not, give up

    MOVE.W  z_UTrakOfstTrack,z_UTrakOfstTrackMin   ; Current track to...
    MOVE.W  z_UTrakOfstTrack,z_UTrakOfstTrackMax   ; ...track bounds
.s0 BEQ     .hd                      ; Jump ahead if we're at track 0
    SUBQ.W  #1,z_UTrakOfstTrackMin   ; Decrement next track bounds
    SUBQ.W  #1,z_UTrakOfstTrackMax
    MOVE.W  z_UTrakOfstTrackMin,-(A7)  ; Next track to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'WALKING BACK TO FIRST TRACK-'>,hx
    SUBI.W  #kCharHeight,kCrtRow     ; Rewind cursor to overwrite the above
    BSR     _UTrakOfstAccessOut      ; Advance one track away from spindle
    BNE     .q2                      ; Give up on error
    BSR     _UTrakOfstCheckTrack     ; Check that head is over expected track
    BNE     .q2                      ; If not, give up
    TST.W   z_UTrakOfstTrack         ; Are we at track 0 yet?
    BRA     .s0                      ; Jump to top of loop (preserves flags)

    ; PART 2: Reset paging and print header
.hd mResetP                          ; Reset paging
    mPrtMem kCrtRow,kCrtCol,#kFirstCol,export,#s_UTrakOfstHeader   ; Show header

    ; PART 3: Main loop.
    ; First, text formatting. Should we print a newline and a new track header?
.lp MOVE.W  z_UTrakOfstTrack,D0      ; Copy current track to D0
    MOVE.W  D0,D1                    ; And clone it to D1
    ANDI.B  #$0F,D0                  ; Is the lower nibble all 0?
    BNE.S   .f1                      ; No, skip ahead to next formatting test
    mPrint  kCrtRow,kCrtCol,#kFirstCol,pendl   ; Yes, print paging newline first
    TST.B   zStopPaging              ; Did the user wish to abort?
    BNE     .q2                      ; Yes, jump ahead to recalibrate and quit
    MOVE.W  D1,-(A7)                 ; No, prepare to print row header...
    mPrint  kCrtRow,kCrtCol,#kFirstCol,hx  ; ...which is the current $___0 track
    ADDQ.W  #1,kCrtCol               ; And advance one column forward
    ; Or, should we space out our columns?
.f1 ANDI.B  #$03,D1                  ; Are the two LSBits 0?
    BNE.S   .tr                      ; No, jump ahead to obtaining track offset
    ADDQ.W  #1,kCrtCol               ; Yes, advance one column forward

    ; Print current offset and advance to next track.
.tr BSR     _UTrakOfstPrintDac       ; Retrieve and print servo offset DAC value
    BNE.S   .q2                      ; Give up on error
    ADDQ.W  #1,z_UTrakOfstTrackMin   ; Increment next track bounds
    ADDQ.W  #1,z_UTrakOfstTrackMax
    MOVE.W  zCylinders,D0            ; Copy total cylinders to D0
    CMP.W   z_UTrakOfstTrackMin,D0   ; Do bounds point beyond last cylinder?
    BLS.S   .ok                      ; Yes, jump ahead to normal exit
    BSR     _UTrakOfstAccessIn       ; No, advance one track toward spindle
    BNE.S   .q2                      ; Give up on error
    BSR     _UTrakOfstCheckTrack     ; Check that head is over expected track
    BNE.S   .q2                      ; Give up on error
    BRA     .lp                      ; Back to top of loop

    ; Normal subroutine exit, with data recal to synch servo and controller
.ok BSR     _UTrakOfstRecal          ; Perform data recal
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller

    ; Abnormal subroutine exit with data recal
.q2 mPrint  kCrtRow,kCrtCol,#kFirstCol<$0D,'TRYING DATA RECAL BEFORE ABORT...'>
    BSR     _UTrakOfstRecal          ; Try data recal
    ; Ordinary abnormal subroutine exit
.q1 mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>
.q0 RTS                              ; Back to caller


    ; _UTrakOfstRecal -- Issue Send_Restore with data recalibration parameter
    ; Args:
    ;   (none)
    ; Notes:
    ;   On return, the Z flag is set on success and clear on failure.
    ;   Trashes D0/A0.
_UTrakOfstRecal:
    MOVE.B  #3,D0                    ; The command is three bytes long
    LEA     s_UTrakOfstCmdDataRecal,A0   ; RAM location of the command template
    JSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; This command reads no data
    CLR.W   zWIOWriteLen             ; This command writes no data
    JSR     WIDGETIO                 ; Issue command
    BEQ.S   .rt                      ; All OK? Jump ahead to return
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DATA RECALIBRATION FAILED.'>
    JSR     WIDGETPERROR             ; Print disk error string
    TST.B   zWIOError                ; Restore flags to mark the error
.rt RTS                              ; Back to caller


    ; _UTrakOfstAccessIn -- Step the servo one track toward the spindle
    ; Args:
    ;   (none)
    ; Notes:
    ;   Does NOT ensure that you will attempt to seek past the crash stops!
    ;   Upon completion, the status register may not contain standard status.
    ;   Trashes D0-D1/A0.
_UTrakOfstAccessIn:
    LEA     s_UTrakOfstCmdServoIn,A0   ; Command template for inward step
    BRA.S   _UTrakOfstAccessCore     ; Jump to code that does the real work


    ; _UTrakOfstAccessOut -- Step the servo one track away from the spindle
    ; Args:
    ;   (none)
    ; Notes:
    ;   Does NOT ensure that you will attempt to seek past the crash stops!
    ;   Upon completion, the status register may not contain standard status.
    ;   Trashes D0-D1/A0.
_UTrakOfstAccessOut:
    LEA     s_UTrakOfstCmdServoOut,A0  ; Command template for outward step
    BRA.S   _UTrakOfstAccessCore     ; Jump to code that does the real work


    ; _UTrakOfstAccessStatus -- Query the servo for status/track offset directly
    ; Args:
    ;   (none)
    ; Notes:
    ;   Upon completion, the status register may not contain standard status.
    ;   Trashes D0-D1/A0.
_UTrakOfstAccessStatus:
    LEA     s_UTrakOfstCmdServoStatus,A0   ; Command template for status query
    ; Fall through to _UTrakOfstAccessCore...


    ; Not really a subroutine: does all the work of _UTrakOfstAccess(In/Out)
_UTrakOfstAccessCore:
    ; Tell the servo to shift as directed.
    MOVE.B  #6,D0                    ; The command is six bytes long
    JSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; This command reads no bytes
    CLR.W   zWIOWriteLen             ; This command writes no bytes
    JSR     WIDGETIO                 ; Issue command
    BNE     .er                      ; Error? Bail

    ; Busy-wait for the servo to be ready again.
    LEA     s_UTrakOfstCmdStatus,A0  ; Command template to get state registers
    MOVE.B  #3,D0                    ; This command is three bytes long
    JSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; This command reads no bytes
    CLR.W   zWIOWriteLen             ; This command writes no bytes
    MOVE.W  #$01FF,D1                ; Let's say we try it 512 times

.lp JSR     WIDGETIO                 ; Get state registers
    BNE.S   .er                      ; Error? Bail
    BTST.B  #5,(3+kStdStatus)        ; Is the servo ready yet?
    BNE     .ok                      ; Yes, off we go!
    DBRA    D1,.lp                   ; No, try again...

    ; We never did see the servo be ready again.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SERVO NOT READY AFTER COMMAND.'>
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark failure
    RTS                              ; Back to caller

    ; An error has occured; whinge.
.er mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO EXECUTE SERVO COMMAND.'>
    JSR     WIDGETPERROR             ; Print disk error string
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark failure
    RTS                              ; Back to caller

    ; The seek has been a success.
.ok ORI.B   #$04,CCR                 ; Set Z flag to mark success
    RTS                              ; Back to caller


    ; _UTrakOfstCheckTrack -- Check current track by reading a sector header
    ; Args:
    ;   (none)
    ; Notes:
    ;   Tries to read sectors on the track starting from 0 until a valid sector
    ;       is found, or we run out of sectors.
    ;   The current track is determined by the first valid sector found.
    ;   On return, the Z flag is set on success and clear on failure.
    ;   Trashes D0-D3/A0.
_UTrakOfstCheckTrack:
    ; Setup.
    CLR.B   D1                       ; We'll count sectors to try in D1

    ; Main loop: read each sector until we get a valid one, starting with 0
    ; First, issue a Diag_ReadHeader command and see if we got a good header.
.lp MOVE.B  #3,D0                    ; The command is three bytes long
    MOVE.B  D1,(2+z_UTrakOfstCmdDiagRdHdr)   ; Copy sector into command
    LEA     z_UTrakOfstCmdDiagRdHdr,A0   ; RAM location of the command template
    JSR     WIDGETCMD                ; Construct actual command in RAM
    MOVE.W  zBlockSize,zWIOReadLen   ; Read a whole block from the Widget...
    ADDI.W  #$0D,zWIOReadLen         ; ...plus a diagnostic header up front
    MOVE.L  #zSectorHeader,zWIOReadPtr   ; Read into this memory location
    CLR.W   zWIOWriteLen             ; This command writes no data
    JSR     WIDGETIO                 ; Issue command
    BNE.S   .nx                      ; Error? Try the next sector

    BTST.B  #2,kStdStatus            ; Was this sector header found?
    BNE.S   .nx                      ; No, try the next sector

    ; Next, see if the header has valid data.
    CLR.W   D2                       ; Load the first three bytes of the...
    LEA     zSectorHeader,A0         ; ...header into D2
    MOVE.B  (A0)+,D2
    LSL.L   #8,D2
    MOVE.B  (A0)+,D2
    MOVE.W  D2,D0                    ; (Copy first two bytes into D0 as we go...
    LSL.L   #8,D2                    ; ...just in case this header is good)
    MOVE.B  (A0)+,D2

    MOVE.W  #$FFFF,D3                ; Load the next three bytes into D3 and...
    MOVE.B  (A0)+,D3                 ; ...invert the whole lot, which should...
    LSL.L   #8,D3                    ; ...yield a long that's identical to...
    MOVE.B  (A0)+,D3                 ; ...the one we loaded into D2
    LSL.L   #8,D3
    MOVE.B  (A0),D3
    NOT.L   D3                       ; Here's the inversion

    CMP.L   D2,D3                    ; Are the two longs equal?
    BEQ.S   .cc                      ; Yes, see if this is the cylinder we want

    ; We saw no header or the header looked bad, so let's try the next sector
.nx ADDQ.B  #1,D1                    ; Increment sector
    CMP.B   zSectors,D1              ; Have we run out of sectors?
    BLO.S   .lp                      ; No, so try the next sector

    ; We ran out of sectors to try on this track.
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO FIND A VALID SECTOR.'>
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark failure
    RTS                              ; Back to caller

    ; We got a valid sector header, but is this track in range?
.cc MOVE.W  D0,z_UTrakOfstTrack      ; Save current track
    CMP.W   z_UTrakOfstTrackMin,D0   ; Is this track lower than the minimum?
    BLO.S   .oo                      ; Yes, skip to print error
    CMP.W   z_UTrakOfstTrackMax,D0   ; Is this track higher than the maximum?
    BHI.S   .oo                      ; Yes, skip to print error
    ORI.B   #$04,CCR                 ; Set Z flag to mark success
    RTS                              ; Back to caller

    ; The track was out of range, so give up.
.oo MOVE.W  D0,-(A7)                 ; Current track to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'POST-SERVOING TRACK '>,hx
    MOVE.W  z_UTrakOfstTrackMax,-(A7)  ; Track bounds to stack for printing
    MOVE.W  z_UTrakOfstTrackMin,-(A7)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<' IS OUT OF VALID RANGE '>,hx,<'..'>,hx
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark failure
    RTS                              ; Back to caller


    ; _UTrakOfstPrintDac -- Retrieve and print the current offset DAC value
    ; Args:
    ;   (none)
    ; Notes:
    ;   Issues a Set_AutoOffset command first so that the servo really does use
    ;       ATF.
    ;   Trashes D0/A0.
_UTrakOfstPrintDac:
    ; Force servo into auto-offset mode
    MOVE.B  #2,D0                    ; This command is two bytes long
    LEA     s_UTrakOfstCmdSetAutoOffset,A0   ; RAM location of command template
    JSR     WIDGETCMD                ; Construct actual command in RAM
    CLR.W   zWIOReadLen              ; There are no bytes to read
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    JSR     WIDGETIO                 ; Issue command
    BEQ.S   .gs                      ; Command sent successfuly, jump ahead

    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO ORDER AUTOOFFSET.'>
    JSR     WIDGETPERROR             ; Print disk error string
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark failure
    RTS                              ; Back to caller

    ; Get servo status long #1
.gs MOVE.B  #3,D0                    ; This command is three bytes long
    LEA     s_UTrakOfstCmdRdSrvoStatus,A0  ; RAM location of command template
    JSR     WIDGETCMD                ; Construct actual command in RAM
    MOVE.W  #4,zWIOReadLen           ; We will read four servo status bytes...
    MOVE.L  #zSectorTag,zWIOReadPtr  ; ...just to the usual buffer, why not
    CLR.W   zWIOWriteLen             ; There are no bytes to write
    JSR     WIDGETIO                 ; Issue command
    BEQ.S   .ok                      ; Read successful, jump ahead

    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'FAILED TO RETRIEVE SERVO STATUS.'>
    JSR     WIDGETPERROR             ; Print disk error string
    ANDI.B  #$FB,CCR                 ; Clear Z flag to mark failure
    RTS                              ; Back to caller

    ; Distill and print DAC value
.ok MOVE.B  (1+zSectorTag),D0        ; Offset DAC value to D0
    BSR     PRINTSERVOOFFSETDAC      ; Print the DAC value
    ORI.B   #$04,CCR                 ; Set Z flag to mark success
    RTS                              ; Back to caller


    PAGE
* NeoWidEx Track Offsets numerical data =====================
    SECTION kSecData


    PAGE
* NeoWidEx Track Offsets scratch data allocation ============
    SECTION kSecScratch

z_UTrakOfstCmdDiagRdHdr:
    DC.B    $10,$0A,$00              ; Diag_ReadHeader cmd. (last byte editable)

    DS.W    0
z_UTrakOfstTrack:                    ; Last known position of the heads
    DC.W    $0000
z_UTrakOfstTrackMin:                 ; New head position must be >= this
    DC.W    $0000
z_UTrakOfstTrackMax:                 ; New head position must be <= this
    DC.W    $0000

    PAGE
* NeoWidEx Track Offsets strings ============================
    SECTION kSecStrings

s_UTrakOfstCmdDataRecal:
    DC.B    $10,$05,$40              ; Send_Restore with data recalibration
s_UTrakOfstCmdRdSrvoStatus:
    DC.B    $10,$02,$01              ; Diag_Read_Servo_Status with $01 argument
s_UTrakOfstCmdServoIn:
    DC.B    $10,$03,$94,$01,$40,$80  ; Send_Servo_Command one track spindleward
s_UTrakOfstCmdServoOut:
    DC.B    $10,$03,$90,$01,$40,$80  ; Send_Servo_Command one track outward
s_UTrakOfstCmdServoStatus:
    DC.B    $10,$03,$00,$00,$20,$80  ; Send_Servo_Command get status/read offset
s_UTrakOfstCmdStatus:
    DC.B    $10,$01,$05              ; Read_Controller_Status w/$05 argument
s_UTrakOfstCmdSetAutoOffset:
    DC.B    $10,$0C                  ; Set_AutoOffset command

s_UTrakOfstForm:                     ; User form for asking about seeking
    DC.B    $0D,'A SEEK COMMAND TELLS THE COMING READ-HEADER COMMANDS WHICH '
    DC.B    $0D,'HEAD TO USE ON ALL TRACKS. SEEK SOMEWHERE FIRST? a',0

    DS.W    0
s_UTrakOfstFormPrompts:              ; Form prompts for asking about seeking
    DC.L    .p1
.p1 DC.B    'SEEK FIRST',0

    DS.W    0
s_UTrakOfstFormInitialVals:          ; Initial values for the form
    DC.L    $00000001

s_UTrakOfstHeader:
    DC.B    $0D,'       00 01 02 03  04 05 06 07  08 09 0A 0B  0C 0D 0E 0F',0


** (Back to the code section) **
    SECTION kSecCode


*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
