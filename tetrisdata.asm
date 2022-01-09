        Wnd.Caption     db 'ERROR',0
        Wnd.Text        db 'Window creation fail', 0

        Wnd.font_name   db "Lucida Sans Typewriter", 0

        Wnd.class       TCHAR    'FASMW32',0
        Wnd.title       TCHAR    'TETRIS WIN ASM by Artiom Drankevich',0

        Wnd.style       equ WS_VISIBLE+WS_OVERLAPPEDWINDOW

        ;========
        DFIELD_H        dq      24.0 ; FIELD_H + 1
        RECT_MODIFIER   dq      0.90
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

        Settings.strTempNickName  db    '________'
        Str.AdminNickName         db    '_ARCHQL_'
        ;========ANIMATIONS========================
        Glow.AnimAngle            dd    0.0
        Glow.AnimDeltaAngle       dd    20.0
        Glow.SZ_delta             dd    0.05
        ;Glow.right                dd    ?
        ;Glow.left                 dd    ?
        ;Glow.Arr                  db    FIELD_H dup 0
        ;========VIEW==============================
        Color_Table     dd      0.0, 0.0, 0.0,\   ;0.271, 0.271, 0.271,\
                                0.7, 0.7, 0.7,\
                                0.25, 0.25, 0.25,\
                                1.0, 0.5098, 0.0,\
                                0.0, 0.0, 1.0,\
                                0.2549, 0.0, 1.0,\
                                0.5098, 0.0, 1.0,\
                                0.745, 0.0, 1.0,\
                                1.0, 0.0, 0.745,\
                                1.0, 0.0, 0.5098,\
                                1.0, 0.0, 0.2549,\
                                1.0, 0.0, 0.0,\
                                1.0, 0.2549, 0.0,\;;;;
                                1.0, 0.745, 0.0,\
                                1.0, 1.0, 0.0,\
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

        figArr          dw      0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b,\ ; O
                                0000'1111_0000'0000b, 0010'0010_0010'0010b, 0000'0000_1111'0000b, 0100'0100_0100'0100b,\ ; I
                                1000_1110_0000_0000b, 0110_0100_0100_0000b, 0000_1110_0010_0000b, 0100_0100_1100_0000b,\ ; J
                                0010_1110_0000_0000b, 0100_0100_0110_0000b, 0000_1110_1000_0000b, 1100_0100_0100_0000b,\ ; L
                                0110_1100_0000_0000b, 0100_0110_0010_0000b, 0000_0110_1100_0000b, 1000_1100_0100_0000b,\ ; S
                                1100_0110_0000_0000b, 0010_0110_0100_0000b, 0000_1100_0110_0000b, 0100_1100_1000_0000b,\ ; Z
                                0100_1110_0000_0000b, 0100_0110_0100_0000b, 0000_1110_0100_0000b, 0100_1100_0100_0000b   ; T
                                ;0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b,\
                                ;0000'1110_1010'0000b, 0110'0100_0110'0000b, 1010'1110_0000'0000b, 1100'0100_1100'0000b;,\;
        figNum          =       ($ - figArr)/8 - 1

        ; # SETTINGS
        ; addl data to ld scoreboard
        Settings.strFileFilter      db    '*.ttr', 0
        Settings.PlaceFormat        db    '#%X', 0
        Settings.Format.File.Temp   db    '%.8s.ttr.tmp', 0
        Settings.Format.File        db    '%.8s.ttr', 0

; ################################################
; ####### UNINITIALIZED MEMORY HERE!!!!! #########
; ################################################
Unitialized_mem:
        ; # Windows
        Wnd.nFontBase                   dd                      ?
        Wnd.msg                         MSG                     ?
        Wnd.paintstruct                 PAINTSTRUCT             ?
        Wnd.pfd                         PIXELFORMATDESCRIPTOR   ?

        font_size                       dd    ?

        Wnd.hwnd                        dd      ?
        Wnd.hrc                         dd      ?
        Wnd.hdc                         dd      ?

        Wnd.wc                          WNDCLASS        ?

        Wnd.rc                          RECT    ?
        ; # Glow data
        Glow.right                      dd      ?
        Glow.left                       dd      ?
        Glow.Arr                        db      FIELD_H dup ? ; initialization!
        ; # Draw
        DFIELD_W                        dq      ?
        clock                           dd      ?
        rect_size                       dd      ? ; initialization
        ; # BUFFER TO SCORE WRITE & GAME RESTORE
GameBuffer:
        GameBuffer.Score                dw      ?
        GameBuffer.ControlWord          dw      ?
        ; # Str
        Str.HighScore                   db      SCOLE_LEN_CONST dup ?
        Str.Score                       db      SCOLE_LEN_CONST dup ?
        ; # Random
        Random.dSeed                    dd      ?
        Random.dPrewNumber              dd      ?
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
        Game.CurTick                    dd      ?
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

        Game.NickName                   db      8 dup ?

        Game.VersionInfo                dd      ?
        Game.VersionCode                dd      ?
        Game.Reserved                   dw      16 dup ?
FILE_SZ_TO_WRITE = ($ - GameBuffer)

        ; # Music
        midihandle                      dd      ?
        SoundPlayer.CurTick             dw      ?
        SoundPlayer.DeltaTick           dw      ?

        SoundPlayer.VolumeMask          dd      ?
        label SoundPlayer.Volume        byte at $ - 2

        ;SoundPlayer.CurEventTick        dw      ?
        SoundPlayer.EndGameTick         dw      ?
        ;SoundPlayer.LineGameTick        dw      ?

        ; # Settings
        Settings.strFilenameBuf         db    16 dup ?

        Settings.strTempLen             dw      ?

        FILE_SZ_TO_READ                 = 4
        Settings.buffer                 db    FILE_SZ_TO_READ dup ?
        Settings.BytesProceed           dd    ?

        Settings.fileData               WIN32_FIND_DATAA            ?
        LB_NAME_STR_LEN                 = 8
        LB_ISTR_RCD_LEN                 = 17
        LB_ISTR_RCD_LEN_POW             = 5; Real mem sz allocated 2^LB_RCDS_AMOUNT
        LB_PRIO_RCD_LEN                 = 4
        LB_BASE_RCDS_AMOUNT             = 16
        LB_MAX_RCDS_AMOUNT              = 1024

        UNINI_MEM_LEN                   = $ - Unitialized_mem

        Settings.LeaderBoardArr         db     (LB_MAX_RCDS_AMOUNT)*(1 shl LB_ISTR_RCD_LEN_POW) dup ?

        ; GAME VERSION
        ; -- App?                       (3 bits)
        GAME_V_APP_LOCAL                = 0
        GAME_V_APP_SERVER               = 1
        GAME_V_APP_CLIENT               = 2
        ; Set here!
        GAME_V_APP                      = GAME_V_APP_LOCAL
        ; -- Platform?                  (3 bits)
        GAME_V_PLATFORM_WIN             = 0
        GAME_V_PLATFORM_ANDROID         = 1
        ; Set here!
        GAME_V_PLATFORM                 = GAME_V_PLATFORM_WIN
        ; -- ASM used?                  (1 bit)
        GAME_V_ASM                      = TRUE
        ; -- Version major (max 255)
        GAME_V_MAJOR                    = 4
        ; -- Version minor (max 63)
        GAME_V_MINOR                    = 8
        ; -- Type?                      (2 bits)
        GAME_V_TYPE_DBG                 = 0
        GAME_V_TYPE_RELEASE             = 11b
        GAME_V_TYPE_BRANCH              = 1
        ; Set here!
        GAME_V_TYPE                     = GAME_V_TYPE_BRANCH
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