# TetrisWin
This is my implementation of famous tetris game in x86 Assembly (FASM). But for Windows ;)

The project is composed of muliple mini-projects and artifacts, made during my studies at BSUIR.

The Core is fully based on my DOS tetris implementation, see [this](https://github.com/archql/tetris-fasm) repo.

### tags:
```diff
+ file system
+ multithreading and synchronization
+ windows registry
+ opengl
+ simple cryptography & obfuscation
+ networking (udp)
+ assembly language
+ static dlls
```

### Size competition

Now (release v6.+) executable file size is `16kBytes`.
Network (release v5.+) executable file size is `12kBytes`.

There is minimal release with `8kBytes` size.

**Note**: no compression is used. Size in Windows by default aligns to `512 bytes` page size

## For users

### 💻SUPPORTED VERSIONS🖥️

- This version tested for
  - 🟢 Windows 11
  - 🟢 Windows 10
  - 🟢 Windows 7
  - 🟡 Windows XP
  - 🔘 other

#### INSTALLATION:
- `[if required]` change extension **.notexe** to **.exe** (*.notzip* to *.zip* and unpack)
- place **.exe** in any folder (empty and not system-protected folder required) an run it
- enjoy

#### ⚠️WARNING⚠️
 - Antiviruses might block this app because of the way of a virus detection used
 - Firewall might block network features

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
 | write         |  A..Z                |
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

- Leaderboard is not updated automatically. Use **R** key to do so (restarts entire gameplay).
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
 - `UUIDERR` &mdash; client tried to read UUID of your machine and failed. Equals `OFFLINE` mode except you cannot use online features.
 
#### Connection algorithm:
 - **Use *F3* key to try to connect to LAN** (your current state is `OFFLINE` or `REJCTED`). If it's worked properly your state is `ON-LINE`. 
 - Next client sends register message and waits (cur 500 ms). If your next state is `REGSTRD` everything went good!
 - If you got `REJCTED` state &mdash; change you nickname & try to connect again (use **F3** key).
 - LAN connection is also used for leaderboard update.
 - You can still get file updates if your state is `REJCTED`.
 - From version **5.9** Online Game View (**OGV**) is added. Every client in the same LAN sends its game frame with ping message. 
 - Other clients display them.
 
#### Competition game mode start algorithm:
 - **competition game mode** ensures that clients which started it will have same random seed 
 - use **F4** key to start it **for every client in the LAN!**. Game starts only if client has `GAME OVER` and `REGSTRD` state
 
#### Other network facts:
 
 - To control clients status ping messages are used. Upon recieval, the message is registered by nickname with timeout of 2s.
 - Ping message is sent every 200 ms. Client updates ping records also every 200 ms.
 - If timeout value reaches 0, client removes corresponding ping record.
 - you will recieve leaderboard updates even in `REJCTED` state.
 - Ping messages contain full game frame so your game can be visualized remotely with 200 ms precision.
 - To protect from clients with same name connection machine UUID is used.
 - It is possible to remote control your gameplay (and gameplay only) from another computer connected to same LAN.
 - ⚠️**WARNING. UDP protocol does not guarantee message delivery!**
 
### 🎨GRAPHICS🎨

 - graphics is fully based on **OpenGL**
 
#### (6.+)
 - by default, client displays 3D using colored cubes
 - cubes can be textured by placing *\*.bmp* files with *any* name to the folder with game
 - ⚠️**WARNING! BMP must be *R8* *G8* *B8* formatted (*24 bit*)**
**Other formai will cause game crash**
 - client will load BMP files automatically when they are presented
 - you can place multiple BMPs to the game folder and swap them with **F5** key
 - game field can be rotated using mouse wheel along Z axis (X axis if ctrl key holded).
 
### 🎵 MUSIC 🎵

 - music is based on **winmm** lib and windows emulation of MIDI.
 - music consists of 2 parts - `background` and `effect`
 - `background` music is included in the exe (1811 bytes) and its volume can be controlled
 - `background` music is enabled when game session is running
 - `effect` music have different types and conditions to trigger
 - `effect` music volume cannot be changed
 - `effect` music includes:
   - game end effect (2 \* 4 piano sounds emmited in the game end)
   - line clear effect (4 piano sounds emmited when line is cleared)
  additionally 'tetris' plays bang sound.
   - collided effect emmited when a figure is collided with game field and no longer movable.
   - key press effect emmited with every game changing key press
 
### 💠Replaceable event music and textures (v6.6+)💠
 - All files must be in .wav format (filename constists of name listed in the table below postfixed with .wav)
 - end game event is chosen randomly out of 3 options
 - optionally event can change texture of cubes to one equal event name postfixed with .bmp
 
| **What?**    | **When?**|
| ------- | ------------------ | 
| #7F2C93 | 1 line cleared |
| #7F3093 | 2 lines cleared |
| #7F3493 | 3 lines cleared |
| #7F3893 | 4 lines cleared |
| #7F2594 | bang sound when 4 lines cleared (conflicts with previous) |
| #7F2690 | end game event 1 (on fail) |
| #7F2290 | end game event 2 (on fail) |
| #7F1E90 | end game event 3 (on fail) |

### 📑Gameplay saves📑

- all gameplay is saved in `.ttr` files. 
- ⚠️**WARN**⚠️ *Full `.ttr`* file is the only valid proof for your score! You must not edit it or provide it to anybody in order to protect your score! You can store this file separatly from other game files for additional protection.
- additional info is [here](#what-is-ttr-files)
 
 
## 👨‍💻For developers👩‍💻

### Build & compile
To build properly, its requires several fasm .inc files (find them in ..\fasm folder [here, for example](https://github.com/Konctantin/FASM), or just google it). 
To compile it requires **fasm**.
Graphics is based on **OpenGL**.

### What is `'.amid'` files?
`'.amid'` file &mdash; file with short midi messages, every message is 4 bytes long,
 format is **control** | **track num byte** , **note_num byte** , **note_velocity byte**, **zero byte** (now delay to next note in ms / 2)
 This file is generated using my another progmam on delphi,
 that converts notes into midi messages.
 
New version (Compressed `'.amid'`, _Cx ) removes 2 bytes from a message, while delay is placed as a last byte in a pack of midi messages).

Super compressed `'.amid'` file ( _Scx ) holds only one byte per note. 7 low bits is note num & 1 hi bit defines to play note or mute.
 Quality of this kind of file is lower.

Super super compressed  `'.amid'` file ( _SScx ) holds one byte per note and has constant delay between notes.
 
 
### What is `'.ttr'` file?
`'.ttr'` file &mdash; is tetris record file with max score. Its name can be only 8 bytes (extension excluded) long and it represents nickname of a player.

New version is also xor-encrypted and holds full [`GameFrame`](#game-frame) information.
This information is enough to restore game process without any additional information or files. 
`'.ttr'` files are forward-compatible. 
Backward compatibility is possible but readonly, write will delete the gameframe.

*Short `.ttr`* - corresponds to **v.4** file format and is only 4 bytes long.
*Full `.ttr`* - includes short format and is **406** bytes long.

`'.ttr.tmp'` file is same format file as `'.ttr'` file. But it used to save gameplay of a player.

### Network protocol (5.+)

 - network packet starts with 2 bytes of message code and other vdistribution dependent data
 - UDP broadcast packets are recieved by the device they were sent from ("self-sending"). While this behavior is desired for some messages (type *global*), other must filter for it (type *public*)
 - current protocol (**v.6.4**) message codes are:
 
| **name**      | **code**         | **type**                  | **payload** | **when sent** | **when recieved** |
| ---           |----------------  |   :---:                   | ---                                | ---  | ---          |
| `BASE_PROXY`  | $F000            |     -                     |  -                                 |  -   | -            |
| KEYCONTROL    | 1 + BASE_PROXY   |     -                     |  Virtual Key (VK)                  |  -   | processes VK |
| PROXY         | 2 + BASE_PROXY   |     -                     |  NetFrame + GameFrame              |  -   | overwrites own gameframe by recieved one |
| `BASE_CLIENT` | $A000            |     -                     |  -                                 |  -   | -            |
| REGISTER      | 1 + BASE_CLIENT  | *public*                  |  NetFrame                          |  first message after network <br> module started | sends **RG_REJECTED** if nicknames of sender and reciever match  |
| REQ_TTR       | 5 + BASE_CLIENT  | *public*                  |  NetFrame                          |  when gets **REGISTER** | sends all local `.ttr` (*short* part) |
| TTR           | 6 + BASE_CLIENT  | *public* <br> or *direct* |  NetFrame + *short* .ttr      |  upon recieving **REQ_TTR** msg <br> or local score update | verifies recieved `.ttr` <br> and overwrites one stored locally  |
| RG_REJECTED   | 7 + BASE_CLIENT  | *direct*                  |  NetFrame                          | if nicknames of sender and reciever match | sets state to `REJCTED` |
| START_GAME    | 8 + BASE_CLIENT  | *global*                  |  NetFrame + random generator key   |  -   | verifies conditions to start competivive mode game and updates random generator key   |
| PING          | $FF + BASE_CLIENT| *global*                  |  NetFrame + GameFrame              |  every *200* ms if `REGSTRD` | creates or updates a ping record  |
| `BASE_CHAT`   | $B000            | *public*                  |  NetFrame + message (max 32 bytes) |  -   | adds message to chat |

- **Where**
  - **NetFrame** is client's UUID and message code + 4 bytes of *short* `.ttr` and **nickname**
  - **Virtual Key** is [this](https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes)
  - *short* `.ttr` is described [here](#what-is-ttr-files)
  - **GameFrame** is described [here](#game-frame)
 - current structure of `.ttr`, `NetFrame` and `GameFrame` can be located in the `'tetrisdata.asm'`

### Errors & fixes
- if you faced an error which is not listed in the full readme while using this public version, please, contact author with detailed description of a problem and steps of reproduction

## Author

@archql




