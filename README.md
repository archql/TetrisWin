# TetrisWin
This is my implementation of famous tetris game on fasm. But for windows ;). Now everybody can simply run it on Windows 10 & Windows 7! (Windows 8,XP isn't tested yet, Windows 2000 isn't supported)
There I used some materials from my laborotory works in 2nd and 3rd terms in BSUIR. Also this is my coursework.
Logics is fully based on my previous tetris variant, see https://github.com/archql/tetris-fasm repo.
To work properly, its requires proc32.inc file (see ..\fasm\include\macro folder). 
To compile it requires fasm.
This tetris version tested on Windows 10 & Windows 7. 
Graphics based on OpenGL lib.
All rectangular screen resolutions supported.

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
 

### NICKNAME CONTROLS:
 to activate edit mode &mdash; hold CTRL
 with all keys pressed
 - write . . . . . . . . . . . .  A..Z
 - move left . . . . . . . . <
 - move right  . . . . . .  > 
 - rm symbol  . . . . . . . BACKSPACE
 - accept changes . . . ENTER
 
#### NETWORK CONTROLS:
 Network connection works only in LAN mode.
 You can software that creates virtual LAN.
 To work with network app sends UDP packets to port 7000. 
 It uses special prefixes for messages to differ them.
 For now there is 2 types of prefixes &mdash; Client & Control.
 I'm going to create tetris API with all information
 about network packets and their formats.
 
**Client has 5 states**:
 - OFFLINE &mdash; client isn't connected to network.
 - ON-LINE &mdash; client is connected to network, but registration isn't completed.
 - REGSTRD &mdash; client is registered in network and now can send & recieve all nessesary messages
 - REJCTED &mdash; client tried to connect to LAN, which already has client with same nickname connected.
 - UUIDERR &mdash; client tried to read UUID of your machine and its failed. Equals OFFLINE mode except you can not use online features.
 
 **Use *F3* key to make try to connect to LAN** (your current state is OFFLINE). If it's worked properly your state is ON-LINE. 
 Next client sends register message and waits (cur 500 ms). If your next state is REGSTRD everything went good!
 If you got REJCTED message &mdash; change you nickname & try to connect again (use **F3** key).
 LAN connection currently used for update leaderboard and synhro game start on same seed (use **F4** key to start. Game starts only if client has GAME OVER mode).
 Leaderboard isn't updated automatically. Use **R** key to do so.
 You can still get file updates if your state is REJCTED.
 From version 5.9 added Online Game View (OGV). Every client in the same LAN sends it game frame with ping message. 
 Other clients displays them.
 To swap Menu #1 (Leaderboard) and Menu #2 (OGV) use **F2** key.
 
 To protect from clients with same name connection machine UUID used.
 
 There is possible to remote control your gameplay from another computer connected to same LAN.
 
 To control clients online ping messages used. If client got such message it checks it's nickname
 registers it and set timeout value (cur 10 \* 200 ms = 2 s).
 
 Ping message sends every 200 ms. Client checks all ping records also every 200 ms.
 
 If timeout value became 0, client removes corresponding ping record.
 
 Ping messages contains full game frame so your game can be visualized remotely with 200 ms precision.

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

#### WARNING!
 if somebody want to test or play this tetris
 antiviruses dont like asm programms, especcially when code section is writable (its to reduce size)
 
