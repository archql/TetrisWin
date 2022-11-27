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
 - special . . . . . . . . . . . . . . . . ENTER (costs 100 score, use is not recommended)
 

### NICKNAME CONTROLS:
 to activate edit mode &mdash; hold CTRL
 with all keys pressed
 - write . . . . . . . . . . . .  A..Z
 - move left . . . . . . . . <
 - move right  . . . . . .  > 
 - rm symbol  . . . . . . . BACKSPACE
 - accept changes . . . ENTER
 
 **unchangable** when:
 - client is in REGSTRD state
 - game started and score is not zero
 - *in theory* nicknames can use first 128 ANSI symbols, 
	but support of such nicknames is *not guaranteed*! 
 
#### LEADERBOARD INFORMATION:

- Leaderboard isn't updated automatically. Use **R** key to do so (restarts entire gameplay).
- Leaderboard *holds up to 16 records sorted* by score.
- Leaderboard record *place displayed as hex number* prefixed with '#'
- All records displayed with white color
- Record which belongs to current user is *highligted in yellow* color 
- *##* place for current user means the place number is greater than 0x0F (16)
 
### NETWORK MODE (v5.+)

 - Network gameplay works only in LAN.
 - You can use software that creates virtual LAN.
 - To work with network app uses UDP port 7000. 
 - App uses special prefixes for messages to differ them.
 
#### Client has 5 states:
 - OFFLINE &mdash; client isn't connected to network.
 - ON-LINE &mdash; client is connected to network, but registration isn't completed.
 - REGSTRD &mdash; client is registered in network and now can send & recieve all nessesary messages
 - REJCTED &mdash; client tried to connect to LAN, which already has client with same nickname connected.
 - UUIDERR &mdash; client tried to read UUID of your machine and its failed. Equals OFFLINE mode except you can not use online features.
 
#### Connection algorithm:
 - **Use *F3* key to make try to connect to LAN** (your current state is *OFFLINE*). If it's worked properly your state is *ON-LINE*. 
 - Next client sends register message and waits (cur 500 ms). If your next state is *REGSTRD* everything went good!
 - If you got *REJCTED* state &mdash; change you nickname & try to connect again (use **F3** key).
 - LAN connection is also used for leaderboard update.

 - You can still get file updates if your state is *REJCTED*.
 - From version 5.9 Online Game View (OGV) is added. Every client in the same LAN sends its game frame with ping message. 
 - Other clients display them.
 
#### Competition game mode start algorithm:
 - **competition game mode** ensures that clients which started it will have same random seed 
 - use **F4** key to start. Game starts only if client has *GAME OVER* and *REGSTRD* state **for every client in the LAN!**
 
#### Other network facts:
 
 - To control clients online ping messages used. If client got such message it checks it's nickname
 registers it and set timeout value (cur 10 \* 200 ms = 2 s).
 - Ping message sends every 200 ms. Client checks all ping records also every 200 ms.
 
 - If timeout value became 0, client removes corresponding ping record.
 
 - if you have *REJCTED* state - change your nickname and retry (use F3 key).
 - you will recieve leaderboard updates even in *REJCTED* state.
 - Ping messages contains full game frame so your game can be visualized remotely with 200 ms precision.
 - To protect from clients with same name connection machine UUID used.
 - There is possible to remote control your gameplay from another computer connected to same LAN (and gameplay only).
 - **WARNING. UDP protocol do not guarantes message delivery!**
 
### GRAPHICS

 - graphics is fully based on OpenGL
 
### MUSIC

 - music is based on winmm lib and windows emulation of MIDI.
 - music consists of 2 parts - *background* and *effect*
 - *background* music is included to the exe (1811 bytes) and its volume be controlled
 - *background* music enables when game session is running
 - *effect* music have different kinds and conditions for it
 - *effect* music volume cant be changed
 - *effect* music includes:
   - game end effect (2 \* 4 piano sounds emmited in the game end)
   - line clear effect (4 piano sounds emmited when line is cleared)
  additionally 'tetris' plays bang sound.
   - collided effect emmited figure is finally collided with game field and is no longer movable.
   - key press effect emmited with basically any game changing key press
   
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
 
