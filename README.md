# TetrisWin
This is my implementation of famous tetris game on fasm. But for windows ;). Now everybody can simply run it on windows 10! (windows 7,8,xp isn't tested yet)
There I used some materials from my laborotory works in 2nd and 3rd terms in BSUIR. Also this is my coursework.
Logics is fully based on my previous tetris variant, see https://github.com/archql/tetris-fasm repo.
To work properly, its requires proc32.inc file (see ..\fasm\include\macro folder). 
To compile it requires fasm.
This tetris version tested on Windows 10. 
Graphics based on OpenGL lib.
All rectangular screen resolutions supported.

CONTROLS:
 - move left          -- <
 - move right         -- > 
 - rotate clockwise   -- ^
 - move anticlockwise -- v
 - quit               -- ESC
 - hard drop          -- SPACE
 - soft drop          -- SHIFT
 - pause              -- P
 - restart            -- R
 - hold               -- H
 - mute music	      -- M
 - increase volume    -- ']'
 - decrease volume    -- '\['
NICKNAME CONTROLS:
 to activate edit mode -- hold CTRL
 with all keys pressed
 - write			  -- A..Z
 - move left          -- <
 - move right         -- > 
 - rm symbol          -- BACKSPACE
 - accept changes     -- ENTER

What is '.amid' files?
'.amid' file -- its file with short midi messages, every message is 4 bytes long,
 format is control + track num byte ,note_num byte, note_velocity byte, zero byte (now delay to next note in ms / 2)
 This file is generated using my another progmam, written on delphi,
 that converts notes into midi messages.
 New version (Extended '.amid', _Ex ) removes 2 elder bytes, and delay is placed as last byte in pack of midi messages)
Super extended '.amid' file ( _SEx ) holds only one byte per note. 7 low bits is note num & 1 hi bit defines to play note or mute.
 Quality of this kind of file is lower.
Compressed super extended  '.amid' file ( _CSEx ) holds only one byte per note and doesnt hold any info about bitrate. 
 All notes played with same delay.
 
What is '.ttr' files?
'.ttr' file -- its tetris record file with max score. Its name can be only 8 bytes long and responses for nickname of a player.
New version also encrypted and holds all game frame information.
This information is enough to restore game process. 
Old '.ttr' files unsupported in new versions.
New '.ttr' files supported in old versions (But they are readonly).
'.ttr.tmp' file is same format file as '.ttr' file. But it used to save gameplay of a player.

Now executable file size is 10kBytes.

There is minimal version with size 8kBytes.

 WARNING!
 if somebody want to test or play this tetris
 antiviruses dont like asm programms, especcially when code section is writable (its to reduce size)
 
