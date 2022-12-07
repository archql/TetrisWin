# TetrisWin
This is my implementation of famous tetris game on fasm. But for windows ;)
There I used some materials from my laborotory works done while studying at BSUIR. Also this is my coursework.
Logics is fully based on my previous tetris variant, see https://github.com/archql/tetris-fasm repo.

## For users

### SUPPORTED VERSIONS

- This version tested on Windows 11, Windows 10, Windows 7 and Windows XP. Windows XP requires additional check.
- All rectangular screen resolutions supported (at least for gameplay).

#### INSTALLATION:
- [if required] change extension .notexe to .exe (.notzip to .zip and unpack)
- place .exe in any folder (preffered empty and not system-protected)
- read agreement.txt before use
- its all!

#### WARNING!
 if somebody want to use this app
 antiviruses dont like asm programms, especcially when code section is writable (its to reduce size)

### CONTROLS
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
 
 - To swap Menus use **F2** key.
 - To swap textures use **F5** key.

#### NICKNAME CONTROLS:
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
 
#### (6.+)
 - by default, client displays 3D using colored cubes
 - cubes can be textured by placing *\*.bmp* files with *any* name to the folder with game
 - **WARNING! BMP must be R8 G8 B8 formatted and its size less than 100 kB!**
Other sizes are not guarantied to work! Possible outcome is game crash
 - client will use BMP files automatically when they are presented
 - you can place multiple BMPs to the game folder and swap them with **F5** key
 - game field can be rotated by mouse wheel along Z axis (X axis if ctrl key holded).
 
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
 
#### (6.+)
 - by default, all music is midi messages
 - *effect* music can be changed by placing *\*.wav* files with *special* name to the folder with game
 - *special* name must be formatted as midi hex code text prefixed with '#' symbol and postfixed with '.wav' 
 - now (v6.4) game end, line clear and bang sounds are replaceable
 
#### Replaceable music messages (v6.4+)
 - All files must be in .wav format (file constists of name listed below postfixed with .wav)
 - end game event is played one from 4 presented randomly
 - additionally sound played changes texture to one which name formatted as midi hex code text 
 prefixed with '#' symbol and postfixed with '.bmp' (if such image presented) 
 - What? - When? 
   - #7F2C93 - 1 line cleared
   - #7F3093 - 2 lines cleared
   - #7F3493 - 3 lines cleared
   - #7F3893 - 4 lines cleared
   - #7F2594 - bang sound when 4 lines cleared (conflicts with previous)
   - #7F2690 - end game event 1 (on loose)
   - #7F2290 - end game event 2 (on loose)
   - #7F1E90 - end game event 3 (on loose)
   - #7F1A90 - end game event 4 (on loose)
 
 
## For developers

### Build & compile
To build properly, its requires several fasm .inc files (they are not mine; find them in ..\fasm folder in the (for example) https://github.com/Konctantin/FASM or just google it). 
To compile it requires fasm.
Graphics based on OpenGL.

### What is '.amid' files?
'.amid' file &mdash; file with short midi messages, every message is 4 bytes long,
 format is control + track num byte ,note_num byte, note_velocity byte, zero byte (now delay to next note in ms / 2)
 This file is generated using my another progmam, written on delphi,
 that converts notes into midi messages.
 
New version (Extended '.amid', _Ex ) removes 2 elder bytes, and delay is placed as last byte in pack of midi messages).

Super extended '.amid' file ( _SEx ) holds only one byte per note. 7 low bits is note num & 1 hi bit defines to play note or mute.
 Quality of this kind of file is lower.

Compressed super extended  '.amid' file ( _CSEx ) holds only one byte per note and doesnt hold any info about bitrate. 
 All notes played with same delay.
 
 
### What is '.ttr' files?
'.ttr' file -- its tetris record file with max score. Its name can be only 8 bytes (extension excluded) long and represents nickname of a player.

New version also encrypted and holds full game frame information.
This information is enough to restore game process without any additional information or files. 
Old '.ttr' files unsupported in new versions.
New '.ttr' files supported in old versions (But they are readonly).

'.ttr.tmp' file is same format file as '.ttr' file. But it used to save gameplay of a player.

Now (release v6.+) executable file size is 16kBytes.
Network (release v5.+) executable file size is 12kBytes.

There is minimal release with 8kBytes size.

### Net protocol (5.+)

 - net packet starts with 2 bytes of message code and other data which depends on game version and message
 - processing logics is:
 When message is recieved its number is checked along with the details of the sender and recipient. This is necessary due to the peculiarity of UDP broadcast packets distribution namely they also recieved by the device from which they were sent ("self-sending"). However, due to the possible presence of a large number of network adapters in the single device there may be duplicated "self-sended" packets. Therefore, there are messages processing which do not accept "self-sending" (named public-only); messages that need it (named global); messages that need it but in a single copy (named public). 
 - current structure can be located in the 'tetrisdata.asm'
 - current protocol (v.6.4) message codes are:
 - MESSAGE CODES
   - MSG_CODE_BASE_PROXY             = $F000
   - MSG_CODE_KEYCONTROL             = 1 + MSG_CODE_BASE_PROXY
   - MSG_CODE_PROXY                  = 2 + MSG_CODE_BASE_PROXY
   - MSG_CODE_BASE_CLIENT            = $A000
   - MSG_CODE_REGISTER               =   1 + MSG_CODE_BASE_CLIENT
   - MSG_CODE_REQ_TTR                =   5 + MSG_CODE_BASE_CLIENT
   - MSG_CODE_TTR                    =   6 + MSG_CODE_BASE_CLIENT
   - MSG_CODE_RG_REJECTED            =   7 + MSG_CODE_BASE_CLIENT
   - MSG_CODE_START_GAME             =   8 + MSG_CODE_BASE_CLIENT
   - MSG_CODE_PING                   = $FF + MSG_CODE_BASE_CLIENT
   - MSG_CODE_BASE_CHAT              = $B000
 - MESSAGE LOGICS
   - MSG_REGISTER - is a public-only broadcast message. Contains the details of the client who wants to register. Client which are registered in the network earlier check if the credentials of the new client do not contradict their own. Because the name must be unique the client sends back a MSG_RG_REJECTED message.
   - MSG_RG_REJECTED - is a direct message containing only the code and attributes if there is a conflict. A client which received this message in ON-LINE state enters REJCTED state.
   -	MSG_TTR – is a public-only message. Contains .ttr file name and content. Content is verified before file is changed on a recipient side.
   -	MSG_REQ_TTR – is a public-only broadcast message.  Is a signal for a client to send MSG_CODE_TTR message. It verifies and sends all local .ttr files. Content is sended only partially.
   -	MSG_PING – is a global broadcast message. Contains all information about a client which sended it. When recieved, a recipient checks own table with all online clients recorded and modifies it by adding new record to it with the name of sender (or by resetting timeout if corresponding record founded)
   -	MSG_START_GAME – is a global broadcast message. Contains key for random generator. If recieved, a client checks conditions to start competivive mode game and updates random generator key
   - MSG_KEYCONTROL - is not sended by a game client. Contains only message code and virtual key code. A recipient do not sends anything back to the controller
   - MSG_BASE_CHAT – is a public broadcast message of type any-any. Regular text message prefixed with sender's credentials 
