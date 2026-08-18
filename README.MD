# Altair 8800 File Manager
When I was a DOS user, the one main killer application that I used day to day was XTreeGold.  I thought I'd try to write one for CP/M in 8080 assembler.

The program name is `STEM` because CP/M doesn't have subdirectories, to anything with "tree" in the name would be kind of dumb.

## Status
As of right now, it'll just list the files in the current logged drive

### Assembling
This is written to run in `CP/M 2.2`. A disk image with CP/M, the assembler, debugger, editor, and everything else that's needed is provided on the SD card for the A-D.  Note: [SD card image can be found here](https://adwaterandstir.com/instructions/)

Follow the A-D instructions on mounting the CP/M disk and booting CP/M itself.  From there, one can either type in the whole program by hand or transfer by `XMODEM` or other method to the disk.

There should be just one file starting with `STEM` on the disk:
```  
D>dir stem.*
D: STEM     ASM
D>
```  

Once there, assemble it using `asm`:
```  
D>asm stem
CP/M ASSEMBLER - VER 2.0
0670
005H USE FACTOR
END OF ASSEMBLY
```   
The assembler finished with no errors - yay!!  There are two new files on the disk: `stem.prn` and `stem.hex`:
```  
D>dir stem.*
D: STEM     ASM : STEM     PRN : STEM     HEX
D>
```  
`stem.prn` is the "printer" output from the assembler.  It is the output of the assembler listed with the original source - this is like a listing file from a c compiler. 

`stem.hex` is an Intel hex file of the memory image of the assembled program.  Same kind of thing that a microcontroller cross compiler will generate for loading into Flash memory.

### Creating a loadable image
The `stem.hex` could be run in the `ddt` debugger, but let's just create the executable image so it can be run from the command line:
```  
D>load stem

FIRST ADDRESS 0100
LAST  ADDRESS 044D
BYTES READ    034E
RECORDS WRITTEN 07
```  
Now there is another file in the directory:
```   
D>dir stem.*
D: STEM     ASM : STEM     PRN : STEM     HEX : STEM     COM
D>
```  
`stem.com` is the executable image of the program!
### Running the program
We now have an executable that can be called from the command line like any other program: 
``` 
D>stem
``` 
The screen will be cleared and the welcome message shown:
```

               Altair 8800 File Manager
            2026 Mattydyne Heavy Industries

          "H" for help, any other key to start

```
Pressing any key will load the directory of the current drive:
```
Enumerating files in drive X

ASM     .COM
DEMO    .ASM
DEMO    .COM
CLEAR   .ASM
L80     .COM
LOAD    .COM
M80     .COM
MAC     .COM
GF      .TXT
STEM    .ASM
STEM    .PRN
STEM    .HEX
STEM    .COM

All done!  Final file count: 13

D>
```
