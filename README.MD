# STEM - an Altair 8800 File Manager
This project is a file manager for an Altair 8800 running CP/M 2.2.  

By file manager, I mean something like XTreeGold, Midnight Commander, etc.; a text interface based utility to list files on disks and perform operations such as copy, delete, display and rename.  Of course, there are CP/M "built-in" commands to do most of these things, and `PIP` to do the rest, but I miss my days of XTree on DOS.

The program name is `STEM` because CP/M doesn't have subdirectories, so anything with "tree" in the name would be kind of dumb :)

## Status
This is a work in progress and definitely not ready for primetime.  It is not feature complete.  Contributions are great!  Here are a couple of ways:
* Fork this repo, do some coding, and submit a PR.  *(A PR that includes any code produced by any kind of LLM/coding agent will be rejected.  Even the most insignificant bit of that crap will be thrown out.  Sorry, my repo, my rules.)*
* Try the program out and submit any issues you may find.  Please include as much detail as possible.

## About the program
The program was written from scratch in 8080 assembly language.  All file I/O is handled by syscalls to CP/M; because of that, the program *should* work on any computer with an 8080 or Z80 CPU that is running CP/M 2.2, but I really can't guarantee that :/

The main reference materials used in the development were the CP/M 2.2 and Intel 8080 System manuals.  I started writing it using `ED` on an Altair-Duino retro kit, but it got to be a bit too much as the filesize grew over 30K.  The rest was done using the Zed editor, transferring the source file to the computer using `XMODEM`.  Once there, it was assembled and tested/debugged.

Why write a new program in 8080 Assembly by hand in this era?  Because it's been a while since I wrote anything of consequence in Assembly.  Because I find it kind of fun, and it keeps my skills sharp.  Also, it's my small way of pushing back against "modern" languages and development where one must download and link 37 libraries to produce a 13MB "Hello World!" program.

I did consider C, a language I have a lot of professional experience with, but in the end went with Assembly.  It was a nice clean toolchain to be able to use just the assembler and `DDT` debugger to produce a program.

When writing the program, I spent a lot of time trying to be sure to accurately and concisely document the code as I went.  My hope is that it helps others who want to learn Assembly.  Skilled Assembly users will see optimizations and shortcuts I could have taken, but I skipped a lot of that in favor of more clarity.

Another reason to use Assembly in the modern era: if you are ever thinking about getting into reverse engineering, security research, malware analysis, or Embedded/IoT/IIoT development you may be exposed to Assembly at some point.  Whether it's decompiled output in Ghidra or reading through a `.lst` file looking for optimizations, having some experience with Assembly will give you a good leg up.

Final note:  **No LLM, coding agent, vibe, or other "AI" crap was or ever will be used in this project.  I have no desire to be around any of that clanker garbage.**

### Building/installation
There are a few ways to get the program:  
* Print out the source listing and type it in by hand.  Just like we did as kids, hand-typing in programs from magazines and books.  While it was a great way to learn, I really don't expect anyone to do that.
* Transfer the source file to either a software Altair emulator, a hardware retro kit, or the real thing if you're lucky enough to have access to one.  There are a variety of ways to do that, see your docs.  Once there:
  1) Assemble the program using CP/M's `asm` program.  Command line and output would be something like this (drive letters most likely different, etc.):
        ```
        D>b:asm stem
        CP/M ASSEMBLER - VER 2.0
        12CB
        00DH USE FACTOR
        END OF ASSEMBLY
        ```
  1) Then use `load` to create loadable executable image:
        ``` 
        D>b:load stem
        
        FIRST ADDRESS 0100
        LAST  ADDRESS 0F01
        BYTES READ    0E02
        RECORDS WRITTEN 1D
        ```
        This process is almost instantaneous on a software-simulated Altair running on modern hardware.  On Altair-Duino hardware with disk I/O set to "real time", the build process will take several minutes!  Grab a coffee and enjoy the Blinkenlights :)
* The last way is to download the latest build from the Releases of this repo.  That will be a zip archive with the latest `.com`, `.prn`, and `.hex` files.  The `hex` and `prn` files are included in case you want to use `DDT` to debug and explore program execution.  *Note - Releases will be produced once the project is a little further along*.

## Requirements
The basic requirements are:
* An Altair 8800 computer, a retro kit, or software emulator.  Also an IMSAI and possibly other 8080/Z80 computers running CP/M 2.2.  I have only used an Altair retro clone kit, so your mileage may vary.  I would be interested in hearing about experiences with other machines.  
* It should run comfortably in anything with 20KB of RAM or greater (although I have not built it on a machine with less that 64K)
* One or more disk drives (real or logical/virtual/emulated)
* CP/M 2.2, including `ASM.COM` and `LOAD.COM` if building from source
* A display that is VT-100 capable.  The program makes a lot of use of escape sequences to control cursor position and other screen details.
  * The program is written assuming an 80x24 character display.  Using a narrower display will look goofy
  * It works well over a serial link to Linux/MacOS running a command line terminal program like `minicom`.  I have no idea how it runs under Windows.  Last I remember, Windows cmd.exe didn't recognize escape sequences, but maybe it'll work under PuTTY or something like that.

Most of the development has been done an Altair-Duino 8800 Experimenter kit from [Adwater & Stir](https://adwaterandstir.com/altair/).  They produce a great kit that's fun and easy to build and has an excellent online community.  

At times, I used a [docker-based emulator](https://gloveboxes.github.io/Altair-8800-Emulator/); mostly when I was away from my desk where the A-D sits.  It's a solid and easy to use emulator, but I strongly dislike that project's push of vibe coding/AI.  Just my opinion and preference.

## Running the program
From the command line, run `STEM`.  The program will show the greeting information and then will load and display the files on the current disk.  At the bottom of the display are two lines, the first showing the currently selected file and the second showing the available commands:
![listing](/img/stem2.png)

*Note - commands can be entered in upper or lower case*
### Navigating files
As the first line hints at, pressing the `N` and `P` keys will move the next and previous file in the listing.  The current filename will be shown at the end of the "Currently selected file" line.

### Tagging files 
Commands are performed on "tagged" files.  Pressing the space bar will either "tag" or "untag" the selected file.  For example, `DEMO.ASM` and `M80.COM` have been "tagged":
```
              Listing of drive D: (total of 13 files, 2  tagged)

[ ]ASM.COM      [X]DEMO.ASM     [ ]DEMO.COM     [ ]CLEAR.ASM    [ ]L80.COM
[ ]LOAD.COM     [X]M80.COM      [ ]MAC.COM      [ ]GF.TXT       [ ]STEM.ASM
[ ]STEM.PRN     [ ]STEM.HEX     [ ]STEM.COM
```
### Deleting files
Once one or more files are tagged, pressing the `D` key.  A popup will prompt for confirmation of deletion.  Select `A` will delete the rest of the tagged files without prompt
```
              Listing of drive D: (total of 13 files, 2  tagged)

[ ]ASM.COM      [X]DEMO.ASM     [ ]DEMO.COM     [ ]CLEAR.ASM    [ ]L80.COM
[ ]LOAD.COM     [X]M80.COM      [ ]MAC.COM      [ ]GF.TXT       [ ]STEM.ASM
[ ]STEM.PRN    +--------------------------------------------------+
               |                                                  |
               |         Delete file M80.COM (Y/N/A)?             |
               |                                                  |
               +--------------------------------------------------+

```
After deletion, the file list will be reloaded:
``` 
              Listing of drive D: (total of 11 files, 0  tagged)

[ ]ASM.COM      [ ]DEMO.COM     [ ]CLEAR.ASM    [ ]L80.COM      [ ]LOAD.COM
[ ]MAC.COM      [ ]GF.TXT       [ ]STEM.ASM     [ ]STEM.PRN     [ ]STEM.HEX
[ ]STEM.COM
```
