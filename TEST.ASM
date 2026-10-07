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
guser	equ     32              ; get/set user code
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




        org     0100h           ; TPA area
        mvi     a,0cdh          ; call instruction
        sta     cinst           ;
        mvi     a,0c9h
        sta     cret
        lhld    01h             ; get warm boot vector
        lxi     b,018h          ; address of get drive table
        dad     b               ; set H/L to address of get drive table
        shld    addr            ; store that
        mvi     a,0             ; drive 0
        sta     drive           ;
drvlp:
        lxi     d,msg1
        mvi     c,strout
        call    sys
        lda     drive
        adi     'A'
        call    pchar
        mvi     a,' '
        call    pchar
        lda     drive
        mov     c,a
        call    stuff
        mov     a,h
        call    phex
        mov     a,l
        call    phex
        call    crlf
        lda     drive
        inr     a
        sta     drive
        cpi     16
        jnz     drvlp
        ret

stuff:
        lxi     h,cinst
        pchl

;
; pchar
; print a character to console out
; IN:
;	reg A - character to print
; all registers preserved
pchar:
        push    h               ;
        push    d               ;
        push    b
        mvi     c,conout        ; CP/M function for char out
        mov     e,a             ; char needs to be in Reg e
        call    sys             ; call CP/M to print
        pop     b               ;
        pop     d               ;
        pop     h               ;
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
        push    b               ;
        push    d               ;
        push    h               ;
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
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret








msg1    db      'Drive $'

drive   ds      1
cinst   ds      1
addr    ds      2
cret    ds      1
        end
