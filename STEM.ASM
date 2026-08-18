;****************************************************
; stem.asm
; Simple file manager
; This is written for use with CP/M
;
; Usage:
; assemble with 'asm':  asm stem
; load: load stem
;
;****************************************************
; subroutines PCHAR, PNIB, PHEX, and CRLF are taken
; from the CP/M manual and modified a bit.
;****************************************************
;
;****************************************************
;
; Copyright 2026 M.Brugman
;
; Permission is hereby granted, free of charge, to any person
; obtaining a copy of this software and associated
; documentation files (the “Software”), to deal in the
; Software without restriction, including without limitation
; the rights to use, copy, modify, merge, publish, distribute,
; sublicense, and/or sell copies of the Software, and to permit
; persons to whom the Software is furnished to do so,
; subject to the following conditions:
;
; The above copyright notice and this permission notice shall
; be included in all copies or substantial portions
; of the Software.
;
; THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY
; KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
; WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
; PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
; OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
; OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
; OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
;****************************************************

; Most of the following is just boiler plate, common
; definitions, etc.

;****************************************************
; Entry point for FDOS, BIOS, CP/M system calls
;****************************************************
sys     equ     5               ; entry point for system (dos)

;***************************************************
; syscall functions
; Generally, drop this into C and do a call sys to
; do a syscall.  Some funcs require more stuffs.
;***************************************************
reset   equ     0               ; reset (reload CP/M)
conin	equ     1               ; console input (blocking)
conout	equ     2               ; console output function
rdinp	equ     3               ; paper tape reader input
pnchout	equ     4               ; paper tape puncher
lstout	equ     5               ; list output (printer)
dirio	equ     6               ; direct console I/O
getio	equ     7               ; get IOBYTE
setio	equ     8               ; set IOBYTE
strout	equ     9               ; string output function
rdcbuf	equ     10              ; read console buffer
constat equ     11              ; get console status
version	equ     12              ; get CP/M version
rstdsk	equ     13              ; reset disk system
seldsk	equ     14              ; select disk
fopen   equ     15              ; open file
fclose  equ     16              ; close file
srchf   equ     17              ; search first file
srchn   equ     18              ; search next file
fdel    equ     19              ; delete file
rdseq   equ     20              ; read sequential
wrseq   equ     21              ; write sequential
fmake   equ     22              ; make file
fname   equ     23              ; rename file
lvect   equ     24              ; return login vector
getdsk	equ     25              ; return current disk
setdma	equ     26              ; set DMA address
alloc	equ     27              ; get address (alloc)
pdsk	equ     28              ; protect disk
getrov	equ     29              ; get R/O vector
setatt	equ     30              ; set file attributes
gdprarm	equ     31              ; get address (disk params)
gsuer	equ     32              ; get/set user code
rdrnd	equ     33              ; read random
wrrnd	equ     34              ; write random
fsize	equ     35              ; compute file size
frset	equ     36              ; set random record
rstdrv	equ     37              ; reset drive
wrtzer	equ     40              ; write random with zero fill

;****************************************************
; CP/M constants/values/addresses
;****************************************************
fcb1    equ     005ch           ; first cmdline fcb
dma1    equ     0080h           ; first DMA area 128 bytes

;*****************************************************
;* handy constants
;*****************************************************
CR      equ     0dh             ; carriage return
LF      equ     0ah             ; line feed
fcblen  equ     36              ; byte size of File Control Block
fnbflen equ     452             ; length of filename buffer
fnlen   equ     11              ; length of 8.3 filename (8+3)
finflen equ     15              ; length of file info struct (8+3 name + 4 bytes)
dspace  equ     17              ; spacing between filenames in list
dsmax   equ     77              ; when to wrap filename list
strtrow equ     3               ; first row of file list
maxfls  equ     70              ; max files in buffer
tagcnt  equ     maxfls/8+1      ; number of tag bytes in array

;****************************************************
; Start of actual program code here
; .org 100h - TPA area starts at 0x0100
;****************************************************
        org     0100h           ; entry point at 100 hex (TPA area)
        lxi     b,canary        ; point to fixed canary value
        lxi     d,stkcny        ; point to last 4 bytes under stack
        ldax    b               ; read fixed byte
        stax    d               ; write to canary
        inx     b               ; increment
        inx     d               ; increment
        ldax    b               ; read fixed byte
        stax    d               ; write to canary
        inx     b               ; increment
        inx     d               ; increment
        ldax    b               ; read fixed byte
        stax    d               ; write to canary
        inx     b               ; increment
        inx     d               ; increment
        ldax    b               ; read fixed byte
        stax    d               ; write to canary
        lxi     h,0             ; zero H/L register pair
        dad     sp              ; get stack pointer from CCP to H/L
        shld    orgstk          ; save original stack pointer to memory
        lxi     sp,newstk       ; set stack pointer to our new stack
        mvi     c,gdprarm       ; syscall code for get DPH address
        call    sys             ; do the syscall
        shld    dpbase          ; save it for later
        mvi     d,5             ; flower box at line 5
        mvi     e,16            ; flower box at column 16
        mvi     a,8             ; 8 blank lines in box
        call    flower          ; print a flower box
        mvi     d,7             ; line 7
        mvi     e,35            ; column 35
        call    setcur          ; move cursor
        mvi     c,strout        ; print string func
        lxi     d,stemver       ; version string
        call    sys             ; print it
        mvi     d,8             ; line 8
        mvi     e,27            ; column 27
        call    setcur          ; move cursor
        mvi     c,strout        ; load reg C with command to print string
        lxi     d,welcom1       ; point to address of welcome #1 string
        call    sys             ; call the system function to print string
        mvi     d,9             ; move cursor to line 9
        mvi     e,25            ; move cursor to column 25
        call    setcur          ; move cursor
        mvi     c,strout        ; load reg C with command to print string
        lxi     d,welcom2       ; point to address of welcome #2 string
        call    sys             ; call the system function to print string
        mvi     d,11            ; move cursor to line 11
        mvi     e,22            ; move cursor to column 22
        call    setcur          ; move cursor
        mvi     c,strout        ; load reg C with command to print string
        lxi     d,welcom3       ; point to address of welcome #3 string
        call    sys             ; call the system function to print string
        mvi     c,conin         ; wait for keypress
        call    sys             ; waiting, key will be in A

usrlp0:
        call    clrtags         ; clear all file tags
        call    listfls         ; load and list files
uinext:                         ; user UI interaction loop
        call    stkchk          ; check stack integrity
        ora     a               ; stack is OK
        jz      cont            ; continue on
        call    crlf            ; newline
        lxi     d,errcan        ; stack error message
        mvi     c,strout        ; print it
        call    sys             ; print it
        jmp     cleanup         ; get outta here

cont:
        ;call    prnvars         ; print debug stuffs on line 2
        call    prnui           ; print user interface info & menu
        call    cin2uppr        ; get user input (force to uppercase)
        cpi     'N'             ; Next file?
        jnz     uiprev          ; nope, check for previous file
        lda     flsel           ; get selected file
        mov     b,a             ; save it in B
        lda     fcount          ; get total filecount
        dcr     a               ; decrement count for good compare
        cmp     b               ; compare to current file
        jz      uinxt2          ; are we at the last file?
        lda     flsel           ; increment selected
        inr     a               ; file indicator
        sta     flsel           ; save it
        jmp     uinext          ; next UI interaction
uinxt2:
        lxi     h,flsel         ; wrap selected file variable
        mvi     m,0             ; back to file zero
        jmp     uinext          ; next UI interaction
uiprev:
        cpi     'P'             ; "P" for previous file
        jnz     uitag           ; nope, check for tag/untag
        lda     flsel           ; get current selected file
        ora     a               ; are we already at zero?
        jz      uiprv2          ; yup, go set it to max count
        dcr     a               ; decrement selection
        sta     flsel           ; and save it
        jmp     uinext          ; next UI interaction
uiprv2:
        lda     fcount          ; get filecount
        dcr     a               ; zero-based count
        sta     flsel           ; save it as selection
        jmp     uinext          ; next UI interaction
uitag:
        cpi     ' '             ; do tag/untag?
        jnz     uidel           ; nope, check for delete
        lda     flsel           ; get currently selected file number
        mov     l,a             ; save it to L
        mvi     d,strtrow       ; first line to use
        mvi     e,2             ; start in column 2
        cpi     0               ; inital check
tag1:
        jz      tag3            ; yup
        mov     a,e             ; get column start
        adi     dspace          ; bump it up for next set of files
        mov     e,a             ; save it for now
        cpi     dsmax           ; anything greater than 77 would be column 6
        jm      tag2            ; nope, this is column 5 or less
        mvi     e,2             ; start over at column 2
        inr     d               ; next row
tag2:
        dcr     l               ; decrement selected count, sets Z flag
        jmp     tag1
tag3:
        call    setcur          ; move cursor to that spot
        lda     flsel           ; get selected file
        call    gettag          ; is this one already set?
        jz      tag4            ; flag is not set - go set it
        lda     flsel           ; gotta get the selected file again
        call    clrtag          ; clear the flag
        mvi     a,' '           ; unmark char in UI
        jmp     tag5            ; go print it
tag4:
        lda     flsel           ; get file selection again
        call    settag          ; set that flag
        mvi     a,'X'           ; mark char in UI
tag5:
        call    pchar           ; print it
        jmp     uinext          ; next UI interaction

uidel:
        cpi     'D'             ; Delete file(s)?
        jnz     uitype          ; Nope, go check for type contents
        call    cnttags         ; get count of tagged files
        ora     a               ; is it zero?
        jnz     del1            ; no? go do tagged stuffs
dels1:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 4 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,26            ; column 26
        call    setcur          ; put cursor there
        lxi     d,delmsg        ; "Delete file"... message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        call    prnname         ; print file name
        lxi     d,uichyn        ; Yes/No prompt
        mvi     c,strout        ; print
        call    sys             ; syscall
        call    cin2uppr        ; get user choice
        cpi     'N'             ; user said nope
        jz      usrlp0          ; redraw whole display
        cpi     'Y'             ; user said yup
        jz      dels2           ; oboy, here we go
        jmp     dels1           ; something else, prompt again
dels2:
        call    bldfcb          ; set up a file control block
        lxi     d,fcb1          ; point to the FCB1
        mvi     c,fdel          ; syscall number to delete file
        call    sys             ; do the syscall
del1:
        jmp     usrlp0

uitype:
        cpi     'T'
        jnz     uiren

uiren:
        cpi     'R'
        jnz     uihelp

uihelp:
        cpi     'H'
        jnz     uilog
        mvi     d,16
        mvi     e,1
        call    setcur
uihlp1:
        call    itertgs
        cpi     0
        jnz     uihlp2
        call    prnname
        mvi     a,' '
        call    pchar
        jmp     uihlp1
uihlp2:
        mvi     c,conin
        call    sys
        jmp     usrlp0

uilog:
        cpi     'L'             ; Log disk?
        jnz     uiexit          ; Nope - check for exit
uilog1:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 4 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,26            ; column 26
        call    setcur          ; put cursor there
        lxi     d,logmsg        ; "select disk" message
        mvi     c,strout        ; print
        call    sys             ; syscall
        call    cin2uppr        ; get user input
        cpi     'A'             ; lowest drive
        jm      uilog1          ; bad input
        cpi     'Q'             ; highest drive
        jp      uilog1          ; bad input
        sta     drvtmp          ; save drive letter in temp
        sui     'A'             ; move from 'A' to 0, etc
        mov     e,a             ; move to D for syscall
        call    isdskok         ; check to see if disk is online
        jz      uilog2          ; it is not!
        mvi     c,seldsk        ; select disk
        call    sys             ; syscall
        jmp     usrlp0          ;
uilog2:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 4 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,19            ; column 26
        call    setcur          ; put cursor there
        lxi     d,logerr        ; error message
        mvi     c,strout        ; print it
        call    sys             ; do the syscall
        mvi     d,7             ; line 7
        mvi     e,24            ; move to placeholder for drive letter
        call    setcur          ; set cursor there
        lda     drvtmp          ; get the drive letter from user input
        call    pchar           ; drop it into message
        mvi     c,conin         ; wait for input
        call    sys             ; syscall
        jmp     usrlp0          ; go back to file list

uiexit:
        cpi     'X'
        jz      cleanup
        jmp     uinext          ; next UI interaction


;*************************************************
; Final clean up before exit
; restore original stack pointer, etc.
;*************************************************
cleanup:
        lhld    orgstk          ; load original stack pointer to H/L pair
        sphl                    ; set stack pointer from H/L pair
        ret                     ; back to CCP, end of program

;*************************************************
; Debug/Test subroutines
;*************************************************
;
; prnvars
prnvars:
        push    h               ;
        push    d               ;
        push    b               ;
        push    psw             ;
        mvi     d,2             ;
        mvi     e,1             ;
        call    rstline         ;
        lda     flsel           ;
        mov     l,a             ;
        call    prn8            ;
        mvi     a,' '           ;
        call    pchar           ;
        lxi     h,tags          ;
        mvi     c,tagcnt        ;
dbgl1:
        dcr     c               ;
        jz      dbgl2           ;
        mov     a,m             ;
        call    phex            ;
        mvi     a,' '           ;
        call    pchar           ;
        inx     h               ;
        jmp     dbgl1           ;
dbgl2:
        pop     psw             ;
        pop     b               ;
        pop     d               ;
        pop     h               ;
        ret


;*************************************************
; Start of subroutines
;*************************************************
;
;stkchk
; Check integrity of stack (look for a blown stack)
; OUT:
;       A-255 stack was blown
stkchk:
        lxi     b,canary        ; get fixed value address
        lxi     h,stkcny        ; get last 4 bytes under stack
        ldax    b               ; get byte
        cmp     m               ; compare
        jnz     stkblwn         ; stack is corrupt
        inx     b               ; next byte
        inx     h               ; next byte
        ldax    b               ; get byte
        cmp     m               ; compare
        jnz     stkblwn         ; stack is corrupt
        inx     b               ; next byte
        inx     h               ; next byte
        ldax    b               ; get byte
        cmp     m               ; compare
        jnz     stkblwn         ; stack is corrupt
        inx     b               ; next byte
        inx     h               ; next byte
        ldax    b               ; get byte
        cmp     m               ; compare
        jnz     stkblwn         ; stack is corrupt
        mvi     a,0             ; stack is good
        ret                     ; all done
stkblwn:
        mvi     a,0ffh          ; set flag
        ret

; isdskok
; Check if selected disk is online
; IN:
;       A - disk number (A=0, B=1, etc)
; OUT:
;       A - zero means disk offline
isdskok:
        push    b               ;
        push    h               ;
        push    psw             ; syscall will stomp A
        mvi     c,lvect         ; get the "log in vector", a bitmap of OK drives
        call    sys             ; do the syscall
        pop     psw             ; restore A
        cpi     8               ; are we talking drives 0 to 7?
        jm      dskoklo         ; low byte
        mov     b,h             ; selected drive is in the H register
        sbi     8               ; subtract 8 from A
        jmp     isdsk1
dskoklo:
        mov     b,l
isdsk1:
        mov     c,a             ; get inx into C
        ora     a               ; initial check for zero
        mvi     a,1             ; set first bit
isdsk2:
        jz      isdsk3          ; done shifting
        rlc                     ; shift
        dcr     c               ; sets zero flag
        jmp     isdsk2          ; shift again
isdsk3:
        ana     b               ; check shifted bit against vector byte
        pop     h               ;
        pop     b               ;
        ret

; pchar
; print a character to console out
; IN:
;	reg A - character to print
; all registers preserved
pchar:
        push    h               ; save registers that we'll
        push    d               ; be using
        push    b
        mvi     c,conout        ; CP/M function for char out
        mov     e,a             ; char needs to be in Reg e
        call    sys             ; call CP/M to print
        pop     b               ;
        pop     d               ; restore registers
        pop     h               ; that were used
        ret

;
; crlf
; output carriage return/linefeed to console out
crlf:
        push    psw             ; save A reg
        mvi     a,CR            ; set A to carriage return
        call    pchar           ; go print it
        mvi     a,LF            ; set A to linefeed
        call    pchar           ; go print it
        pop     psw             ; restore A reg
        ret

;
; pnib
; Print low nibble in register A
; register A stomped
pnib:
        ani     0fh             ; mask off upper nibble
        cpi     10              ; value of low nibble under 10?
        jnc     pnib10          ; nope, it's hex a-f, go there
        adi     '0'             ; add 30h to value (for ascii 0-9)
        jmp     pnibprn         ; print it out
pnib10:
        adi     'a'-10          ; hex a-f, add ascii 'A' offset
pnibprn:
        call    pchar           ; print
        ret

;
; phex
; print hex (2 chars)
; IN char to print in register A
phex:
        push    psw             ; save A register
        rrc                     ;
        rrc                     ; start with upper nibble
        rrc                     ; so rotate bits right
        rrc                     ; 4 bits
        call    pnib            ; print this upper nibble
        pop     psw             ; restore A register
        push    psw             ; save it again
        call    pnib            ; print lower nibble
        pop     psw             ; final restore before return
        ret

; cin2uppr
; Console in to uppercase - do a conin, if lowercase alpha, shift to
; upper, otherwise leave as is
; RETURNS:
;       byte in A
cin2uppr:
        push    b               ; save B/C pair
        mvi     c,conin         ; code for console in
        call    sys             ; do the syscall
        cpi     'a'             ; is char greater or equal to lowercase a?
        jm      c2udone         ; less than lower case a, return whatever this is
        cpi     'z'+1           ; is char greater than lowercase z?
        jp      c2udone         ; sure it, just return it
        ani     0dfh            ; mask off bit 5 (that's the difference between A and a, etc)
c2udone:
        pop     b               ; restore B/C
        ret                     ; and get outta here

;
; prn16
; Print 16-bit binary value as decimal
; IN:
;       H/L - value to print
; all registers preserved
;
prn16:
        push    h               ; save registers
        push    b
        push    d
        mvi     b, 0            ; Used as a flag to skip printing leading zeroes
        lxi     d,-10000        ; ten thousands place
        call    pdec            ; go print it
        lxi     d,-1000         ; tousands place
        call    pdec            ; go print it
        lxi     d,-100          ; hundreds place
        call    pdec            ; go print it
        lxi     d,-10           ; tens place
        call    pdec            ; go print it
        mov     a,l             ; get remaining ones place
        adi     '0'             ; offset for ascii
        call    pchar           ; and print it
        pop     d               ; restore registers
        pop     b
        pop     h
        ret

;
; prn8
; Print 8-bit binary value as decimal
; IN:
;       L - value to print
; all registers preserved
;
prn8:
        push    h               ; save registers
        push    b
        push    d
        mvi     h,0             ; zero upper byte
        mov     a,l             ; initial check for zero
        ora     a               ; is it zero?
        jnz     prn81           ; nope, continue later
        mvi     a,'0'           ; print a zero
        jmp     prn82           ; done here now
prn81:
        mvi     b, 0            ; Used as a flag to skip printing leading zeroes
        lxi     d,-100          ; hundreds place
        call    pdec            ; go print it
        lxi     d,-10           ; tens place
        call    pdec            ; go print it
        mov     a,l             ; get remaining ones place
        adi     '0'             ; offset for ascii
prn82:
        call    pchar           ; and print it
        pop     d               ; restore registers
        pop     b
        pop     h
        ret

;
; pdec
; Internal subroutine to print decimal values from
; binary single or multibyte values.  To be called
; from prn16 or prn8 type subroutines
; Uses B register
;
pdec:
        mvi     c,'0'-1         ; init C
pdec2:
        inr     c               ; increment C
        dad     d               ; add negated D reg (subtract)
        jc      pdec2           ; still more to subtract (no negative yet)
        mov     a,d             ; we need to complement (re-negate to positive)
        cma                     ; complement (change sign)
        mov     d,a             ; store it back
        mov     a,e             ; lower byte, too
        cma                     ; complement that one
        mov     e,a             ; now D/E contain positive value
        inx     d               ; 2's complement, gotta add one
        dad     d               ; add that "one too many" back
        mov     a,c             ; get that count (remember, it's ascii now)
        cpi     '0'             ; check for zero
        jz      pdecz           ; check if this is a leading zero
        mvi     b,0ffh          ; set flag - this is non zero
        call    pchar           ; print it
        jmp     pdecr           ; done here
pdecz:                          ; checking for leading zeroes
        mov     a,b             ; get the flag
        cpi     0               ; has it been set?
        jz      pdecr           ; it's a leading zero, just return
        mov     a,c             ; get the zero back
        call    pchar           ; not a leading zero, print
pdecr:
        ret

;
; byt2asc
; Convert byte to hex ascii numeric (e.g., 0x80 -> 313238
; IN
;       A - byte to Convert
;       H/L - buffer pointer to put the bytes.  Buffer will
;             be incremented to the 'next' location
byt2asc
        push    d               ; save regs on entry
        push    b               ;
        mvi     e,0             ; leading zero flag
        mvi     d,100           ; hundreds place first
b2asc1:
        mvi     c,'0'-1         ; starting value
b2asc2:
        inr     c               ; increment
        sub     d               ; subtract off 100/10 value
        jnc     b2asc2          ; still positive
        add     d               ; add back to get positive
        mov     b,a             ; modulo (remainder)
        mov     a,c             ; 100/10 value
        cpi     '1'             ; compare to ascii 1
        jnc     b2asc3          ; less than 1 (it is zero)
        mov     a,e             ; get zero flag
        ora     a               ; or sets zero flag
        mov     a,c             ; get the byte again
        jz      b2asc4          ; this zero is a leading zero
b2asc3:
        mov     m,a             ; stuff the ascii byte into buffer
        inx     h               ; increment buffer
        mvi     e,0ffh          ; add number, set leading zero flag
b2asc4:
        mov     a,d             ; get 100/10 place value
        sui     90              ; go from 100 to 10
        mov     d,a             ; put it back
        mov     a,b             ; get modulo from previous
        jnc     b2asc1          ; still more to subtract off
        adi     '0'             ; ascii bias
        mov     m,a             ; store it to buffer
        inx     h               ; increment buffer
        pop     b               ; restore
        pop     d               ; registers
        ret

;
; flower
; Print a "flower box" on the screen
; IN
;       A - number of rows
;       D - start line
;       D - start col
flower:
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
        sta     flwrtmp         ; save line count
        call    setcur          ; put cursor at top left
        lxi     d,flowr1        ; print top line
        mvi     c,strout        ; print call
        call    sys             ; go print it
        lda     flwrtmp         ; retrieve line count
        cpi     0               ; initial check
flwr1:
        jz      flwr2           ; draw bottom line
        dad     sp              ; get stack pointer H/L
        lxi     h,3             ; H/L to 3 (position where D was pushed)
        dad     sp              ; point to "pushed D"
        mov     d,m             ; get original D (line number)
        inr     d               ; increment
        mov     m,d             ; save it (on stack)
        dcx     h               ; E was pushed on stack one byte later (lower in RAM)
        mov     e,m             ; put it back to E
        call    setcur          ; put cursor there
        lxi     d,flowr2        ; blank row in flowerbox
        mvi     c,strout        ; print that
        call    sys             ; let CP/M print it
        lda     flwrtmp         ; get count back
        dcr     a               ; another line?
        sta     flwrtmp         ; save updated line count
        jnz     flwr1           ;
flwr2:
        dad     sp              ; get stack pointer H/L
        lxi     h,3             ; H/L to 3 (position where D was pushed)
        dad     sp              ; point to "pushed D"
        mov     d,m             ; get original D (line number)
        dcx     h               ; E was pushed on stack one byte later (lower in RAM)
        mov     e,m             ; put it back to E
        call    setcur          ; put cursor there
        lxi     d,flowr1        ; bottom line
        mvi     c,strout        ; print func
        call    sys             ; print it
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
        ret

;
; memcpy
; memory copy from one buffer to another
; IN:
;       A count to copy
;       B/C source
;       D/E destination
memcpy:
        push    psw             ; save a/status register
        push    h               ; save H/L pair (using l)
        push    b               ; save addr of source
        push    d               ; save addr of destination
        mov     l,a             ; save count to L
        cpi     0               ; initial compare, make sure there's
mcploop:                        ; work to do
        jz      mcpdone         ; done copying, clean up and return
        ldax    b               ; get next byte from source
        stax    d               ; save to destination
        inx     b               ; next source
        inx     d               ; next destination
        dcr     l               ; decrement copy count (sets zero flag)
        jmp     mcploop         ; check and do next byte
mcpdone:
        pop     d               ; restore dst addr
        pop     b               ; restore src addr
        pop     h               ; restore H/L pair
        pop     psw             ; resture A and status flags
        ret                     ; get outta here

;
; memset
; set a buffer to a fixed byte value.
; THIS VERSION ONLY DOES UP TO 255 BYTES
; IN:
;       A byte value to set buffer to
;       B count of bytes to set
;       D/E buff
memset:
        push    b               ;
        push    d               ;
        mov     c,a             ; save count
        mov     a,b             ; move count for initial compare
        cpi     0               ;
        mov     a,c             ; get set value back
mstloop:
        jz      mstdone         ; done setting, cleanup and return
        stax    d               ; set addr to desired values
        inx     d               ; next buffer address
        dcr     b               ; decrement copy count
        jmp     mstloop
mstdone:
        pop     b               ; restore count
        pop     d               ; restore addr
        ret                     ; get outta here

;
; cls
; Clear terminal using ANSII escape sequence
; sequence is ^[2J
;
cls:
        push    h               ; save H/L
        push    b               ; save B/C
        lxi     h,esctmp        ; get buffer
        mvi     m,01bh          ; escape character
        inx     h               ; next byte
        mvi     m,'['           ; CSI (Control Sequence Introducer)
        inx     h               ; next byte
        mvi     m,'2'           ; STILL
        inx     h               ;  SETTING
        mvi     m,'J'           ;   ANSI
        inx     h               ;    SEQUENCE....
        mvi     m,'$'           ; terminator for CP/M send string syscall
        lxi     d,esctmp        ; set buffer
        mvi     c,strout        ; set function
        call    sys             ; call CP/M
        mvi     d,1             ; move cursor to
        mvi     e,1             ; top left
        call    setcur          ; after clearning screen
        pop     b               ; restore
        pop     h               ; restore
        ret

;
; setcur
; Set cursor position on screen
; sequence is ^[{line};{col}H
; IN:
;       D - line
;       E - col
setcur:
        push    psw             ; save A and PSW
        push    b               ; save B/C pair
        push    d               ; save D/E pair
        push    h               ; save H/L pair
        lxi     h,esctmp        ; get buffer for building sequence
        mvi     m,01bh          ; escape
        inx     h               ; next byte
        mvi     m,'['           ; CSI (Control Sequence Introducer)
        inx     h               ; next byte
        mov     a,d             ; get the desired line
        call    byt2asc         ; add to the buffer
        mvi     m,';'           ; separator
        inx     h               ; next byte
        mov     a,e             ; get desired column
        call    byt2asc         ; add to buffer
        mvi     m,'H'           ; finish off the command
        inx     h               ; next byte
        mvi     m,'$'           ; for CP/M command
        lxi     d,esctmp        ; back to start of buffer of CP/m
        mvi     c,strout        ; syscall for string out to the terminal
        call    sys             ; let CP/M do the thing
        pop     h               ; restore H/L
        pop     d               ; restore D/E
        pop     b               ; restore B/C
        pop     psw             ; restore A and PSW
        ret                     ; bye

;
; rstline
; Clear current line
;
rstline:
        push    d
        push    h
        call    setcur          ; put cursor on correct line
        lxi     h,esctmp        ; get sequence buffer
        mvi     m,01bh          ;
        inx     h               ;
        mvi     m,'['           ;
        inx     h               ;
        mvi     m,'2'           ;
        inx     h               ;
        mvi     m,'K'           ;
        inx     h               ;
        mvi     m,'$'           ;
        mvi     c,strout        ; send it to the console
        lxi     d,esctmp        ;
        call    sys             ;
        pop     h
        pop     d
        call    setcur          ; replace the cursor
        ret

;
; clrtags
; Clear all tags
clrtags:
        push    psw
        push    b
        push    d
        mvi     b,tagcnt        ; array of bytes of tags
        lxi     d,tags          ; get the array of tags
        mvi     b,tagcnt        ; number of bytes
        mvi     a,0             ; value
        call    memset          ; set them
        pop     b
        pop     d
        pop     psw
        ret

;
; settags
; Set all tags
settags:
        push    psw
        push    b
        push    d
        mvi     b,tagcnt        ; array of bytes of tags
        lxi     d,tags          ; get the array of tags
        mvi     b,tagcnt        ; number of bytes
        mvi     a,0ffh          ; value
        call    memset          ; set them
        pop     b
        pop     d
        pop     psw
        ret

;
; cnttags
; Count all set tag bits in tag array
; OUT
;       A - sum of set bits in array
cnttags:
        push    b               ;
        push    d               ;
        push    h               ;
        mvi     e,0             ; zero E (temporary count)
        lxi     h,tags          ; get the tag array
        mvi     d,tagcnt        ; get number of bytes in tag array
cttgs1:                         ; loop through all bytes in array
        mvi     a,1             ; bit 1
        mvi     c,9             ; 8 bits in a byte (add 1 for pre-decrement)
cttgs2:                         ; loop through all bits in current byte
        dcr     c               ; down a bit
        jz      cttgs4          ; done with this byte
        mov     b,a             ; save bit
        ana     m               ; check this bit against current byte
        jz      cttgs3          ; bit not set
        inr     e               ; bit was set, count it
cttgs3:
        mov     a,b             ; restore bit before shift
        rlc                     ; increment bit position
        jmp     cttgs2          ; go count next bit
cttgs4:
        inx     h               ; next byte
        dcr     d               ; decrement byte counter
        jnz     cttgs1          ; go count bits in this byte
        mov     a,e             ; final result in A
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret

;
; itertgs
; Iterate through tagged files.  Sets FLSEL to
; next tagged file, then clears that tag.
; OUT:
;       A - 0ffh if no tagged files
itertgs:
        push    b               ;
        push    d               ;
        push    h               ;
        lda     fcount          ; get file count
        mov     d,a             ; save to D
iter1:
        mov     a,d             ; get current index
        call    gettag          ; is that tag set?
        jz      iter2           ; nope - try next
        mov     a,d             ; get that count again
        call    clrtag          ; clear it
        mov     a,d             ; once again..
        sta     flsel           ; store it as the selected file
        mvi     a,0             ; set OK response
        jmp     iterdn          ; return
iter2:
        mov     a,d             ; get current index again
        ora     a               ; check for zero (last one)
        jz      iter3           ; go set no files flag
        dcr     d               ; decrement index
        jmp     iter1           ; try again
iter3:
        mvi     a,0ffh          ; no file flag
iterdn:
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret

;
; findtag
; find byte and bit of a tag given index
; IN
;       A - tag to find
; OUT
;       A - bit mask (desired bit set to 1)
;       H/L - address of byte
findtag:
        mov     c,a             ; save original tag number
        ani     0f8h            ; mask of lower 3 bits
        rrc                     ; divide by
        rrc                     ; eight is 3
        rrc                     ; right shifts
        lxi     d,0             ; set D/E to zero
        mov     e,a             ; set D/E to be result of inx / 8
        lxi     h,tags          ; get tag array
        dad     d               ; H/L now has address of tag byte
        mov     a,c             ; get that initial tag number back
        ani     07h             ; bit number is lower 3 bits (0-7)
        mov     c,a             ; save that number for now
        ora     0               ; is it zero?
        mvi     a,1             ; set bit zero
fndtl1:
        jz      fndtdon         ; we're done
        rlc                     ; shift left one
        dcr     c               ; decrement cnt, sets Z flag
        jmp     fndtl1          ; next
fndtdon:
        ret

;
; gettag
; Get the value of the desired tag
; IN
;       A - index of tag
; OUT
;       A - tag value (1=set, 0=clear)
gettag:
        push    b               ;
        push    d               ;
        push    h               ;
        call    findtag         ; H/L now has byte, A has mask
        ana     m               ; AND with index byte to get result
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret

;
; settag
; Set the desired tag
; IN
;       A - index of tag to set
settag:
        push    b               ;
        push    d               ;
        push    h               ;
        call    findtag         ; H/L now has byte, A has mask
        ora     m               ; OR with index byte to get result
        mov     m,a             ; save it back to array
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret

;
; clrtag
; Clear the value of the desired tag
; IN
;       A - index of tag
clrtag:
        push    b               ;
        push    d               ;
        push    h               ;
        call    findtag         ; H/L now has byte, A has mask
        xri     0ffh            ; XOR the set bit
        ana     m               ; AND with index byte to clear the bit
        mov     m,a             ; store it back to the array
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret

;
; bldfcb
; Build a file control block using filename from
; FLSEL's filename
; resulting fcb1
bldfcb:
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
        lxi     b,schfcb        ; set B/C to search value for find first
        lxi     d,fcb1          ; set D/E to file control block 2
        mvi     a,fcblen        ; 32 bytes to copy
        call    memcpy          ; this sets up fcb1 with generic format
        mvi     c,getdsk        ; get current disk number (A=0, etc)
        call    sys             ; ask CP/M for it, return in A
        inr     a               ; A=1
        sta     fcb1            ; first byte of fcb is drive number
        call    setfptr         ; flposn is now set to start of filename
        lhld    flposn          ; start of selected filename
        mov     b,h             ;
        mov     c,l
        lxi     d,fcb1+1        ; start of FCB + 1
        mvi     a,fnlen         ; 11 bytes in filename
        call    memcpy          ; copy filename into fcb1]
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
        ret

;
; pfsize
; Print filesize
; Prints decimal filesize (in KB)
pfsize:
        push    b               ;
        push    d               ;
        push    h               ;
        call    bldfcb          ; build an FCB for the selected file
        lxi     d,fcb1          ; point to it
        mvi     c,fsize         ; syscal to get file size
        call    sys             ; do the syscall
        lxi     h,fcb1          ; H/L to fcb1
        lxi     b,33            ; byte 33 is size in sectors
        dad     b               ; so set H/L to that byte
        mov     a,m             ; put it into A
        ani     0f8h            ; mask off lower 3 bits
        rar                     ; three right shifts
        rar                     ; is divide by 8
        rar                     ; (each sector is 128 bytes, 1/8 K)
        mov     l,a             ; move to L register
        call    prn8            ; print it at current location
        mvi     a,'K'           ; print 'K'
        call    pchar           ;
        mvi     a,'B'           ; print 'B;
        call    pchar           ;
        mvi     a,' '           ; adda space
        call    pchar           ;
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret

;
; first
; get first file FCB in directory
; RETURNS:
;       A - result (0xff if no file found)
;       B/C pair - address of file control block
;
first:
        lxi     b,schfcb        ; set B/C to search value for find first
        lxi     d,fcb1          ; set D/E to file control block 2
        mvi     a,fcblen        ; 32 bytes to copy
        call    memcpy          ; copy search value to FCB1
        mvi     c,srchf         ; search first file function
        call    sys             ; call CP/M, result in A
        lxi     b,dma1          ; set address of FCB as DMA1
        ret

;
; nextf
; get next file name in directory
; RETURNS:
;       A - result (0xff if no file found)
;       B/C pair - address of file control block
;
nextf:
        mvi     c,srchn         ; search next file function
        call    sys             ; call CP/M, result in A
        cpi     255             ; compare to 0xff - no file found
        rz                      ; no file was found
        rlc                     ;
        rlc                     ; do 5 left shifts on the A
        rlc                     ; register,
        rlc                     ; this multiplies the value in
        rlc                     ; A by 32 to get offset of next FCB
        lxi     h,0             ; load the H/L pair with the value
        mov     l,a             ; in A
        lxi     b,dma1          ; load B/C pair with base address of DMA
        dad     b               ; H/L now contain address of new found FCB
        mov     b,h             ; save that to
        mov     c,l             ; B/C pair
        ret

;
; gtfinfo
; Get file info - gets filesize, attributes, and user number


;
; enumdir
; Enumerate directory - get all filenames on the currently
; logged disk
; RETURNS
;       fcount - number of files found
; Stomps on most registers :/
enumdir:
        lxi     h,flist         ; get the address file buffer
        shld    flposn          ; save that as pointer (start at beginning)
        lxi     h,fcount        ; get file count variable
        mvi     m,0             ; zero file count
        lxi     h,flsel         ; get the selected file variable
        mvi     m,0             ; zero that, too
        call    first           ; find first file, FCB is in B/C
        cpi     0ffh            ; compare a to 255; 255 means no file found
        jnz     frstok          ; we found a file
        mvi     c,strout        ; gonna print a string
        lxi     d,nofiles       ; msg: no files on disk
        jmp     enumret         ; we're all done here
frstok:
        inx     b               ; B/C holds FCB1, filename starts at second byte
        lhld    flposn          ; load value at flposn into H/L
        xchg                    ; swap H/L into D/E
        mvi     a,fnlen         ; set copy len to be 8+3 (file name + ext in FCB)
        call    memcpy          ; copy filename to buffer\
        lhld    flposn          ; get the buffer pointer again
        lxi     b,finflen       ; load B/C with data struct length
        dad     b               ; add filename length to buffer pointer
        shld    flposn          ; save it
        lda     fcount          ; get file count
        inr     a               ; increment
        sta     fcount          ; save it
nxtfl:
        call    nextf           ; look for another file
        cpi     0ffh            ; no more files found
        jz      enumret         ; so break out of loop
        inx     b               ; B/C holds FCB1, filename starts at second byte
        lhld    flposn          ; get next address of filename buffer into H/L
        xchg                    ; swap that into D/E
        mvi     a,fnlen         ; set copy len to be 8+3 (file name + ext in FCB)
        call    memcpy          ; copy filename to buffer
        lhld    flposn          ; get the buffer pointer again
        lxi     b,finflen         ; load B/C with filename length
        dad     b               ; add filename length to buffer pointer
        shld    flposn          ; save it
        lda     fcount          ; get file count
        inr     a               ; increment
        sta     fcount          ; save it
        cpi     maxfls          ; did we hit max?
        jz      enumful         ; yes, stop loading
        jmp     nxtfl           ; go try again
enumful:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 4 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,20            ; column 20
        call    setcur          ; put cursor there
        lxi     d,en2many       ; error message
        mvi     c,strout        ; print it
        call    sys             ; do the syscall
        mvi     l,maxfls        ; print max file count
        call    prn8            ; print
        mvi     c,conin         ; wait for input
        call    sys             ; via syscall
        call    cls             ; clear screen before continuing
enumret:
        ret                     ; all done

;
; setfptr
; Set flposn to point to the start position of
; the selected file in the filename buffer
; Selected file identified by FLSEL
setfptr:
        push    psw
        push    b
        push    d
        push    h
        lda     flsel           ; get selected file number
        mov     b,a             ; save selected to B
        mvi     c,0             ; zero current file index
        lxi     h,flposn        ; get the pointer
        mvi     h,0             ; zero it
        mvi     l,0             ; zeroing
        lxi     d,flist         ; start of filename list buffer in D/E
        dad     d               ; set flposn pointer to be start of buffer
        lxi     d,finflen       ; load D/E with 11 struct len
setfp1:
        mov     a,c             ; get current index
        cmp     b               ; is it the desired filename?
        jz      setfp2          ; yup, we're done
        dad     d               ; add 11 to the current flist pointer value
        inr     c               ; incrment file number
        jmp     setfp1          ; go and increment again
setfp2:
        shld    flposn          ; save the position
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
        ret

;
; prnname
; Print filename in human readible form
; Name to print will be the selected file number
; store in variable FLSEL
;
prnname:
        push    psw
        push    b
        push    d
        push    h
        call    setfptr         ; set flposn pointer with start of filename
        lhld    flposn          ; load the pointer into H/L
        mvi     d,8             ; 8 characters in filename portion
prnnm2:
        mov     a,m             ; get next char
        inx     h               ; increment buffer pointer
        cpi     ' '             ; is it a space?
        jz      prnnm3          ; don't print a space
        call    pchar           ; print non-space char
prnnm3:
        dcr     d               ; decrement count, sets Z flag
        jnz     prnnm2          ; more to print
        mvi     a,'.'           ; delimiter
        call    pchar           ; print it
        mvi     d,3             ; 3 chars in extension portion
prnnm4:
        mov     a,m             ; get next char
        inx     h               ; increment buffer pointer
        call    pchar           ; print it
        dcr     d               ; decrement char count, sets Z flag
        jnz     prnnm4          ; nope, guess not :/
        pop     h
        pop     d
        pop     b
        pop     psw
        ret

;
; fndisp
; Formatted display of filenames.  5 columns of names,
; each with a preceding "[ ]" which will be used to hold
; selected file status
;
fndisp
        push    psw             ; save A and PSW
        push    b               ; save B/C
        push    d               ; save D/E
        push    h               ; save H/L
        lxi     h,flsel         ; get selected file number
        mvi     m,0             ; zero it out
        lda     fcount          ; get file count to a
        cpi     0               ; is it zero (no files?)
        jz      fnddone         ; then we're done
        mov     c,a             ; save file count
        mvi     d,strtrow       ; first line to use
        mvi     e,1             ; start in column 1
fndlp:
        call    setcur          ; move cursor there
        mvi     a,'['           ; print
        call    pchar           ;   [ ]
        mvi     a,' '           ; to terminal
        call    pchar           ; to hold
        mvi     a,']'           ; and 'X'
        call    pchar           ; inidicating selection
        call    prnname         ; print filename
        lda     flsel           ; get selected file number
        inr     a               ; and increment it
        sta     flsel           ; save it
        mov     a,e             ; get column start
        adi     dspace          ; bump it up for next set of files
        mov     e,a             ; save it for now
        cpi     dsmax           ; anything greater than 77 would be column 6
        jm      fndlp1          ; nope, this is column 5 or less
        mvi     e,1             ; start over at column 1
        inr     d               ; next row
fndlp1:
        dcr     c               ; decrement file count, sets Z flag
        jnz     fndlp           ; go do next
fnddone:
        pop     h               ; restore H/L
        pop     d               ; restore D/E
        pop     b               ; restore B/C
        pop     psw             ; restore A and PSW
        ret                     ; all done

;
; listfls
; List all files on logged drive, resets counters, etc.
;
listfls:
        call    cls             ; clear
        call    enumdir         ; get the listing for the logged drive,
                                ; names stored in buffer, not printed yet
        call    fndisp          ; formatted listing of filenames
        lda     flsel           ; reload selected file number
        mvi     a,0             ; and reset to zero
        sta     flsel           ; store it
        ret

;
; prnui
; Print "user interface" section
;
prnui:
        push    psw             ; save A and PSW
        push    b               ; save B/C
        push    d               ; save D/E
        push    h               ; save H/L
        mvi     d,1             ; new cursor position, line 1
        mvi     e,20            ; column 22
        call    rstline         ; clear current line,
        mvi     c,strout        ; print string
        lxi     d,fndstr1       ; "Listing of drive " message
        call    sys             ; CP/M
        mvi     c,getdsk        ; get current disk number (A=0, etc)
        call    sys             ; ask CP/M for it, return in A
        adi     'A'             ; bias for ASCII
        call    pchar           ; print that
        mvi     a,':'           ; trailing colon after drive letter
        call    pchar           ; print to terminal
        lxi     d,fndstr2       ; " (total of  " message
        mvi     c,strout        ; print string
        call    sys             ; CP/M
        lda     fcount          ; get file count
        mov     l,a             ; put in L for print
        call    prn8            ; print it as decimal
        mvi     c,strout        ; print string
        lxi     d,fndstr3       ; next part of header
        call    sys             ; print to terminal
        call    cnttags         ; get count of tagged files
        mov     l,a             ; it was in A, move to L for
        call    prn8            ; printing as 8-bit decimal
        mvi     a,' '           ; another space
        call    pchar           ; to print
        lxi     d,fndstr4       ; final part of top line
        mvi     c,strout        ; print string
        call    sys             ; syscall
        mvi     d,20            ; go to line 20
        mvi     e,1             ; column 1
        call    rstline         ; clear line
        lxi     d,uistr1        ; "Current file..." message
        mvi     c,strout        ; string out syscall
        call    sys             ; make the syscall
        lxi     d,uibold        ; set bold font
        mvi     c,strout        ; print
        call    sys             ; print it
        call    prnname         ; print selected filename
        ;mvi     a,' '          ;
        ;call    pchar          ;
        ;call    pchar          ;
        ;call    pfsize         ; print filesize
        lxi     d,uireset       ; clear formatting
        mvi     c,strout        ; print
        call    sys             ; print it
        mvi     d,21            ; go to line 21
        mvi     e,1             ; column 1
        call    rstline         ; clear line
        lxi     d,uistr2        ; second UI line
        mvi     c,strout        ; print string
        call    sys             ; let cpm print it
xret:
        pop     h               ; restore H/L
        pop     d               ; restore D/E
        pop     b               ; restore B/C
        pop     psw             ; restore A and PSW
        ret                     ; all done

;***************************************************
; START OF FIXED DATA AREA
;***************************************************
canary  db      0beh,0efh,0cah,0feh
errcan  db      'ERROR - Stack is corrupt!',CR,LF,'$'
flowr1  db      '+--------------------------------------------------+$'
flowr2  db      '|                                                  |$'
stemver db      'STEM v0.9.0$'
welcom1 db      'An Altair 8800 File Manager$'
welcom2 db      '2026 Mattydyne Heavy Industries$'
welcom3 db      01bh,'[1m"H" for help, any other key to start',01bh,'[0m',CR,LF,'$'
nofiles db      'No files found',CR,LF,'$'
en2many db      'Exceeded max file count!  Loading first $'
fndstr1 db      'Listing of drive $'
fndstr2 db      ' (total of $'
fndstr3 db      ' files, $'
fndstr4 db      ' tagged)$'
uibold  db      01bh,'[1m$'
uireset db      01bh,'[0m$'
uistr1  db      'Currently selected file (N/P-next/previous,Space-tag/untag): $'
uistr2  db      'Command(D-delete,C-copy,T-display,R-rename,H-help,X-exit)? $'
delmsg  db      'Delete file $'
uichyn  db      ' (Y/N)? $'
uichyna db      ' (Y/N/A)? $'
logmsg  db      'Select new disk letter: $'
logerr  db      'Disk x: is not available, any key to continue$'
schfcb  db      0,'???????????',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mworkng db      'Enumerating files in drive $'
help1   db      'STEM - a basic file manager for CP/M 2.2 on Altair 8800',CR,LF,CR,LF,'$'



;***************************************************
; START OF VARIABLE DATA AREA
;***************************************************
orgstk  ds      2               ; original stack pointer
dpbase  ds      2               ; Disk Parameter Base address
dphxlt  ds      2               ; XLT (address of phys to logical translation vector
dphsp1  ds      2               ; scratch pad 1
dphsp2  ds      2               ; scratch pad 2
dphsp3  ds      2               ; scratch pad 3
dphdbuf ds      2               ; address of 126-byte directory scratch pad
dphdpb  ds      2               ; address of disk parameter block
dphcsv  ds      2               ; address of changed disk scratch pad
dphalv  ds      2               ; address of disk storage allocation
dpbspt  ds      2               ; disk parameter block - sectors per track
dpbbsh  ds      1               ; disk parameter block - block shift factor
dpbblm  ds      1               ; disk parameter block - allocation block mask
dpbexm  ds      1               ; disk parameter block - extent mask
dpbdsm  ds      2               ; disk parameter block - total storage capacity
dpbdrm  ds      2               ; disk parameter block - directory entry capacity
dpbal0  ds      1               ; disk parameter block - reserved blocks
dpbal1  ds      1               ; disk parameter block - reserved blocks
dpbcks  ds      2               ; disk parameter block - directory check vector size
dpboff  ds      2               ; disk parameter block - count of reserved tracks at beginning
fcb2    ds      fcblen          ; another FCB for file operations
fcount  ds      1               ; file count addr
flsel   ds      1               ; selected file number
flwrtmp ds      1               ; temporary storage for flower box
drvtmp  ds      1               ; drive letter storage during drive change
flposn  ds      2               ; position in file name array
flist   ds      (maxfls*finflen)+1 ; area for list of filenames
tags    ds      tagcnt          ; bitmap of tagged files
esctmp  ds      24              ; temp area for building escape sequences
stkcny  ds      4               ; stack canary
usrstk  ds      64              ; 32 level stack
newstk                          ; top of newstk area

        end
