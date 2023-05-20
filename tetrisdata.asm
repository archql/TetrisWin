        ; LOOK FOR PROTECTED STRINGS IN CLIENT.ASM!!!

        Wnd.font_name   db "Lucida Sans Typewriter", 0

        Wnd.style       equ WS_VISIBLE+WS_OVERLAPPEDWINDOW

        ; == FIELD SZ
        FIELD_W = 12; 12
        FIELD_H = 23
        DFIELD_W_CONST = 13.0
        DFIELD_H_CONST = 24.0
        ;========
        DFIELD_H         dq      DFIELD_H_CONST ; FIELD_H + 1
        sub_DFIELD_W     dq      DFIELD_W_CONST
        RECT_MODIFIER    dq      0.90
        ;DFIELD_W        dq      ?
        ;clock           dd      ?
        ;rect_size       dd      ?

        ; =======TEXT==============================
        SCOLE_LEN_CONST           = 6
        Str.NextFig               db    'NEXT FIGURE'
        Str.NextFig.Len           =     $ - Str.NextFig
        Str.HoldedFig             db    'HOLDED FIGURE'
        Str.HoldedFig.Len         =     $ - Str.HoldedFig
        Str.Scoreboard            db    '--<LEADERBOARD>--'
        Str.Score.Format          db    '%5d', 0
        ;Str.ScoreCorrypted.Format db    '#$&*!', 0
        Str.Pause                 db    'PAUSED'
        Str.Loose                 db    'GAME OVER'
        Str.Win                   db    'YOU WON'

        NICKNAME_LEN                     =     8
        Settings.strTempNickName         db    '________'
        STR_BASE_NICKNAME_FIRST_SYMBOL   =     '@'
        Str.BaseNickName                 db    STR_BASE_NICKNAME_FIRST_SYMBOL ,'DEFAULT'
        Settings.strTempNickNameBlocked  db    '~~~~~~~~'
        ;========ANIMATIONS========================
        Glow.AnimDeltaAngle       dd    2.0
        Glow.SZ_delta             dd    0.05
        ;Glow.right                dd    ?
        ;Glow.left                 dd    ?
        ;Glow.Arr                  db    FIELD_H dup 0
        ;========VIEW==============================
        Color_Table     dd      0.0, 0.0, 0.0,\   ;0.271, 0.271, 0.271,\
                                0.271, 0.271, 0.271,\   ;0.7, 0.7, 0.7
                                0.1, 0.1, 0.1,\  ;0.25, 0.25, 0.25
                                1.0, 0.5098, 0.0,\
                                0.0, 0.0, 1.0,\     ; blue
                                0.2549, 0.0, 1.0,\  ; 5
                                0.5098, 0.0, 1.0,\
                                0.745, 0.0, 1.0,\
                                1.0, 0.0, 0.745,\
                                1.0, 0.0, 0.5098,\
                                1.0, 0.0, 0.2549,\
                                1.0, 0.0, 0.0,\
                                1.0, 0.2549, 0.0,\
                                1.0, 0.745, 0.0,\
                                1.0, 1.0, 0.0,\     ; yellow
                                0.745, 1.0, 0.0,\
                                0.5098, 1.0, 0.0,\
                                0.2549, 1.0, 0.0,\
                                0.0, 1.0, 0.2549,\
                                0.0, 1.0, 0.5098,\
                                0.0, 1.0, 0.745,\
                                0.0, 1.0, 1.0,\
                                0.0, 0.745, 1.0,\
                                0.0, 0.5098, 1.0,\
                                0.0, 0.2549, 1.0
        colorsNum       =       ($ - Color_Table)/12 - 1

        ;========Game model==============
        Game.SpeedMul           dq      0.96;96

        figArr          dw      0110'0110_0000'0000b, 0110'0110_0000'0000b, 0110'0110_0000'0000b, 0110'0110_0000'0000b,\ ; O
                                0000'1111_0000'0000b, 0010'0010_0010'0010b, 0000'0000_1111'0000b, 0100'0100_0100'0100b,\ ; I
                                1000_1110_0000_0000b, 0110_0100_0100_0000b, 0000_1110_0010_0000b, 0100_0100_1100_0000b,\ ; J
                                0010_1110_0000_0000b, 0100_0100_0110_0000b, 0000_1110_1000_0000b, 1100_0100_0100_0000b,\ ; L
                                0110_1100_0000_0000b, 0100_0110_0010_0000b, 0000_0110_1100_0000b, 1000_1100_0100_0000b,\ ; S
                                1100_0110_0000_0000b, 0010_0110_0100_0000b, 0000_1100_0110_0000b, 0100_1100_1000_0000b,\ ; Z
                                0100_1110_0000_0000b, 0100_0110_0100_0000b, 0000_1110_0100_0000b, 0100_1100_0100_0000b   ; T
                                ;0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b,\
                                ;0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b,\
                                ;0000'1110_1010'0000b, 0110'0100_0110'0000b, 1010'1110_0000'0000b, 1100'0100_1100'0000b;,\;
        figNum          =       ($ - figArr)/8 - 1

        ; # SETTINGS
        ; addl data to ld scoreboard
        View.strTextureFileFilter   db    '*.bmp', 0
        Settings.strFileFilter      db    '*.ttr', 0
        Settings.PlaceFormat        db    '#%X', 0
        Settings.Music.HexFormat    db    '#%X.wav', 0
        Settings.Format.File.Temp   db    '%.8s.ttr.tmp', 0   ;NICKNAME_LEN
        Settings.Format.File        db    '%.8s.ttr', 0       ;NICKNAME_LEN
        Settings.File.Name          db    'lastnickname', 0

        ; # CLIENT
if (SERVER_DEFINED)
        Client.dIPAddrTableSz       dd    CLIENT_ADAPTERS_BUF_MAX
        Client.PCIDBufLen           dd    CLIENT_PCID_LEN + CLIENT_BUF_LEN + 1 ; Buffer for key isnt large enough but it isnt dangerous??

        ; protected strings
        ;Wnd.title                   TCHAR 'TETRIS WIN ASM by Artiom Drankevich',0
        ;Client.QuaryValue           db    'SOFTWARE\Microsoft\Cryptography', 0
        ;Client.QuaryKey             db    'MachineGuid', 0

        Client.StrError             db    '@OFFLINE'
        CLIENT_STR_LEN              = $ - Client.StrError
        Client.StrConnected         db    '@ON-LINE'
        Client.StrRegistered        db    '@REGSTRD'
        Client.StrRgRejected        db    '@REJCTED'
        Client.StrKeyFail           db    '@UUIDERR'
end if

        ;# SoundPlayer
        SoundPlayer.Notes         file    'tetris_ex.amid' ; ex
        SoundPlayer.NotesNum:     ; this pos - 2 bytes
        SoundPlayer.Instruments   db    1100'0000b or 0, 32 , 0, 0,\ ; 32 25 25 10
                                        1100'0000b or 1, 25 , 0, 0,\; formatt 1100'nnnn n - channel no, instr no, 0, 0
                                        1100'0000b or 2, 25 , 0, 0,\
                                        1100'0000b or 3, 10 , 0, 0,\
                                        1100'0000b or 4, 127, 0, 0; gunshot

        if (HELP_DEFINED)
        Help.Str1       db      '  ~~~TETRIS HELP TABLE~~~  '
        Help.Str.LEN    = $ - Help.Str1
        Help.Str2       db      'For help read README       '
        Help.Str3       db      '    find out more at:      '
        Help.Str4       db      'github.com/archql/TetrisWin'
        Help.Str5       db      '      archql (c) 2022      '
        Help.LPos:
        Help.LEN        = ($ -  Help.Str1) / Help.Str.LEN
        end if


        include 'tcp_data.asm'

; ################################################
; ####### UNINITIALIZED MEMORY HERE!!!!! #########
; ################################################
Unitialized_mem:
        ; # Windows
        Wnd.msg                         MSG                     ?
        Wnd.paintstruct                 PAINTSTRUCT             ?
        Wnd.pfd                         PIXELFORMATDESCRIPTOR   ?
     Wnd.font:  ; Wnd.rc & FONT united based on TETRIS INI CODE
        Wnd.nFontBase                   dd                      ?
        Wnd.fontSz                      dd                      ?

        Wnd.hwnd                        dd      ?
        Wnd.hrc                         dd      ?
        Wnd.hdc                         dd      ?

        Wnd.wc                          WNDCLASS        ?

        ratio                           dq      ?

        Wnd.rc                          RECT    ?
        ; # Glow data
        Glow.AnimAngle                  dd      ?

        Glow.right                      dd      ?
        Glow.left                       dd      ?
        Glow.Arr                        db      FIELD_H dup ? ; initialization!
        ; # Draw
        DFIELD_W                        dq      ?
        clock                           dd      ?
        rect_size                       dd      ? ; initialization

        View.FieldAngleDraw             dd      ?
        View.HFieldAngleDraw            dd      ?

        View.TextureID                  dd      ?

        View.TextureFileLookupHandle    dd      ? ; if zero, then noninitialized
        ; to be initialized, call special function
        View.TextureFileDataa           WIN32_FIND_DATAA        ?

        ; sub draw data
     sub_:
        sub_rect_size                   dd      ?
        sub_inv_x_pos                   dd      ?
        sub_inv_y_pos                   dd      ?
        sub_scale_f                     dd      ?
        sub_inv_scale_f                 dd      ?
        sub_scale                       dd      ?
        sub_x_pos                       dd      ?
        sub_y_pos                       dd      ?
     sub_font:
        sub_font_base                   dd      ?
        sub_font_sz                     dd      ?
     chat_font:
        .sub_font_base                  dd      ?
        .sub_font_sz                    dd      ?

        Game.randomEndSpecialId         dw      ?

        ; # MESSAGE CODES
        MSG_CODE_BASE_PROXY             = $F000
        MSG_CODE_KEYCONTROL             = 1 + MSG_CODE_BASE_PROXY
        MSG_CODE_PROXY                  = 2 + MSG_CODE_BASE_PROXY

        MSG_CODE_BASE_CLIENT            = $A000
        MSG_CODE_REGISTER               =   1 + MSG_CODE_BASE_CLIENT
        MSG_CODE_REQ_TTR                =   5 + MSG_CODE_BASE_CLIENT
        MSG_CODE_TTR                    =   6 + MSG_CODE_BASE_CLIENT
        MSG_CODE_RG_REJECTED            =   7 + MSG_CODE_BASE_CLIENT
        MSG_CODE_START_GAME             =   8 + MSG_CODE_BASE_CLIENT
        MSG_CODE_PING                   = $FF + MSG_CODE_BASE_CLIENT

        MSG_CODE_BASE_CHAT              = $B000


        ; # BUFFER TO SCORE WRITE & GAME RESTORE
        Client.CritSection              RTL_CRITICAL_SECTION    ?
GameMessage:
        ; # Client
        Client.MessageCode              dw      ?
        CLIENT_PCID_LEN                 = 36
        Client.PCID                     db      CLIENT_PCID_LEN dup ?, ? ; zero term
        CLIENT_BUF_LEN                  = 32; 16 (increased due to send chat msg buf needed)
        Client.Buffer                   db      CLIENT_BUF_LEN dup ? ; Buffer for client message addl parameters
GameBuffer:
        ; Its defines base .ttr file data
        GameBuffer.Score                dw      ?
        GameBuffer.ControlWord          dw      ?
        ; # Game
        Game.NickName                   db      NICKNAME_LEN dup ?
MESSAGE_BASE_LEN = ($ - GameMessage)
; There can be overlapped data!
        ; # Str
        Str.HighScore                   db      SCOLE_LEN_CONST dup ?
        Str.Score                       db      SCOLE_LEN_CONST dup ?
        ; # Random
        Random.dSeed                    dd      ?
        Random.dPrewNumber              dd      ?
MESSAGE_START_GAME_LEN =  ($ - GameMessage)
        ; # Game
        Game.BlocksArr:                 db      FIELD_W*FIELD_H dup ? ; initialization!
        Game.CurFig                     dw      ?
        Game.CurFigColor                dw      ?
        Game.CurFigRotation             dw      ?
        Game.CurFigNumber               dw      ?

        Game.NextFig                    dw      ?
        Game.NextFigNumber              dw      7 dup ?
        Game.NextFigCtr                 dw      ?

        Game.FigX                       dw      ?
        Game.FigY                       dw      ?
        Game.FigPreviewY                dw      ?
        Game.TickSpeed                  dw      ?
        Game.TicksPlayed                dd      ?
        Game.Score                      dw      ?
        Game.HighScore                  dw      ?
        Game.Playing                    dw      ?
        Game.Pause                      dw      ?
        Game.FigsPlaced                 dw      ?
        Game.Holded                     dw      ?
        Game.HoldedFigNum               dw      ?
        Game.HoldedFig                  dw      ?
        Game.MusicOff                   dw      ?
        Game.SoftDrop                   dw      ?

        ; NICKNAME

        Game.VersionInfo                dd      ?
        Game.VersionCode                dd      ?
        Game.Reserved                   dw      16 dup ?
FILE_SZ_TO_WRITE = ($ - GameBuffer)
FILE_SZ_TO_RCV   = ($ - GameMessage)

        Game.CurTick                    dd      ?

        View.MenuChosen                 dw      ?

        ; # Music
        midihandle                      dd      ?
        SoundPlayer.CurTick             dw      ?
        SoundPlayer.DeltaTick           dw      ?

        SoundPlayer.NextSound           dw      ?

        SoundPlayer.VolumeMask          dd      ?
        label SoundPlayer.Volume        byte at $ - 2

        ;SoundPlayer.CurEventTick        dw      ?
        SoundPlayer.EndGameTick         dw      ?
        ;SoundPlayer.LineGameTick        dw      ?

        ; # CLIENT
        Client.wsaData          WSADATA         ?
        Client.psocket          dd              ?
        Client.flag             dd              ?
        Client.Recv_addr        sockaddr_in     ?
        Client.Sender_addr      sockaddr_in     ?
        Client.Broadcast_addr   sockaddr_in     ?

        Client.State            dw              ?
        CLIENT_STATE_OFFLINE    = 0
        CLIENT_STATE_ONLINE     = 1
        CLIENT_STATE_REGISTERED = 2
        CLIENT_STATE_REJECTED   = 3
        CLIENT_STATE_UUIDERROR  = 4

        ; IP list table
        ;Client.dIPAddrTableSz   dd              ?
        ;Client.pIPAddrTable     dd              ?
        ; for get UUID
        Client.KeyHandle        dd              ?

        ; Thread reciever
        Client.ThRecv.hThread   dd              ?
        Client.ThRecv.pThId     dd              ?
        Client.ThRecv.thStop    dw              ?

        ; Thread Ping | send
        Client.ThSend.hThread   dd              ?
        Client.ThSend.pThId     dd              ?
        Client.ThSend.thStop    dw              ?

        CLIENT_RECV_BUF_LEN     =               FILE_SZ_TO_RCV
        Client.recvbuff         db              CLIENT_RECV_BUF_LEN dup ?
        Client.StructLen        dd              ?


        ; # Settings
        Settings.SetupNickNameActive            dw      ?
        Settings.strFilenameBuf                 db      (NICKNAME_LEN + 10) dup ?
        Settings.strTempNickNameHighlight       db      NICKNAME_LEN  dup ?, ? ; special save byte

        Settings.strTempLen             dw      ?

        FILE_SZ_TO_READ                 = 4
        Settings.buffer                 db      FILE_SZ_TO_READ dup ?
        Settings.BytesProceed           dd      ?

        Settings.fileData               WIN32_FIND_DATAA            ?
        LB_NAME_STR_LEN                 = NICKNAME_LEN
        LB_ISTR_RCD_LEN                 = 17
        LB_ISTR_RCD_LEN_POW             = 5; Real mem sz allocated 2^*
        LB_PRIO_RCD_LEN                 = 4
        LB_BASE_RCDS_AMOUNT             = 16
        LB_MAX_RCDS_AMOUNT              = 1024 ; NEVER CHECKED!!

UNINI_MEM_LEN                   = $ - Unitialized_mem  ; Its filled with 0s when started (so its protected from page allocation error & from unini mem errorrs)
        ; Filled up with zeros!
        CLIENT_MAX_CONN                 = 64 ; NEVER CHECKED!!
        CLIENT_CL_RCD_LEN               = NICKNAME_LEN + 2 + FILE_SZ_TO_WRITE ; NICK + "word" ping
        Client.ClientsDataArr           db     (CLIENT_MAX_CONN) * (CLIENT_CL_RCD_LEN) dup ? ; temp nick name usage



        ; Buffer for adapters info table
        CLIENT_ADAPTERS_BUF_MAX         = 1024
        Client.IPAddrTableBuf           db     (CLIENT_ADAPTERS_BUF_MAX) dup ?
        ; LB LINE STRUCT = [17 bytes Info = {place str - 3}{nick - 8}{score - 6}][ empty (11) ][is cur usr? (0)][4 bytes - prio prd {score - 2}{place - 2}]
        Settings.LeaderBoardArr         db     (LB_MAX_RCDS_AMOUNT)*(1 shl LB_ISTR_RCD_LEN_POW) dup ?

        ; CHAT BUFFER
        CHAT_MAX                        =  1024
        CHAT_MSG_RCD                    =  5 ; Real mem sz allocated 2^*
        CHAT_MSG_LEN                    =  (1 shl CHAT_MSG_RCD)
        CHAT_MSG_OFF                    =  NICKNAME_LEN + 2
        CHAT_MSG_MAX                    =  CHAT_MSG_LEN - CHAT_MSG_OFF
        Chat.Length                     dw    ?
        Chat.MsgPos                     dw    ?
        Chat.InpPos                     dw    ?
        Chat.Buf                        db    CHAT_MSG_LEN dup ?
        Chat.Table                      db    CHAT_MAX*CHAT_MSG_LEN dup ?

        ; GAME VERSION
        ; -- App?                       (3 bits)
        GAME_V_APP_LOCAL                = 0
        GAME_V_APP_SERVER               = 1
        GAME_V_APP_CLIENT               = 2
        ; Set here!
        GAME_V_APP                      = GAME_V_APP_CLIENT
        ; -- Platform?                  (3 bits)
        GAME_V_PLATFORM_WIN             = 0
        GAME_V_PLATFORM_ANDROID         = 1
        ; Set here!
        GAME_V_PLATFORM                 = GAME_V_PLATFORM_WIN
        ; -- ASM used?                  (1 bit)
        GAME_V_ASM                      = TRUE
        ; -- Version major (max 255)
        GAME_V_MAJOR                    = 6
        ; -- Version minor (max 63)
        GAME_V_MINOR                    = 6
        ; -- Type?                      (2 bits)
        GAME_V_TYPE_DBG                 = 0
        GAME_V_TYPE_RELEASE             = 11b
        GAME_V_TYPE_BRANCH              = 1
        ; Set here!
        GAME_V_TYPE                     = GAME_V_TYPE_RELEASE
        ; -- Random type                (2 bits)
        GAME_V_RND_TYPE_ORIGINAL        = 1
        GAME_V_RND_TYPE_CLASSIC         = 0
        ; Set here!
        GAME_V_RND_TYPE                 = GAME_V_RND_TYPE_ORIGINAL
        ; -- Rotation type              (2 bits)
        GAME_V_ROT_TYPE_ORIGINAL        = 1
        GAME_V_ROT_TYPE_FIXED           = 0
        GAME_V_ROT_TYPE_CLASSIC         = 2
        ; Set here!
        GAME_V_ROT_TYPE                 = GAME_V_ROT_TYPE_FIXED
        ; -- Speed type                 (2 bits)
        GAME_V_SPD_TYPE_ORIGINAL        = 0
        GAME_V_SPD_TYPE_CLASSIC         = 1
        ; Set here!
        GAME_V_SPD_TYPE                 = GAME_V_SPD_TYPE_ORIGINAL