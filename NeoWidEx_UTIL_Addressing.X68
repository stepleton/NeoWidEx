*-----------------------------------------------------------
* Title      : NeoWidEx_UTIL_Addressing
* Written by : Tom Stepleton
* Date       : 1 April 2017
* Description:
*   Formatting and diagnostic tool for Widget drives,
*   inspired by the WidEx utility internal to Apple, and by
*   Patrick Schäfer's UsbWidEx hardware tool.
*   -- This file: utilities for calculating addresses
*      Equates from NeoWidEx_DEFS must be defined.
*      Macros from NeoWidEx_MACROS must be defined.
*      Resources from NeoWidEx_IO must be defined.
*      Resources from NeoWidEx_UI must be defined.
*      Resources from NeoWidEx_UI_FORMS must be defined.
*      Resources from NeoWidEx_WIDGETINFO must be defined.
*-----------------------------------------------------------


* NeoWidEx Addressing utility code =========================

    ; UTIL_Addressing -- UI for various disk address calculators
    ; Args:
    ;   (none)
    ; Notes:
    ;   A "sub-UI" with its own menu and everything.
    ;   Probably destroys most registers; depends on what user chooses to do.
    ;   Will not trash beyond D0-D5/A0-A4.
UTIL_Addressing:
    mMenuUi #sUtilAddrMenu,#dUtilAddrMenuHandlers
    RTS                              ; ...and go back to utilities menu


    ; To reduce code size, all menu options implemented in this file use these
    ; shared snippets to print something and return to the menu UI above.
_UAddr_CopyPrintResult:
    MOVE.L  D0,z_UAddrLba            ; Copy LBA to memory
    MOVE.L  D1,z_UAddrPba            ; Copy PBA to memory
    MOVE.W  D2,z_UAddrLCylinder      ; Copy LCHS cylinder to memory
    MOVE.B  D3,z_UAddrLHead          ; Copy LCHS head to memory
    MOVE.B  D4,z_UAddrLSector        ; Copy LCHS sector to memory
    MOVE.W  D2,z_UAddrPCylinder      ; Copy PCHS cylinder to memory
    MOVE.B  D3,z_UAddrPHead          ; Copy PCHS head to memory
    MOVE.B  D5,z_UAddrPSector        ; Copy LCHS sector to memory
_UAddr_PrintResult:
    MOVE.L  z_UAddrLba,-(A7)         ; LBA to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  LOGICAL BLOCK ADDRESS-'>,3x
    MOVE.L  z_UAddrPba,-(A7)         ; PBA to stack for printing
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,' PHYSICAL BLOCK ADDRESS-'>,3x
    MOVE.B  z_UAddrLSector,-(A7)
    MOVE.B  z_UAddrLHead,-(A7)
    MOVE.W  z_UAddrLCylinder,-(A7)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  LOGICAL CYLINDER-'>,hx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  HEAD-'>,hhx,<'  SECTOR-'>,hhx
    MOVE.B  z_UAddrPSector,-(A7)
    MOVE.B  z_UAddrPHead,-(A7)
    MOVE.W  z_UAddrPCylinder,-(A7)
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,' PHYSICAL CYLINDER-'>,hx
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<'  HEAD-'>,hhx,<'  SECTOR-'>,hhx
_UAddr_OkBye:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'DONE.'>
    RTS                              ; Back to caller
_UAddr_Nevermind:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'...ABORTED...'>
    RTS                              ; Back to caller


_UAddr_FromLba:
    MOVE.L  #s_UAddrBannerPrefix,-(A7)   ; Banner prefix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,<'LOGICAL BLOCK ADDRESS ---'>
    BSR     _UAddr_MaybeLoadIlMap_nobanr   ; Load interleave map if needed
    BSR     _UAddr_FillBounds        ; Set form bounds for this drive

    LEA     s_UAddrFormLba,A0        ; Prepare FORM args; address of template...
    LEA     s_UAddrFormLbaPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UAddrFormLbaInitVal,A2   ; ...address of initial values array...
    LEA     z_UAddrFormLbaBound,A3   ; ...and address of bounds array
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     _UAddr_Nevermind         ; Yes, jump to common quit code

    MOVE.L  zFieldValues,D0          ; Copy user input to D0
    BSR     _UAddr_LbaToPba          ; Compute LBA into PBA in D1
    BSR     _UAddr_PbaToLchs         ; Compute PBA to LCHS in D2-D4
    BSR     _UAddr_LsToPs            ; Compute LSector to PSector in D5
    BRA     _UAddr_CopyPrintResult   ; Save and print result; return to caller


_UAddr_FromPba:
    MOVE.L  #s_UAddrBannerPrefix,-(A7)   ; Banner prefix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,<'PHYSICAL BLOCK ADDRESS ---'>
    BSR     _UAddr_MaybeLoadIlMap_nobanr   ; Load interleave map if needed
    BSR     _UAddr_FillBounds        ; Set form bounds for this drive

    LEA     s_UAddrFormPba,A0        ; Prepare FORM args; address of template...
    LEA     s_UAddrFormPbaPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UAddrFormPbaInitVal,A2   ; ...address of initial values array...
    LEA     z_UAddrFormPbaBound,A3   ; ...and address of bounds array
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     _UAddr_Nevermind         ; Yes, jump to common quit code

    MOVE.L  zFieldValues,D1          ; Copy user input to D1
    BSR     _UAddr_PbaToLba          ; Copy PBA into LBA in D0
    BSR     _UAddr_PbaToLchs         ; Compute PBA to LCHS in D2-D4
    BSR     _UAddr_LsToPs            ; Compute LSector to PSector in D5
    BRA     _UAddr_CopyPrintResult   ; Save and print result; return to caller


_UAddr_FromLchs:
    MOVE.L  #s_UAddrBannerPrefix,-(A7)   ; Banner prefix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,<'LOGICAL C.H.S. ADDRESS ---'>
    BSR     _UAddr_MaybeLoadIlMap_nobanr   ; Load interleave map if needed
    BSR     _UAddr_FillBounds        ; Set form bounds for this drive

    LEA     s_UAddrFormLchs,A0       ; Prepare FORM args; address of template...
    LEA     s_UAddrFormChsPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UAddrFormLchsInitVals,A2   ; ...address of initial values array...
    LEA     z_UAddrFormChsBounds,A3  ; ...and address of bounds array
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     _UAddr_Nevermind         ; Yes, jump to common quit code

    MOVE.L  zFieldValues,D2          ; Copy user input cylinder to D2
    MOVE.L  (4+zFieldValues),D3      ; Copy user input head to D3
    MOVE.L  (8+zFieldValues),D4      ; Copy user input sector to D4
    BSR     _UAddr_LchsToPba         ; Compute LCHS to PBA in D1
    BSR     _UAddr_PbaToLba          ; Copy PBA into LBA in D0
    BSR     _UAddr_LsToPs            ; Compute LSector to PSector in D5
    BRA     _UAddr_CopyPrintResult   ; Save and print result; return to caller


_UAddr_FromPchs:
    MOVE.L  #s_UAddrBannerPrefix,-(A7)   ; Banner prefix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,s,<'PHYSICAL C.H.S. ADDRESS ---'>
    BSR     _UAddr_MaybeLoadIlMap_nobanr   ; Load interleave map if needed
    BSR     _UAddr_FillBounds        ; Set form bounds for this drive

    LEA     s_UAddrFormPchs,A0       ; Prepare FORM args; address of template...
    LEA     s_UAddrFormChsPrompts,A1   ; ...address of prompt pointer array...
    LEA     z_UAddrFormPchsInitVals,A2   ; ...address of initial values array...
    LEA     z_UAddrFormChsBounds,A3  ; ...and address of bounds array
    JSR     FORM                     ; Launch the form
    ; Back from form, did user want to cancel?
    TST.B   zFormIntent              ; Did the user cancel?
    BEQ     _UAddr_Nevermind         ; Yes, jump to common quit code

    MOVE.L  zFieldValues,D2          ; Copy user input cylinder to D2
    MOVE.L  (4+zFieldValues),D3      ; Copy user input head to D3
    MOVE.L  (8+zFieldValues),D5      ; Copy user input sector to D5
    BSR     _UAddr_PsToLs            ; Compute PSector to LSector in D4
    BSR     _UAddr_LchsToPba         ; Compute LCHS to PBA in D1
    BSR     _UAddr_PbaToLba          ; Copy PBA into LBA in D0
    BRA     _UAddr_CopyPrintResult   ; Save and print result; return to caller


    ; _UAddr_LbaToPba -- Convert a logical block address to a physical one.
    ; Args:
    ;   D0: Logical block address no larger than $FFFF
    ; Notes:
    ;   Only works on disks with $FFFF or fewer blocks. If you have a 40MB
    ;     Widget for some erason, the ADDX trick below won't work, and I'm not
    ;     certain that Dr. Schäfer's formula below would work either.
    ;   Resulting PBA is stored in D1.
    ;   "Trashes" D1.
_UAddr_LbaToPba:
    ROR.L   #8,D0                    ; Rotate D0 right 8 bits
    MOVE.W  D0,D1                    ; Copy D0 LSWord to D1 LSWord and MSWord...
    SWAP.W  D1                       ; ...both; this is the LBA / 256
    MOVE.W  D0,D1
    ROL.L   #8,D0                    ; Restore D0 to original state
    ; Add the LSByte of D0, which is the LBA % 256, to the LSByte of D1, which
    ; is (LBA / 256) % 256. We don't really care about the result, we just care
    ; that it sets the X bit if the sum is greater than 255.
    ADD.B   D0,D1                    ; Do that add, setting X
    CLR.W   D1                       ; Clear the result (leaves X alone)
    SWAP.W  D1                       ; Swap other copy of LBA / 256 to LSWord
    ; At this point D0 contains the LBA 00XXYYZZ, D1 contains 0000XXYY, and the
    ; X bit is set iff YY+ZZ > $FF. The following add gives us the PBA, whose
    ; formula as recovered by Dr. Patrick Schäfer is:
    ;   PBA = LBA + LBA/256 + int(LBA/256 + LBA%256 > 255)
    ADDX.L  D0,D1                    ; The magic add
    RTS                              ; Back to caller


    ; _UAddr_PbaToLba -- Convert a physical block address to a logical one.
    ; Args:
    ;   D1: Physical block address
    ; Notes:
    ;   Resulting LBA is stored in D0.
    ;   "Trashes" D0.
_UAddr_PbaToLba:
    MOVE.L  D1,D0                    ; Copy PBA to D0
    LSR.L   #8,D0                    ; Divide PBA in D0 by 256
    NEG.L   D0                       ; Negate the result
    ADD.L   D1,D0                    ; Add PBA to this negative offset
    RTS                              ; And that's all there is


    ; _UAddr_PbaToLchs -- Convert physical block address to a logical CHS addr.
    ; Args:
    ;   D1: Physical block address
    ; Notes:
    ;   D2, D3, and D4 contain the resulting logical cylinder, head, and sector
    ;       respectively. The MSWords of all values are clean ($0000).
    ;   "Trashes" D2-D4.
_UAddr_PbaToLchs:
    MOVE.L  D1,D3                    ; Copy PBA to D3
    CLR.W   D2                       ; Clear D2 LSWord and copy...
    MOVE.B  z_UAddrHeads,D2          ; ...the number of heads there
    CLR.L   D4                       ; Clear ALL of D4 and copy...
    MOVE.B  z_UAddrSectors,D4        ; ...the number of sectors there
    MULU    D4,D2                    ; D2 contains 0000:heads*sectors
    DIVU    D2,D3                    ; D3 contains "remainder":cylinder
    MOVE.W  D3,D2                    ; D2 contains 0000:cylinder
    CLR.W   D3                       ; D3 contains "remainder":0000
    SWAP    D3                       ; D3 contains 0000:"remainder"
    DIVU    D4,D3                    ; D3 contains sector:head
    SWAP    D3                       ; D3 contains head:sector
    MOVE.W  D3,D4                    ; D4 contains 0000:sector
    CLR.W   D3                       ; D3 contains head:0000
    SWAP    D3                       ; D3 contains 0000:head
    RTS                              ; Back to caller


    ; _UAddr_LchsToPba -- Convert logical CHS address to a physical block addr.
    ; Args:
    ;   D2: Logical cylinder, as a word
    ;   D3: Logical head, as a word
    ;   D4: Logical sector, as a word
    ; Notes:
    ;   D1 will contain the corresponding physical address.
    ;   "Trashes" D1.
_UAddr_LchsToPba:
    MOVE.W  D0,-(A7)                 ; Save D0 on stack
    MOVE.W  D2,D1                    ; Copy cylinder to D1
    CLR.W   D0                       ; Clear D0 LSWord in preparation for...
    MOVE.B  z_UAddrHeads,D0          ; ...receiving the number of heads
    MULU    D0,D1                    ; Multiply cylinder by number of heads
    MOVE.B  z_UAddrSectors,D0        ; Copy number of sectors to D0
    MULU    D0,D1                    ; Multiply cylinder*heads by # of sectors
    MOVE.L  D1,-(A7)                 ; Temporarily store on stack
    MOVE.W  D3,D1                    ; Copy head to D1
    MULU    D0,D1                    ; Multiply by number of sectors per head
    ADD.W   D4,D1                    ; Add sector
    ADD.L   (A7)+,D1                 ; Add in sector count from cylinders
    MOVE.W  (A7)+,D0                 ; Restore D0
    RTS                              ; Back to caller


    ; _UAddr_LsToPs -- Convert logical sector to physical sector
    ; Args:
    ;   D4: Logical sector; should be a word, not just a byte.
    ; Notes:
    ;   D5 will contain the resulting physical sector. Its MSWord will be
    ;       clean ($0000).
    ;   "Trashes" D5/A0.
_UAddr_LsToPs:
    LEA     z_UAddrIlMap,A0          ; Point A0 at our interleave map
    CLR.L   D5                       ; Clear D5
    MOVE.B  0(A0,D4.L),D5            ; Use D4 to index into interleave map
    RTS                              ; Back to caller


    ; _UAddr_PsToLs -- Convert physical sector to logical sector
    ; Args:
    ;   D5: Physical sector
    ; Notes:
    ;   D4 will contain the resulting logical sector. Its MSWord will be
    ;       clean ($0000).
    ;   Will do unpredictable things if D5 contains a value not in the
    ;       interleave map.
    ;   "Trashes" D5/A0.
_UAddr_PsToLs:
    CLR.L   D4                       ; Clear D4
    LEA     z_UAddrIlMap,A0          ; Point A0 at our interleave map
.lp CMP.B   (A0)+,D5                 ; Is this the logical sector we're seeking?
    BEQ.S   .rt                      ; Yes, jump to return
    ADDQ.B  #1,D4                    ; No, get ready to try the next map entry
    BRA.S   .lp                      ; And loop around to do just that
.rt RTS                              ; Back to caller


    ; _UAddr_FillBounds -- Fill form bounds based on Widget parameters
    ; Args:
    ;   (none)
    ; Notes:
    ;   Requires that WINFOMAYBE has been called (a side effect of all
    ;       interleave map loading routines).
    ;   Trashes D0-D1.
_UAddr_FillBounds:
    MOVE.L  z_UAddrNumBlocks,D0      ; Number of blocks to D0
    SUBQ.L  #1,D0                    ; Less one for upper bound
    MOVE.L  D0,z_UAddrFormLbaBound   ; Copy into bound storage

    BSR     _UAddr_LbaToPba          ; Derive PBA for largest LBA
    MOVE.L  D1,z_UAddrFormPbaBound   ; Copy into bound storage

    CLR.L   D0                       ; Clear D0 in anticipation of...
    MOVE.W  z_UAddrCylinders,D0      ; ...getting the number of sectors
    SUBQ.W  #1,D0                    ; Less one for upper bound
    MOVE.L  D0,z_UAddrFormChsBounds  ; Copy into bound storage

    CLR.W   D0                       ; Clear D0 LSWord in anticipation of...
    MOVE.B  z_UAddrHeads,D0          ; ...getting the number of heads
    SUBQ.B  #1,D0                    ; Less one for upper bound
    MOVE.L  D0,(4+z_UAddrFormChsBounds)  ; Copy into bound storage

    MOVE.B  z_UAddrSectors,D0        ; ...getting the number of sectors
    SUBQ.B  #1,D0                    ; Less one for upper bound
    MOVE.L  D0,(8+z_UAddrFormChsBounds)  ; Copy into bound storage

    RTS                              ; Back to caller


    ; _UAddr_LoadIlMap -- Load and check the interleave map, with narration.
    ; Args:
    ;   (none)
    ; Notes:
    ;   Also has the side-effects of calling WINFOMAYBE.
    ;   Trashes D0-D4/A0-A3.
_UAddr_LoadIlMap:
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'  --- RELOAD INTERLEAVE MAP ---'>
    BSR.B   _UAddr_LoadIlMap_nobanner  ; Helper that actually loads the IL map
    BRA     _UAddr_OkBye             ; Say "Done" and return to caller


    ; _UAddr_MaybeLoadIlMap_nobanr -- Load/check I.L. map if not done yet.
    ; Args:
    ;   (none)
    ; Notes:
    ;   Also has the side-effects of calling WINFOMAYBE.
    ;   Trashes D0-D4/A0-A3.
_UAddr_MaybeLoadIlMap_nobanr:
    TST.B   z_UAddrHaveIlMap         ; Is the interleave map loaded already?
    BNE.S   .rt                      ; Yes, skip to exit
    BSR.B   _UAddr_LoadIlMap_nobanner  ; No, load it
.rt RTS                              ; Back to caller


    ; _UAddr_LoadIlMap_nobanner -- Actually load and check the interleave map.
    ; Args:
    ;   (none)
    ; Notes:
    ;   Also has the side-effects of calling WINFOMAYBE.
    ;   Trashes D0-D4/A0-A3.
_UAddr_LoadIlMap_nobanner:
    JSR     WINFOMAYBE               ; Run WIDGETINFO if it hasn't been run yet
    TST.B   zIsWidgety               ; Do we have a widget?
    BNE.S   .go                      ; Yes, go check and copy its information
    MOVE.L  #s_UAddrUntrustworthy,-(A7)   ; Warning suffix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'NOT A WIDGET--ALL'>,s
    RTS                              ; Return to caller in defeat

    ; Copy Widgety size and geometry information locally.
.go MOVE.L  zNumBlocks,z_UAddrNumBlocks
    MOVE.W  zCylinders,z_UAddrCylinders
    MOVE.W  zHeads,z_UAddrHeads
    MOVE.W  zSectors,z_UAddrSectors

    ; Attempt to load spare table.
    MOVE.L  #$00FFFFFE,D1            ; Sector ID for the Widget spare table
    JSR     SECTOR                   ; Read the spare table
    BCC     .pr                      ; Jump to parse spare table structure
    MOVE.L  #s_UAddrUntrustworthy,-(A7)   ; Warning suffix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'SPARE TABLE ERROR--PHYSICAL CHS'>,s
    RTS                              ; Return to caller in defeat

    ; Find and validate interleave map information. We use a crummy N^2
    ; algorithm to make sure the map contains only one of each number in
    ; 0..zSectors-1, but zSectors is never large, so it shouldn't matter much.
.pr MOVEA.L #($1C0+zSectorTag),A0    ; Interleave map address to A0
    ; In these nesting loops, D0 will be the entry we're looking for in the map,
    ; and D1 will index the map itself.
    CLR.W   D0                       ; Prepare D0 word to hold:
    MOVE.B  zSectors,D0              ; The number of sectors per track
    SUBQ.B  #1,D0                    ; Subtract 1 to make it a loop counter
.lo CLR.W   D1                       ;   Prepare D1 word to hold:
    MOVE.B  zSectors,D1              ;   The number of sectors per track
    SUBQ.B  #1,D1                    ;   Subtract 1 to make it a loop counter

.li CMP.B   0(A0,D1.W),D0            ;     Did we find the entry we're seeking?
    BEQ     .nx                      ;     Yes, skip ahead, find the next entry
    DBRA    D1,.li                   ;     No, keep iterating through entries

    MOVE.L  #s_UAddrUntrustworthy,-(A7)  ; Warning suffix on stack to print
    mPrint  kCrtRow,kCrtCol,#kFirstCol,<$0D,'BAD INTERLEAVE MAP--PHYS. CHS'>,s
    RTS                              ;   Return to caller in defeat
.nx DBRA    D0,.lo                   ;   On to next iteration of outer loop

    ; Looks like the interleave map is just fine. Make a local copy.
    CLR.W   D0                       ; Prepare D0 word to hold:
    MOVE.B  zSectors,D0              ; The number of sectors per track
    mMemCpy A0,#z_UAddrIlMap,D0      ; Copy the interleave map
    MOVE.B  #$FF,z_UAddrHaveIlMap    ; Affirm that we've now loaded the map
    RTS                              ; Back to caller in triumph!


    PAGE
* NeoWidEx Addressing numerical data ========================
    SECTION kSecData

    DS.W    0                        ; Force even alignment for what follows
dUtilAddrMenuHandlers:               ; Addresses of handlers for each of the...
    DC.L    (1+GOBACK)               ; ...menu items in sUtilAddrMenu
    DC.L    _UAddr_FromLba           ; 1+ means don't print a newline before...
    DC.L    _UAddr_FromPba           ; ...calling this handler; the LSBit...
    DC.L    _UAddr_FromLchs          ; ...will be cleared before the call
    DC.L    _UAddr_FromPchs
    DC.L    SPAREPRINT
    DC.L    _UAddr_LoadIlMap
    DC.L    $00000000                ; Null terminator


    PAGE
* NeoWidEx Addressing utility scratch data allocation ======
    SECTION kSecScratch

z_UAddrHaveIlMap:                    ; Have we loaded the interleave map yet?
    DC.B    $00
z_UAddrIlMap:                        ; Our copy of the drive's interleave map
    DC.B    $00,$0C,$05,$11,$0A,$03,$0F,$08  ; Initialised with the default
    DC.B    $01,$0D,$06,$12,$0B,$04,$10,$09  ; Widget interleave map
    DC.B    $02,$0E,$07
    ; And just in case anyone gets their hands on a 20MB or 40MB Widget:
    DC.B    $13,$14,$15,$16,$17,$18,$19,$1A
    DC.B    $1B,$1C,$1D,$1E,$1F,$20,$21,$22
    DC.B    $23,$24,$25

    DS.W    0                        ; Word alignment for what follows
z_UAddrFormLbaBound:                 ; Form bound for logical block addresses
    DC.L    $00000000
z_UAddrFormPbaBound:                 ; Form bound for physical block addresses
    DC.L    $00000000
z_UAddrFormChsBounds:                ; Form bounds for both kinds of CHS addr.s
    DC.L    $00000000                ; Cylinder
    DC.L    $00000000                ; Head
    DC.L    $00000000                ; Sector

    ; The following locations do double-duty as initial values for forms
    ; and as storage for entered/computed address data. Recall that form values
    ; are always longs, but symbols have been interposed within the longs for
    ; convenient access to non-long quantities.

z_UAddrLba:                          ; Last computed logical block address
z_UAddrFormLbaInitVal:               ; Form init.val. for logical block addr.s
    DC.L    $00000000
z_UAddrPba:                          ; Last computed physical block address
z_UAddrFormPbaInitVal:               ; Form init.val. for physical block addr.s
    DC.L    $00000000

z_UAddrFormLchsInitVals:             ; Form init.val.s for logical CHS addr.s
    DC.W    $0000
z_UAddrLCylinder:                    ; Last computed logical cylinder
    DC.W    $0000
    DC.B    $00,$00,$00              ; Longword padding bytes for:
z_UAddrLHead:                        ; Last computed logical head
    DC.B    $00
    DC.B    $00,$00,$00              ; Longword padding bytes for:
z_UAddrLSector:                      ; Last compued logical sector
    DC.B    $00

z_UAddrFormPchsInitVals:             ; Form init.val.s for physical CHS addr.s
    DC.W    $0000
z_UAddrPCylinder:                    ; Last computed physical cylinder
    DC.W    $0000
    DC.B    $00,$00,$00              ; Longword padding bytes for:
z_UAddrPHead:                        ; Last computed physical head
    DC.B    $00
    DC.B    $00,$00,$00              ; Longword padding bytes for:
z_UAddrPSector:                      ; Last compued physical sector
    DC.B    $00

    ; We keep local copies of the drive size and the cylinder/head/sector
    ; geometry---this allows us to do calculations for a 10MB Widget on machines
    ; that have no Widget at all. On machines that do have Widgets, the real
    ; values will be copied here.

z_UAddrNumBlocks:
    DC.L    $4C00
z_UAddrCylinders:
    DC.W    $202
z_UAddrHeads:
    DC.B    $02
z_UAddrSectors:
    DC.B    $13

    PAGE
* NeoWidEx Addressing utility strings =======================
    SECTION kSecStrings

sUtilAddrMenu:
    DC.B    'ADDRESS TOOL',0         ; Menu title
    DC.B    'GO BACK...    1',0
    DC.B    'FROM LOG.BA   2',0
    DC.B    'FROM PHYS.BA  3',0
    DC.B    'FROM LOG.CHS  4',0
    DC.B    'FROM PHYS.CHS 5',0
    DC.B    'SPARE TABLE   6',0
    DC.B    'RELOAD IL MAP 7',0
    DC.B    0                        ; End of menu
    DC.B    $01                      ; Divider after item 1
    DC.B    $05                      ; Divider after item 5
    DC.B    0                        ; No more dividers

s_UAddrBannerPrefix:
    DC.B    $0D,'  --- CALCULATE ADDRESSES FROM ',0

s_UAddrUntrustworthy:
    DC.B    ' CALCULATIONS ARE UNTRUSTWORTHY.',0

s_UAddrFormLba:
    DC.B    $0D,'FROM LOGICAL BLOCK ADDRESS-ac____',0

    DS.W    0
s_UAddrFormLbaPrompts:
    DC.L    .p1
.p1 DC.B    'LBA',0

s_UAddrFormPba:
    DC.B    $0D,'FROM PHYSICAL BLOCK ADDRESS-ac____',0

    DS.W    0
s_UAddrFormPbaPrompts:
    DC.L    .p1
.p1 DC.B    'PBA',0

s_UAddrFormLchs:
    DC.B    $0D,'FROM LOGICAL CYLINDER-ab__  HEAD-ba  SECTOR-ca',0

s_UAddrFormPchs:
    DC.B    $0D,'FROM PHYSICAL CYLINDER-ab__  HEAD-ba  SECTOR-ca',0

    DS.W    0
s_UAddrFormChsPrompts:
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
