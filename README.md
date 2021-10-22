# TetrisWin
This is my implementation of famous tetris game on fasm. But for windows ;). Now everybody can simply run it on windows 10! (windows 7,8,xp isn't tested yet)
There I used some materials from my laborotory works in 2nd and 3rd terms in BSUIR. Also this is my coursework.
Logics is fully based on my previous tetris variant, see https://github.com/archql/tetris-fasm repo.
To work properly, its requires proc32.inc file (into fasm\include\macro folder). 
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
 - force push down    -- SPACE
 - pause              -- P
 - restart            -- R
What is '.amid' files?
'.amid' file -- its file with short midi messages, every message is 4 bytes long,
format is control + track num byte ,note_num byte, note_velocity byte, zero byte (now delay to next note in ms / 2)
This file is generated using my another progmam, written on delphi,
that converts notes into midi messages.

 
