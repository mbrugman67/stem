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
fcblen  equ     34              ; byte size of File Control Block
fnbflen equ     452             ; length of filename buffer
fnlen   equ     11              ; length of 8.3 filename (8+3)
dspace  equ     16              ; spacing between filenames in list
dsmax   equ     71              ; when to wrap filename list
strtrow equ     3               ; first row of file list
maxfls  equ     70              ; max files in buffer
tagcnt  equ     maxfls/8+1      ; number of tag bytes in array
uinplen equ     40              ; length of user input buffer

;****************************************************
; Start of actual program code here
; .org 100h - TPA area starts at 0x0100
;****************************************************
        org     0100h           ; entry point at 100 hex (TPA area)
        lxi     d,canary        ; point to fixed canary value
        lxi     h,stkcny        ; point to last 4 bytes under stack
        lxi     b,4             ; 4 bytes of stack canary
        call    memcpy          ; copy fixed data to mem just under stack
        lxi     h,0             ; zero H/L register pair
        dad     sp              ; get stack pointer from CCP to H/L
        shld    orgstk          ; save original stack pointer to memory
        lxi     sp,newstk       ; set stack pointer to our new stack

        ; Draw the "Welcome" header over whatever is on the screen
        mvi     d,5             ; flower box at line 5
        mvi     e,16            ; flower box at column 16
        mvi     a,8             ; 7 blank lines in box
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
        call    tstdrvs         ; "log in" all hardware drives, just to check validity

        ; start of main loop.  Entering at 'usrlp0' will result in a total
        ; re-read of filenames and screen redraw.  Entering at 'uinext' will
        ; keep existing tags and files
usrlp0:
        call    clrtags         ; clear all file tags
        call    listfls         ; load and list files
uinext:                         ; user UI interaction loop
        call    stkchk          ; check stack integrity
        ora     a               ; stack is OK
        jz      cont            ; continue on
        call    crlf            ; newline
        call    crlf            ; another newline
        lxi     d,errcan        ; stack error message
        mvi     c,strout        ; print it
        call    sys             ; print it
        jmp     cleanup         ; get outta here

cont:
        ;call    prnvars         ; print debug stuffs on line 2
        call    prnui           ; print user interface info & menu
        call    cin2uppr        ; get user input (force to uppercase)

        ; Move file selection to next file.  Wraps around to first file
        ; when current selected is last
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

        ; Move file selection to previous file.  Wraps around to last
        ; file when current is first file
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

        ; handle file tagging.  When the 'space' key is pressed, the
        ; current selected file tag status is toggled.  Tags are stored
        ; in a bitmap (an array of bytes where each bit represents one
        ; file)
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

        ; Delete all tagged files.  The first file is displayed with a prompt
        ; to "delete yes/no/all".  If 'no', then go to the next tagged file,
        ; if yes, then delete and go to next tagged file.  If 'all', then
        ; delete all remaining tagged files with no more prompts.  Danger, Will
        ; Robinson!!
uidel:
        cpi     'D'             ; Delete file(s)?
        jnz     uicopy          ; Nope, go check file copy
        mvi     a,0             ; zero flag
        sta     allflag         ; store it
        call    cnttags         ; get count of tagged files
        cpi     0               ; is it zero?
        jnz     dels1           ; no? go start deleting
        lxi     d,delser        ; error message for no files selected
        call    perr            ; print the error message in a flower box
        jmp     usrlp0          ; redraw all
dels1:
        call    itertgs         ; get the next tagged file
        cpi     0ffh            ; 0xff means no more tagged files
        jz      usrlp0          ; all done
delbox:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 3 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,26            ; column 26
        call    setcur          ; put cursor there
        lxi     d,delmsg        ; "Delete file"... message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        call    prnname         ; print file name
        lda     allflag         ; user previously said "all"?
        ora     a               ; check for non-zero
        jnz     dels2           ; yup, go delete next
        lxi     d,uichyna       ; Yes/No/ALL prompt
        mvi     c,strout        ; print
        call    sys             ; syscall
        call    cin2uppr        ; get user choice
        cpi     'N'             ; user said nope
        jz      dels1           ; check next file
        cpi     'Y'             ; user said yup
        jz      dels2           ; oboy, here we go
        cpi     'A'             ; yes to all!
        jnz     delbox          ; go ask again
        mvi     a,0ffh          ; set flag
        sta     allflag         ; save it for next file
dels2:
        call    bldfcb          ; set up a file control block
        lxi     d,fcb1          ; point to the FCB1
        mvi     c,fdel          ; syscall number to delete file
        call    sys             ; do the syscall
        jmp     dels1           ; probably need some error handling here!!

        ; Copy all tagged files.  User will be prompted for a new filename
        ; for each file.  This can be on current drive if the new filename
        ; is just entered like "newfile.txt", or on another drive if
        ; specified (e.g., "b:newfile.txt").  If the destination already
        ; exists, file will not be copied, and user will be prompted for a
        ; new name.
uicopy:
        cpi     'C'             ; copy file?
        jnz     uitype          ; nope, try for display contents
        mvi     a,0             ; zero flag
        sta     allflag         ; store it
        call    cnttags         ; get count of tagged files
        cpi     0               ; is it zero?
        jnz     cpy1            ; no? go start copying
        lxi     d,cpyser        ; error message for no files selected
        call    perr            ; print the error message in a flower box
        jmp     usrlp0          ; redraw all
cpy1:
        call    itertgs         ; get the next tagged file
        cpi     0ffh            ; 0xff means no more tagged files
        jz      usrlp0          ; all done
cpybox:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 3 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,26            ; column 26
        call    setcur          ; put cursor there
        lxi     d,cpymsg1       ; "Copy file"... message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        call    prnname         ; print file name
        lxi     d,uichyn        ; Yes/No
        mvi     c,strout        ; print
        call    sys             ; syscall
        call    cin2uppr        ; get user choice
        cpi     'N'             ; user said nope
        jz      cpy1            ; check next file
        cpi     'Y'             ; user said yup
        jz      cpy2            ; oboy, here we go
        jmp     cpybox          ; something else
cpy2:
        call    bldfcb          ; set up a file control block for source file
        lxi     d,blnkfcb       ; blank FCB, ready for filename (src)
        lxi     h,fcb2          ; get FCB 2 address (dst)
        lxi     b,fcblen        ; set length
        call    memcpy          ; copy blank FCB data to FCB2
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,6             ; 5 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,29            ; column 29
        call    setcur          ; put cursor there
        lxi     d,cpymsg1       ; "Copy file"... message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        call    prnname         ; print file name
        mvi     d,9             ; line 7
        mvi     e,22            ; column 22
        call    setcur          ; put cursor there
        lxi     d,cpymsg2       ; "new name"... message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        call    getfnm          ; get filename from user
        ora     a               ; check return code
        jz      cpy3            ; good filename
        lxi     d,badfnm        ; bad filename message
        call    perr            ; print the error
        jmp     cpybox          ; re-prompt for name
cpy3:
        call    bldfcb          ; set up source file control block
        lxi     h,fcb2          ; start setting up dest FCB (dst)
        lxi     d,blnkfcb       ; default "blank" FCB (src)
        lxi     b,fcblen        ; FCB length
        call    memcpy          ; copy default to dest FCB
        lxi     d,usrfnm        ; point to user entered filenamene (src)
        lxi     h,fcb2+1        ; name startes at byte 1 (dst)
        lxi     b,fnlen         ; copy count = filename length
        call    memcpy          ; copy user filename into dest FCB
        lxi     d,fcb2          ; point to dest FCB1
        mvi     c,fopen         ; syscall code for open file
        call    sys             ; try to open the file
        cpi     0ffh            ; 255 means file does not exist.  Good!
        jnz     cpyexst         ; go error for destination already exists
        lxi     d,fcb1          ; point to source file
        mvi     c,fopen         ; try to open it
        call    sys             ; hey FDOS - go open the file!
        cpi     0ffh            ; 255 means unable to open the file :/
        jz      cpyofl          ; jump to open fail
        lxi     d,fcb2          ; point to dest FCB
        mvi     c,fmake         ; syscal to make file
        call    sys             ; hey FDOS, one more time!
        cpi     0ffh            ; 255 means unable to create dest file
        jz      cpydfl          ; error message, close source file
        xra     a               ; zero A reg
        sta     eofflag         ; save as EOF flag
        lxi     h,0             ; zero H/L register set
        shld    blkcnt          ; save it to block count
cpy4:                           ; FILE COPY HAPPENS THROUGH DMA BLOCK at 0x0080
        lxi     d,fcb1          ; source file
        mvi     c,rdseq         ; read a block function
        call    sys             ; read the block
        ora     a               ; check for end of file (any non-zero result)
        jz      cpy5            ; go clean up
        lxi     d,fcb2          ; destination file
        mvi     c,wrseq         ; write block function
        call    sys             ; write the block
        lhld    blkcnt          ; get block counter
        inx     h               ; increment it
        shld    blkcnt          ; save it
        jmp     cpy4            ; back for next block
cpy5:
        lxi     d,fcb1          ; source file
        mvi     c,fclose        ; close function
        call    sys             ; go do it
        lxi     d,fcb2          ; dest file
        mvi     c,fclose        ; close function
        call    sys             ; go do it
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 3 blank lines
        call    flower          ; flower box
        mvi     d,7             ; line 7
        mvi     e,25            ; column 25
        call    setcur          ; cursor goes there
        lhld    blkcnt          ; get the block count
        call    prn16           ; print that as a decimal
        lxi     d,cpyok         ; ' blocks copied' message
        mvi     c,strout        ; print string function
        call    sys             ; syscall
        mvi     c,conin
        call    sys
        jmp     cpy1            ; next tagged file
cpyexst:
        lxi     d,fcb2          ; make sure we're pointing to dest file
        mvi     c,fclose        ; close bad existing destination file
        call    sys             ; syscall
        lxi     d,cpyeer        ; file exists message
        call    perr            ; error display
        jmp     cpybox          ; back to prompt file again
cpyofl:
        lxi     d,cpysr1        ; "Unable to open source..." msg
        call    perr            ; display error message
        jmp     cpybox          ; go try again
cpydfl:
        lxi     d,fcb1          ; point to source file
        mvi     d,fclose        ; close syscall
        call    sys             ; go close it
        lxi     d,cpyder        ; "Unable to open source..." msg
        call    perr            ; display error message
        jmp     cpybox          ; go try again



uitype:
        cpi     'T'             ; display file?
        jnz     uiren           ; nope, try rename next


uiren:
        cpi     'R'             ; rename file?
        jnz     uihelp          ; nope, try

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

        ; "Log into another disk" - in other words, change disk.  User
        ; is prompted for the new disk.  If disk is "OK", then the
        ; files will be listed for that drive.  Otherwise, a "disk not
        ; available" kind of error will be displayed, and the current
        ; disk will be re-listed.
uilog:
        cpi     'L'             ; Log disk?
        jnz     uiexit          ; Nope - check for exit
uilog1:
        mvi     d,5             ; line 5
        mvi     e,16            ; column 16
        mvi     a,4             ; 3 blank lines
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
        jmp     usrlp0          ; go read new disk and list files
uilog2:
        lxi     d,logerr        ; Error message
        lxi     h,tmpmsg        ; temporary message buffer
        lxi     b,31            ; length of error message
        call    memcpy          ; cpy msg into buffer
        lda     drvtmp          ; get user's drive choice
        lxi     d,tmpmsg+10     ; 10 characters in is placeholder for disk ID
        stax    d               ; store the drive letter there
        lxi     d,tmpmsg        ; get the start of the buffer again
        call    perr            ; display it
        jmp     usrlp0          ; go back and re-read current disk

        ; go back to CP/M.
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
        push    h               ; h=sp+7, l=sp+6
        push    d               ; d=sp+5, e=sp+4
        push    b               ; b=sp+3, c=sp+2
        push    psw             ; psw=sp, a=sp+1
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
        mvi     a,' '           ;
        call    pchar           ;
        call    pchar           ;
        lxi     h,newstk        ;
        lxi     b,-256          ;
        dad     b               ;
        call    prn16           ;
        mvi     a,'/'           ;
        call    pchar           ;
        lhld    06h             ;
        lxi     b,-256          ;
        dad     b               ;
        call    prn16           ;
        mvi     a,'K'           ;
        call    pchar           ;
        mvi     a,'B'           ;
        call    pchar           ;
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
;       A - 255 if stack was blown, 0 if stack OK
stkchk:
        lxi     d,canary        ; get fixed value address
        lxi     h,stkcny        ; get last 4 bytes under stack
        lxi     b,4             ; 4 bytes to compare
        call    memcmp          ; compare buffers
        ret                     ; all done

;
; tstdrvs
; Try to find a file on the first 4 drives.  This will "log"
; them in CP/M, so that they show up in the "logged in vector"
tstdrvs:
        lxi     d,schfcb        ; point to the "find any file" fcb template
        lxi     h,fcb1          ; point to the default file control block
        lxi     b,fcblen        ; length of FCB
        call    memcpy          ; copy template to default FCB
        mvi     a,1             ; set drive 1 (A)
        sta     drvtmp          ; save that for now
tstd1:
        lda     drvtmp          ; get current drive select
        lxi     d,fcb1          ; point to default FCB
        stax    d               ; store drive number in byte 0
        mvi     c,srchf         ; syscall function to find file
        call    sys             ; do the syscall
        lda     drvtmp          ; go back and get the drive number
        inr     a               ; increment
        sta     drvtmp          ; save it
        cpi     4               ; is it 4 yet?
        rz                      ; if so, we're done; return to caller
        jmp     tstd1           ; go search on next drive

;
; isdskok
; Check if selected disk is online
; IN:
;       A - disk number (A=0, B=1, etc)
; OUT:
;       A - zero means disk offline, any
;           non-zero means disk online and OK
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

;
; getinput
; Get user input


;
; getfnm
; Get a filename from the user
; Result placed in buffer at USRFNM
; OUT:
;       A - 0=good filename, 0xff bad
getfnm:
        push    b               ;
        push    d               ;
        push    h               ;
        lxi     h,usrfnm        ; get address of fn buffer
        mvi     b,' '           ; fill with spaces
        lxi     d,fnlen         ; for filename number of bytes
        call    memset          ; go do it
        lxi     d,usrfnm+fnlen  ; special thing here
        mvi     a,'$'           ; drop a dollar sign at the end of the buffer
        stax    d               ; so we can straight up print it with strout
        mvi     c,8             ; char counter
        lxi     h,usrfnm        ; point to start of filename buffer
gfn1:
        call    cin2uppr        ; get user input
        cpi     '.'             ; early "dot"?
        jz      gfn4            ; go get the extension
        cpi     8               ; user hit <BACKSPACE>?
        jnz     gfn2            ; nope, go place char in buffer
        mov     a,c             ; get char position
        cpi     8               ; have any chars been entered?
        jz      gfn1            ; ignore the backspace
        inr     c               ; revert a char
        dcx     h               ; back up the buffer
        mvi     m,' '           ; put the space back, too
        jmp     gfn1            ; go try again
gfn2:
        mov     m,a             ; drop it into filename
        inx     h               ; next byte
        dcr     c               ; next char, sets zero flag
        jnz     gfn1            ; Done with basename, get extension
gfn3:
        mvi     a,'.'           ; force a separator
        call    pchar           ; and print it
gfn4:
        lxi     h,usrfnm+8      ; start of extension
        mvi     c,3             ; extension length
gfn5:
        call    cin2uppr        ; get input
        cpi     CR              ; user hit <ENTER>?
        jz      gfn6            ; go validate
        cpi     08h             ; user hit <BACKSPACE>?
        jnz     gfn6            ; nope, add extension character
        mov     a,c             ; get char position
        cpi     3               ; have any chars been entered?
        jz      gfn5            ; ignore the backspace
        inr     c               ; revert a char
        dcx     h               ; back up the buffer
        mvi     m,' '           ; put the space back, too
        jmp     gfn5            ; go try again
gfn6:
        mov     m,a             ; copy to FCB2
        inx     h               ; next byte
        dcr     c               ; next ext, sets zero flag
        jnz     gfn5            ; loop
gfn7:
        mvi     b,0fh          ; assume a bad name
gfnval:
        lxi     h,usrfnm        ; time to start validating
        mov     a,m             ; get first character
        cpi     'A'             ; is char less than uppercase A?
        jm      gfnret          ; filename must start with alpha
        cpi     'Z'             ; is char greater than uppercase Z?
        jp      gfnret          ; again, bad!
        inx     h               ; next char
        mvi     c,10            ; seven more chars + 3 ext to go
gfnv2:
        mov     a,m             ; get next char
        cpi     ' '             ; space is OK (ok, this can be a problem to check...)
        jz      gfnv3           ; spaces allowed between name and ext
        cpi     'Z'+1           ; can't be greater than capital Z
        jp      gfnret          ; return with error
        cpi     'A'             ; but can be between A and Z
        jp      gfnv3           ; return with error
        cpi     '9'+1           ; at this point, can't be greater than "9"
        jp      gfnret          ; return with error
        cpi     '0'             ; or less than zero (sorry, B.E.E.)
        jm      gfnret          ; return with error
gfnv3:
        inx     h               ; next char
        dcr     c               ; decrement count
        jnz     gfnv2           ; next check
        mvi     b,0             ; if we got this far, name is good!
gfnret:
        mov     a,b             ; get return code for exit
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret
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
        push    b               ;
        push    d               ;
        push    h               ;
        mvi     c,conin         ; code for console in
        call    sys             ; do the syscall
        cpi     'a'             ; is char greater or equal to lowercase a?
        jm      c2udone         ; less than lower case a, return whatever this is
        cpi     'z'+1           ; is char greater than lowercase z?
        jp      c2udone         ; sure it, just return it
        ani     0dfh            ; mask off bit 5 (that's the difference between A and a, etc)
c2udone:
        pop     h               ;
        pop     d               ;
        pop     b               ;
        ret                     ; and get outta here

;
; prn16
; Print 16-bit binary value as decimal
; IN:
;       H/L - value to print
; all registers preserved
;
prn16:
        push    h               ;
        push    b               ;
        push    d               ;
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
        pop     d               ;
        pop     b               ;
        pop     h               ;
        ret

;
; prn8
; Print 8-bit binary value as decimal
; IN:
;       L - value to print
; all registers preserved
;
prn8:
        push    h               ;
        push    b               ;
        push    d               ;
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
        pop     d               ;
        pop     b               ;
        pop     h               ;
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
        push    d               ;
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
        pop     b               ;
        pop     d               ;
        ret

;
; flower
; Print a "flower box" on the screen
; IN
;       A - number of rows + 1
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
;       B/C byte count
;       D/E source
;       H/L destination
memcpy:
        push    psw             ;
        push    h               ;
        push    b               ;
        push    d               ;
        mov     a,b             ; get upper byte of count
        ora     c               ; or it with lower byte
mcploop:
        jz      mcpdone         ; all done when count is zero
        ldax    d               ; get first source byte
        mov     m,a             ; copy it to dest
        inx     d               ; increment source
        inx     h               ; increment destination
        dcx     b               ; decrement count
        mov     a,b             ; get upper byte of count
        ora     c               ; or it with lower byte, sets Z flag
        jmp     mcploop         ; go do next byte
mcpdone:
        pop     d               ;
        pop     b               ;
        pop     h               ;
        pop     psw             ;
        ret                     ; get outta here

;
; memcmp
; compare two memory buffers
; IN:
;       B/C byte count
;       D/E buffer 1
;       H/L buffer 2
; OUT:
;       A - zero if buffers match
memcmp:
        push    h               ;
        push    b               ;
        push    d               ;
        mov     a,b             ; get upper byte of count
        ora     c               ; or it with lower byte
mcloop:
        jz      mcdone          ; all done when count is zero (A will have zero)
        ldax    d               ; get first source byte
        cmp     m               ; copy it to dest
        jnz     mcdiff          ; they are different!!
        inx     d               ; increment source
        inx     h               ; increment destination
        dcx     b               ; decrement count
        mov     a,b             ; get upper byte of count
        ora     c               ; or it with lower byte, sets Z flag
        jmp     mcloop          ; go do next byte
mcdiff:
        mvi     a,0ffh          ; set a non-zero value to A for error
mcdone:
        pop     d               ;
        pop     b               ;
        pop     h               ;
        ret                     ; get outta here

;
; memset
; set a buffer to a fixed byte value.
; IN:
;       b byte value to set buffer to
;       D/E count of bytes to set
;       H/L buff
memset:
        push    h               ;
        push    b               ;
        push    d               ;
        mov     a,d             ; get upper byte of count
        ora     e               ; or it with lower byte
mstloop:
        jz      mstdone         ; done setting, cleanup and return
        mov     m,b             ; set addr to desired value
        inx     h               ; next buffer address
        dcx     d               ; decrement copy count
        mov     a,d             ; get upper byte of count
        ora     e               ; or it with lower byte, sets Z flag
        jmp     mstloop
mstdone:
        pop     b               ;
        pop     d               ;
        pop     h               ;
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
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
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
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
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
        mvi     m,01bh          ; start
        inx     h               ;  building
        mvi     m,'['           ;   an
        inx     h               ;    ANSI
        mvi     m,'2'           ;     escape
        inx     h               ;     sequence
        mvi     m,'K'           ;    to clear
        inx     h               ;   currrent line
        mvi     m,'$'           ; ^[2K
        mvi     c,strout        ; send it to the console
        lxi     d,esctmp        ;
        call    sys             ;
        pop     h
        pop     d
        call    setcur          ; replace the cursor
        ret

;
; perr
; Print error message in flower box.  One line of message
; IN:
;       D/E - address of error message
perr:
        push    b               ;
        push    h               ;
        push    d               ;
        mvi     d,5             ; line 5
        mvi     e,16            ; column 17
        mvi     a,5             ; 4 blank lines
        call    flower          ; draw a flower box
        mvi     d,7             ; line 7
        mvi     e,24            ; column 24
        call    setcur          ; put cursor there
        lxi     d,uibold        ; make next text BOLD
        mvi     c,strout        ; print
        call    sys             ; syscall
        pop     d               ; get user's message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        lxi     d,uireset       ; back to normal text
        mvi     c,strout        ; print
        call    sys             ; syscall
        mvi     d,8             ; line 7
        mvi     e,28            ; column 28
        call    setcur          ; put cursor there
        lxi     d,contmsg       ; "Press any key"... message
        mvi     c,strout        ; print it
        call    sys             ; syscall
        mvi     c,conin         ; wait for key keypress
        call    sys             ; syscall
        pop     h               ;
        pop     b               ;
        ret

;
; clrtags
; Clear all tags
clrtags:
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
        lxi     h,tags          ; get the array of tags
        lxi     d,tagcnt        ; number of bytes
        mvi     b,0             ; zero to reset them all
        call    memset          ; reset them
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
        ret

;
; settags
; Set all tags
settags:
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
        lxi     h,tags          ; get the array of tags
        lxi     d,tagcnt        ; number of bytes
        mvi     b,0ffh          ; 0xff to reset them all
        call    memset          ; set them
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
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
        lxi     d,schfcb        ; set D/E to search value for find first (src)
        lxi     h,fcb1          ; set H/L to file control block 2 (dst)
        lxi     b,fcblen        ; set B/C to byte count to copy
        call    memcpy          ; this sets up fcb1 with generic format
        mvi     c,getdsk        ; get current disk number (A=0, etc)
        call    sys             ; ask CP/M for it, return in A
        inr     a               ; A=1
        sta     fcb1            ; first byte of fcb is drive number
        call    setfptr         ; flposn is now set to start of filename
        lhld    flposn          ; start of selected filename
        xchg                    ; exchange value between H/L and D/E
        lxi     h,fcb1+1        ; start of FCB
        lxi     b,fnlen         ; 11 bytes in filename
        call    memcpy          ; copy filename into fcb1]
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
        ret

;
; first
; get first file FCB in directory
; RETURNS:
;       A - result (0xff if no file found)
;       B/C pair - address of file control block
;
first:

        lxi     d,schfcb        ; set D/E to search value for find first (src)
        lxi     h,fcb1          ; set H/L to file control block (dst)
        lxi     b,fcblen        ; length of one fcb
        call    memcpy          ; copy search value to FCB1
        mvi     c,getdsk        ; get currently logged-in disk
        call    sys             ; syscall
        inr     a               ; drive A=1, etc.
        lxi     d,fcb1          ; fcb in D/E for syscall
        sta     fcb1            ; drive is first byte in FCB:
        mvi     c,srchf         ; search first file function
        call    sys             ; call CP/M, result in A
        cpi     255             ; compare to 0xff - no file found
        rz                      ; no file was found
        rlc                     ; result in A is muliplied by 32 to get actual FCB addr
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
        rlc                     ; result in A is muliplied by 32 to get actual FCB addr
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
        mov     d,b             ; B/C to
        mov     e,c             ; D/E
        lhld    flposn          ; load value at flposn into H/L (dst)
        lxi     b,fnlen         ; set copy len to be 8+3 (file name + ext in FCB)
        call    memcpy          ; copy filename to buffer
        lhld    flposn          ; get the buffer pointer again
        lxi     b,fnlen         ; load B/C with data struct length
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
        mov     d,b             ; move B/C
        mov     e,c             ; D/E
        lhld    flposn          ; get next address of filename buffer into H/L
        lxi     b,fnlen         ; set copy len to be 8+3 (file name + ext in FCB)
        call    memcpy          ; copy filename to buffer
        lhld    flposn          ; get the buffer pointer again
        lxi     b,fnlen         ; load B/C with filename length
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
        mvi     a,4             ; 3 blank lines
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
        lxi     h,0             ; zero it
        lxi     d,flist         ; start of filename list buffer in D/E
        dad     d               ; set flposn pointer to be start of buffer
        lxi     d,fnlen         ; load D/E with 11 struct len
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
; stored in variable FLSEL.  CP/M stores files
; with spaces and no 'dot'; for example:
;   >FILE    TXT<
; This routine will print that as >FILE.TXT<
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
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
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
        call    pchar           ;  [ ]
        mvi     a,' '           ;   to terminal
        call    pchar           ;    to hold
        mvi     a,']'           ;   an 'X'
        call    pchar           ;  indicating tag status
        call    prnname         ; print filename
        lda     flsel           ; get selected file number
        inr     a               ; and increment it
        sta     flsel           ; save it
        mov     a,e             ; get column start
        adi     dspace          ; increment for next column of files to the right
        mov     e,a             ; save it for now
        cpi     dsmax           ; did we increment into column 6?
        jm      fndlp1          ; nope, this is column 5 or less
        mvi     e,1             ; start over at column 1
        inr     d               ; next row
fndlp1:
        dcr     c               ; decrement file count, sets Z flag
        jnz     fndlp           ; go do next
fnddone:
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
        ret                     ; all done

;
; listfls
; List all files on logged drive, resets counters, etc.
;
listfls:
        call    cls             ; clear
        call    enumdir         ; get the listing for the logged drive
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
        push    psw             ;
        push    b               ;
        push    d               ;
        push    h               ;
        mvi     d,1             ; new cursor position, line 1
        mvi     e,16            ; column 16
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
        lxi     d,uireset       ; clear formatting
        mvi     c,strout        ; print
        call    sys             ; print it
        mvi     d,21            ; go to line 21
        mvi     e,1             ; column 1
        call    rstline         ; clear line
        lxi     d,uistr2        ; second UI line
        mvi     c,strout        ; print string
        call    sys             ; let cpm print it
        pop     h               ;
        pop     d               ;
        pop     b               ;
        pop     psw             ;
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
delser  db      'Tag one or more files for deletion!$'
cpyser  db      '   Tag one or more files to copy!$'
cpyeer  db      '  DESTINATION FILE ALREADY EXISTS!$'
cpysr1  db      '    UNABLE TO OPEN SOURCE FILE!$'
cpyder  db      '  UNABLE TO OPEN DESTINATION FILE!$'
badfnm  db      '          BAD FILE NAME$'
logerr  db      '     DISK x: IS NOT AVAILABLE!$'
cpyok   db      ' blocks copied.$'
contmsg db      'Press any key to continue$'
delmsg  db      'Delete file $'
cpymsg1 db      'Copy file $'
cpymsg2 db      'Enter new filename> $'
uichyn  db      ' (Y/N)? $'
uichyna db      ' (Y/N/A)? $'
logmsg  db      'Select new disk letter: $'
schfcb  db      0,'???????????',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
blnkfcb db      0,'           ',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
mworkng db      'Enumerating files in drive $'
help1   db      'STEM - a basic file manager for CP/M 2.2 on Altair 8800',CR,LF,CR,LF,'$'

;***************************************************
; START OF VARIABLE DATA AREA
;***************************************************
orgstk  ds      2               ; original stack pointer
dpbase  ds      2               ; Disk Parameter Base address
usrfnm  ds      fnlen+1         ; user entered filename buffer
fcb2    ds      fcblen+1        ; another FCB for file operations
allflag ds      1               ; flag to indicate "ALL" files
eofflag ds      1               ; last read was EOF
fcount  ds      1               ; file count addr
flsel   ds      1               ; selected file number
flwrtmp ds      1               ; temporary storage for flower box
drvtmp  ds      1               ; drive letter storage during drive change
blkcnt  ds      2               ; generic block counter
tmpmsg  ds      36              ; temp message buffer
usrinp  ds      uinplen         ; user input buffer
flposn  ds      2               ; position in file name array
flist   ds      (maxfls*fnlen)+1; area for list of filenames
tags    ds      tagcnt          ; bitmap of tagged files
esctmp  ds      24              ; temp area for building escape sequences
stkcny  ds      4               ; stack canary
usrstk  ds      64              ; 32 level stack
newstk                          ; top of newstk area

        end
