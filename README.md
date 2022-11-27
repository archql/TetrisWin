# TetrisWin
This is my implementation of famous tetris game on fasm. But for windows ;). Now everybody can simply run it on Windows 10!
There I used some materials from my laborotory works done while studying at BSUIR. Also this is my coursework.
Logics is fully based on my previous tetris variant, see https://github.com/archql/tetris-fasm repo.
To work properly, its requires several fasm .inc files (they are not mine; find them in ..\fasm folder in the (for example) https://github.com/Konctantin/FASM or just google it). 
To compile it requires fasm.
Graphics based on OpenGL.
All rectangular screen resolutions supported (at least for gameplay).

## For users

### SUPPORTED VERSIONS

- This version tested on Windows 11, Windows 10, Windows 7 and Windows XP. 
- Windows XP requires additional check.
- Windows 11 fails.

#### INSTALLATION:
- [if required] change extension .notexe to .exe (.notzip to .zip and unpack)
- place .exe in any folder (preffered empty and not system-protected)
- read agreement.txt before use
- its all!

#### WARNING!
 if somebody want to use this app
 antiviruses dont like asm programms, especcially when code section is writable (its to reduce size)

### CONTROLS:
 - move left . . . . . . . . . . . . .  <
 - move right . . . . . . . . . . . . > 
 - rotate clockwise . . . . . . .  ^
 - move anticlockwise . . . .  v
 - quit . . . . . .  . . . . . . . . . . . . ESC
 - hard drop . . . . . . . . . . . . . SPACE
 - soft drop . . . . . . . . . . . . . . SHIFT
 - pause . . . . . . . . . . . . . . . . . P
 - restart  . . . . . . . . . . . . . . . . R
 - hold . . . . . . . . . . . . . . . . . . H
 - mute music . . . . . . . . . . .  M
 - increase volume . . . . . . .  ']'
 - decrease volume . . . . . . . '\['
 
### GRAPHICS

 - graphics is fully based on OpenGL
   
## For developers

#### What is '.amid' files?
'.amid' file &mdash; its file with short midi messages, every message is 4 bytes long,
 format is control + track num byte ,note_num byte, note_velocity byte, zero byte (now delay to next note in ms / 2)
 This file is generated using my another progmam, written on delphi,
 that converts notes into midi messages.
 
New version (Extended '.amid', _Ex ) removes 2 elder bytes, and delay is placed as last byte in pack of midi messages).

Super extended '.amid' file ( _SEx ) holds only one byte per note. 7 low bits is note num & 1 hi bit defines to play note or mute.
 Quality of this kind of file is lower.

Compressed super extended  '.amid' file ( _CSEx ) holds only one byte per note and doesnt hold any info about bitrate. 
 All notes played with same delay.
 
 
#### What is '.ttr' files?
'.ttr' file &mdash; its tetris record file with max score. Its name can be only 8 bytes long and responses for nickname of a player.

New version also encrypted and holds full game frame information.
This information is enough to restore game process without any additional information or files. 
Old '.ttr' files unsupported in new versions.
New '.ttr' files supported in old versions (But they are readonly).

'.ttr.tmp' file is same format file as '.ttr' file. But it used to save gameplay of a player.

Now executable file size is 10kBytes.
Network executable file size is 12kBytes.

There is minimal version with size 8kBytes.

#### if you use code from here - please mention autor @archql

#### WARNING!
 if somebody want to test or play this tetris
 antiviruses dont like asm programms, especcially when code section is writable (its to reduce size)
 
