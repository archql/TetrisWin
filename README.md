# TetrisWin
This is my implementation of famous tetris game on fasm. But for windows ;)
There I used my laborotory works which were done while studying at BSUIR. Also this is my coursework.
Logics is fully based on my previous tetris variant, see [this](https://github.com/archql/tetris-fasm) repo.

## For users

### 💻SUPPORTED VERSIONS🖥️

- All rectangular screen resolutions supported (at least for gameplay).
- This version tested on
  - 🟢 Windows 11
  - 🟢 Windows 10
  - 🟢 Windows 7
  - 🟡 Windows XP
  - 🔘 other

#### INSTALLATION:
- `[if required]` change extension **.notexe** to **.exe** (*.notzip* to *.zip* and unpack)
- place **.exe** in any folder (empty and not system-protected folder preffered)
- read **agreement.txt** before use
- its all!

#### ⚠️WARNING⚠️
 - Antiviruses might block this app because of the way of a virus detection used
 - Firewall might block network features of this app even in `ON-LINE` state!

### ⌨️CONTROLS⌨️
| **Ingame action**    | **Key to trigger it**|
| -------------------- |:------------------:| 
| move left            |  <                 |
| move right           |  >                 | 
| rotate clockwise     |  ^	            |
| rotate anticlockwise |  v                 |
| end game/quit        |  ESC               |
| hard drop            |  SPACE             |
| soft drop            |  SHIFT             |
| pause/play           |  P                 |
| restart              |  R                 |
| hold                 |  H                 |
| special *not recommended* | ENTER (*costs 100 score*)|

#### 🖱️MOUSE CONTROLS🖱️
| **Ingame action**    | **Mouse action**|
| -------------------- |:------------------:| 
| move left            |  move left (inside the field)  |
| move right           |  move right (inside the field) |
| rotate clockwise     |  wheel rotation |
| rotate anticlockwise |  wheel rotation |
| hard drop            |  Left button click  |
| hold                 |  Right button click |

*Be careful with mouse while playing using keyboard!*
*Planned* add a way to disable mouse

#### 🎵 MUSIC CONTROLS 🎵

| **Ingame action**    | **Key to trigger it**|
| -------------------- |:------------------:| 
| mute music           |  M                 |
| increase volume      |  ]                 |
| decrease volume      |  \[                |

More information [here](#-music-)

#### 🎨VIEW CONTROLS🎨

| **Ingame action**           | **Key to trigger it**|
| --------------------        |:------------------:| 
| swap menus                  |  F2                           |
| swap textures (v.6.+)       |  F5	                      |
| rotate field along X (v.6.+)|  SHIFT + mouse wheel rotation |
| rotate field along Z (v.6.+)|  CTRL +	mouse wheel rotation  |

More information [here](#graphics)

#### 📶NETWORK CONTROLS (v5.+)📶
| **Ingame action**    | **Key to trigger it**|
| -------------------- |:------------------:| 
| connect              |  F3               |
| competition mode     |  F4	           |

More information [here](#network-mode-v5)

#### 🏷️NICKNAME CONTROLS:🏷️
to activate edit mode &mdash; hold **CTRL** key
with all keys pressed
 
 | **action**    | **Key to trigger it**|
 | ------------- |:--------------------:| 
 | write         | A..Z                 |
 | move left     | <                    |
 | move right    | >                    |
 | rm symbol     | BACKSPACE            |
 | accept changes| ENTER                |
 
- nickname is **unchangable** when
  - client is in `REGSTRD` state
  - game is started and score is not zero
 
- *in theory* nicknames can use first 128 ANSI symbols, 
	but support of such nicknames is *not guaranteed*! 
- there is nickname `@DEFAULT` which does not save your score nor displays on Leaderboard 
- your last used nickname is auto saved by the app

#### 🥇LEADERBOARD INFORMATION:🥇

- Leaderboard isn't updated automatically. Use **R** key to do so (restarts entire gameplay).
- Leaderboard *holds up to 16 records sorted* by score.
- Leaderboard record *place displayed as hex number* prefixed with '#'
- All records displayed with ⬜white color⬜
- Record which belongs to current user is 🟨*highligted in yellow* color🟨
- *##* place for current user means the place number is greater than **0x0F** (16)
- Based on gameplay saved files. More information [here](#gameplay-save)
 
### 📶NETWORK MODE (v5.+)📶

 - Network gameplay works only in LAN.
 - You can use software that creates virtual LAN.
 - To work with network app uses UDP port 7000. 
 - App uses special prefixes for messages to differ them.
 
#### Client has 5 states:
 - `OFFLINE` &mdash; client isn't connected to network.
 - `ON-LINE` &mdash; client is connected to network, but registration isn't completed.
 - `REGSTRD` &mdash; client is registered in network and now can send & recieve all nessesary messages
 - `REJCTED` &mdash; client tried to connect to LAN, which already has client with same nickname connected.
 - `UUIDERR` &mdash; client tried to read UUID of your machine and failed. Equals `OFFLINE` mode except you can not use online features.
 
#### Connection algorithm:
 - **Use *F3* key to make try to connect to LAN** (your current state is `OFFLINE` or `REJCTED`). If it's worked properly your state is `ON-LINE`. 
 - Next client sends register message and waits (cur 500 ms). If your next state is `REGSTRD` everything went good!
 - If you got `REJCTED` state &mdash; change you nickname & try to connect again (use **F3** key).
 - LAN connection is also used for leaderboard update.
 - You can still get file updates if your state is `REJCTED`.
 - From version **5.9** Online Game View (**OGV**) is added. Every client in the same LAN sends its game frame with ping message. 
 - Other clients display them.
 
#### Competition game mode start algorithm:
 - **competition game mode** ensures that clients which started it will have same random seed 
 - use **F4** key to start. Game starts only if client has `GAME OVER` and `REGSTRD` state **for every client in the LAN!**
 
#### Other network facts:
 
 - To control clients online ping messages used. If client got such message it checks it's nickname
 registers it and set timeout value (cur 10 \* 200 ms = 2 s).
 - Ping message sends every 200 ms. Client checks all ping records also every 200 ms.
 - If timeout value became 0, client removes corresponding ping record.
 - if you have *REJCTED* state - change your nickname and retry (use F3 key).
 - you will recieve leaderboard updates even in `REJCTED` state.
 - Ping messages contains full game frame so your game can be visualized remotely with 200 ms precision.
 - To protect from clients with same name connection machine UUID used.
 - There is possible to remote control your gameplay from another computer connected to same LAN (and gameplay only).
 - ⚠️**WARNING. UDP protocol does not guarantee message delivery!**
 
### 🎨GRAPHICS🎨

 - graphics is fully based on **OpenGL**
 
#### (6.+)
 - by default, client displays 3D using colored cubes
 - cubes can be textured by placing *\*.bmp* files with *any* name to the folder with game
 - ⚠️**WARNING! BMP must be *R8* *G8* *B8* formatted (*24 bit*) and its size less than 100 kB!**
**Other sizes are not guaranteed to work! Possible outcome is game crash**
 - client will use BMP files automatically when they are presented
 - you can place multiple BMPs to the game folder and swap them with **F5** key
 - game field can be rotated by mouse wheel along Z axis (X axis if ctrl key holded).
 
### 🎵 MUSIC 🎵

 - music is based on **winmm** lib and windows emulation of MIDI.
 - music consists of 2 parts - `background` and `effect`
 - `background` music is included to the exe (1811 bytes) and its volume can be controlled
 - `background` music enables when game session is running
 - `effect` music have different kinds and conditions for it
 - `effect` music volume cant be changed
 - `effect` music includes:
   - game end effect (2 \* 4 piano sounds emmited in the game end)
   - line clear effect (4 piano sounds emmited when line is cleared)
  additionally 'tetris' plays bang sound.
   - collided effect emmited figure is finally collided with game field and is no longer movable.
   - key press effect emmited with basically any game changing key press
 
#### (6.+)
 - by default, all music is midi messages
 - `effect` music can be changed by placing *\*.wav* files with *special* name to the folder with game
 - `special` name must be formatted as midi hex code text prefixed with '#' symbol and postfixed with '.wav' 
 - now (v6.4) game end, line clear and bang sounds are replaceable
 
### 💠Replaceable event music and textures (v6.6+)💠
 - All files must be in .wav format (filename constists of name listed in the table below postfixed with .wav)
 - end game event is played one from 3 presented randomly (*can be 4 but random is stupid*)
 - additionally sound played changes texture to one which filename constists of name 
 listed in the table below postfixed with .bmp)
 
| **What?**    | **When?**|
| ------- | ------------------ | 
| #7F2C93 | 1 line cleared |
| #7F3093 | 2 lines cleared |
| #7F3493 | 3 lines cleared |
| #7F3893 | 4 lines cleared |
| #7F2594 | bang sound when 4 lines cleared (conflicts with previous) |
| #7F2690 | end game event 1 (on loose) |
| #7F2290 | end game event 2 (on loose) |
| #7F1E90 | end game event 3 (on loose) |
| *#7F1A90* | *end game event 4 (on loose) **not guaranteed** * |

### 📑Gameplay save📑

- all gameplay is saved in `.ttr` files. 
- ⚠️**WARN**⚠️ *Full `.ttr`* file is the only valid proof for your score! You must not edit it or provide it to anybody except officials in order to protect your score! You can store this file separatly from other game files for additional protection.
- additional info is [here](#what-is-ttr-files)
 
 
## 👨‍💻For developers👩‍💻

### Build & compile
To build properly, its requires several fasm .inc files (they are not mine; find them in ..\fasm folder [here, for example](https://github.com/Konctantin/FASM), or just google it). 
To compile it requires **fasm**.
Graphics based on **OpenGL**.

### Size competition

Now (release v6.+) executable file size is `16kBytes`.
Network (release v5.+) executable file size is `12kBytes`.

There is minimal release with `8kBytes` size.

### Short list of what "skills" are used:
```diff
+ file system
+ multithreading and synchronization
+ windows registry
+ midi
+ opengl 2D & 3D
+ simple cryptography & obfuscation
+ networking (udp)
+ assembly 
+ git
+ static dll usage
+ google usage
```

### What is `'.amid'` files?
`'.amid'` file &mdash; file with short midi messages, every message is 4 bytes long,
 format is **control** | **track num byte** , **note_num byte** , **note_velocity byte**, **zero byte** (now delay to next note in ms / 2)
 This file is generated using my another progmam on delphi,
 that converts notes into midi messages.
 
New version (Extended `'.amid'`, _Ex ) removes 2 elder bytes, and delay is placed as last byte in pack of midi messages).

Super extended `'.amid'` file ( _SEx ) holds only one byte per note. 7 low bits is note num & 1 hi bit defines to play note or mute.
 Quality of this kind of file is lower.

Compressed super extended  `'.amid'` file ( _CSEx ) holds only one byte per note and doesnt hold any info about bitrate. 
 All notes played with same delay.
 
 
### What is `'.ttr'` files?
`'.ttr'` file &mdash; is tetris record file with max score. It's name can be only 8 bytes (extension excluded) long and it represents nickname of a player.

New version is also encrypted and holds full [`GameFrame`](#game-frame) information.
This information is enough to restore game process without any additional information or files. 
Old `'.ttr'` files are supported in new versions.
New `'.ttr'` files are supported in old versions (But they are readonly, write will "kill" them).

*Short `.ttr`* - corresponds to **v.4** file format and is only 4 bytes long.
Now it is part of `.ttr`
*Full `.ttr`* is now **406** bytes long file.

`'.ttr.tmp'` file is same format file as `'.ttr'` file. But it used to save gameplay of a player.

### Network protocol (5.+)

 - net packet starts with 2 bytes of message code and other data which depends on game version and message
 - processing logics is &mdash; When message is recieved, its code is checked along with the details of the sender and recipient. This is necessary due to the peculiarity of UDP broadcast packets distribution namely they also recieved by the device from which they were sent ("self-sending"). However, due to the possible presence of a large number of network adapters in the single device there may be duplicated "self-sended" packets. Therefore, there are messages processing which do not accept "self-sending" (named *public-only*); messages that need it (named *global*); messages that need it but in a single copy (named *public*). 
 - current protocol (**v.6.4**) message codes are:
 
| **name**      | **code**         | **type**                  | **payload** | **when sended** | **when recieved** |
| ---           |----------------  |   :---:                   | ---                                | ---  | ---          |
| `BASE_PROXY`  | $F000            |     -                     |  -                                 |  -   | -            |
| KEYCONTROL    | 1 + BASE_PROXY   |     -                     |  Virtual Key (VK)                  |  ?   | processes VK |
| PROXY         | 2 + BASE_PROXY   |     -                     |  NetFrame + GameFrame              |  -   | overwrites own gameframe by recieved one |
| `BASE_CLIENT` | $A000            |     -                     |  -                                 |  -   | -            |
| REGISTER      | 1 + BASE_CLIENT  | *public-only*             |  NetFrame                          |  first message after network <br> module started | sends **RG_REJECTED** if nicknames of sender and reciever match  |
| REQ_TTR       | 5 + BASE_CLIENT  | *public-only*             |  NetFrame                          |  when gets **REGISTER** | sends all local `.ttr` (*short* part) |
| TTR           | 6 + BASE_CLIENT  | *public-only* <br> or *direct* |  NetFrame + *short* .ttr      |  when gets **REQ_TTR** <br> or got local score update | verifies recieved `.ttr` <br> and overwrites local one if nessesary  |
| RG_REJECTED   | 7 + BASE_CLIENT  | *direct*                  |  NetFrame                          | if nicknames of sender and reciever match | sets state to `REJCTED` |
| START_GAME    | 8 + BASE_CLIENT  | *global*                  |  NetFrame + random generator key   |  ?   | checks conditions to start competivive mode game and updates random generator key   |
| PING          | $FF + BASE_CLIENT| *global*                  |  NetFrame + GameFrame              |  every *200* ms if `REGSTRD` | checks own table with all online clients recorded and modifies it by adding new record to it with the name of sender (or by resetting timeout if corresponding record founded) |
| `BASE_CHAT`   | $B000            | *public*                  |  NetFrame + message (max 32 bytes) |  ?   | adds message to chat view buffer |

- **Where**
  - **NetFrame** is client's UUID and message code + 4 bytes of *short* `.ttr` and **nickname** (last two actually are part of **GameFrame**, but *shhh*) 
  - **Virtual Key** is [this](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)
  - *short* `.ttr` is described [here](#what-is-ttr-files)
  - **GameFrame** is described [here](#game-frame)
 - current structure of `.ttr`, `NetFrame` and `GameFrame` can be located in the `'tetrisdata.asm'`
  
### `.ttr` protection

## Author

*Artiom Drankevich* (**archql**)

artem.drankevich@gmail.com




