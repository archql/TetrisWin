;include '%fasminc%/win32a.inc' ;;ax
;include '%fasminc%/win32a.inc'
; test

format PE GUI 5.0

include '%fasminc%/macro/proc32.inc'
include 'win32ax.inc'

entry start

;===========================
; consts
        SERVER_DEFINED              = TRUE

        TRUE    = 1
        FALSE   = 0

        START_TICK_SPEED = 500
        GLOW_TIME_TICKS  = 15

        NUM_OF_CHARACTERS = 128

        INC_EVERY_FIGS=15 ;2^N-1

;===========================
;section '.data' data readable writable
;===========================
section '.code' code executable readable ;writable  ; code section
start:
        ; zero
        xor     ebx, ebx
        ; zero allocated memory
        xor     eax, eax
        mov     ecx, UNINI_MEM_LEN
        mov     edi, Unitialized_mem
        rep     stosb
        ; set Client.PCID (unique PC ID)
        if (SERVER_DEFINED)
        invoke  RegOpenKeyExA, HKEY_LOCAL_MACHINE, Client.QuaryValue, ebx, KEY_READ or 0x0100, Client.KeyHandle   ;KEY_WOW64_64KEY
        test    eax, eax
        jnz     @F
        invoke  RegGetValueA, [Client.KeyHandle], Client.QuaryKey - 1, Client.QuaryKey, 0x0000ffff, ebx, Client.PCID, Client.PCIDBufLen ; Client.QuaryKey - 1 -- NULL STRING
        test    eax, eax
     @@:
        jz      @F
        ; Throw error
        mov     [Client.State], CLIENT_STATE_UUIDERROR ; Error
     @@:
        end if
        ; set nickname
        stdcall Settings.GetLastNick
        ; zero
        xor     ebx, ebx
        ; =====
        ; Setup Game Version
        ; FORMATT: 1' Platform code' ASM? ' App type ' Version major ' Version minor ' DBG|RELEASE|BRANCH ' Random type ' Rotation type ' Speed type ' Reserved
        ;mov     [Game.VersionCode], 1'000'0'000_00000000_000000'00_00'00'00'00b
        mov     [Game.VersionCode], (1               shl 31) or\
                                    (GAME_V_PLATFORM shl 28) or\
                                    (GAME_V_ASM      shl 27) or\
                                    (GAME_V_APP      shl 24) or\
                                    (GAME_V_MAJOR    shl 16) or\
                                    (GAME_V_MINOR    shl 10) or\
                                    (GAME_V_TYPE     shl  8) or\
                                    (GAME_V_RND_TYPE shl  6) or\
                                    (GAME_V_ROT_TYPE shl  4) or\
                                    (GAME_V_SPD_TYPE shl  2)
        mov     [Game.VersionInfo], Wnd.title
        ; ====
        ; setup Wnd.wc
        mov     esi, Wnd.wc
        mov     [esi + (Wnd.wc.lpfnWndProc - Wnd.wc)], WindowProc
        mov     [esi + (Wnd.wc.lpszClassName - Wnd.wc)], Wnd.class
        ; window creation process
        invoke  GetModuleHandle, ebx
        mov     [esi + (Wnd.wc.hInstance - Wnd.wc)],  eax

        invoke  LoadCursor, ebx, IDC_ARROW
        mov     [esi + (Wnd.wc.hCursor - Wnd.wc)], eax

        invoke  LoadIcon, ebx, IDI_APPLICATION
        mov     [esi + (Wnd.wc.hIcon - Wnd.wc)], eax

        invoke  RegisterClass, esi
        test    eax, eax ; check if success
        jz      creation_error; err_reg_class

        ; push wnd data
        push    ebx [esi + (Wnd.wc.hInstance - Wnd.wc)] ebx ebx
        ; push wnd szs
        ; get screen ratio
        invoke  GetSystemMetrics, SM_CYSCREEN   ; hei
        push    eax
        invoke  GetSystemMetrics, ebx  ; width
        push    eax

        invoke  CreateWindowEx, ebx, Wnd.class, Wnd.title,WS_POPUP+WS_VISIBLE+WS_SYSMENU,\          ;+WS_VISIBLE+WS_OVERLAPPEDWINDOW+WS_CLIPCHILDREN+WS_CLIPSIBLINGS
                                     ebx, ebx
        test    eax, eax ; check if success
        jz      creation_error; err_reg_class
        mov     [Wnd.hwnd], eax

        if (SERVER_DEFINED)
        ; create critical section to protect write-send (for multithreaded app)
        invoke  InitializeCriticalSectionAndSpinCount, Client.CritSection, 0x400 ; 0x400 tries to capture crit section b4 go to core speed
        end if

        ; call music ini
        stdcall SoundPlayer.Ini
        ; call game initialization
        call    Game.IniField

        call    Random.Initialize
        ;stdcall Game.GenNewFig
        stdcall Game.Initialize

        ; loop
  msg_loop:
        xor     ebx, ebx; NULL = zero
        mov     esi, Wnd.msg
        invoke  GetMessage, esi, ebx, ebx, ebx
        or      eax, eax
        jz      end_loop
        invoke  TranslateMessage, esi
        invoke  DispatchMessage, esi
        jmp     msg_loop

creation_error:
        invoke  MessageBox, ebx, Wnd.Text, Wnd.title, MB_OK or MB_ICONERROR;
  end_loop:
        invoke  ExitProcess, [Wnd.msg.wParam]

;############# ThrowMessage ##################
proc ThrowMessage; eax is ptr to string, ebx is zero!
        invoke  MessageBox, ebx, eax, Wnd.title, MB_OK or MB_ICONERROR;
        ret
endp

;############# WindowProc ####################

proc WindowProc uses ebx esi edi,\
                hwnd, wmsg, wparam, lparam
        mov     ebx, [wmsg]
        cmp     ebx, WM_CREATE
        je      .wmcreate
        cmp     ebx, WM_SIZE
        je      .wmsize
        cmp     ebx, WM_PAINT
        je      .wmpaint
        cmp     ebx, WM_KEYDOWN
        je      .wmkeydown
        cmp     ebx, WM_KEYUP
        je      .wmkeyup
        cmp     ebx, WM_DESTROY
        je      .wmdestroy
  .defwndproc:
        invoke  DefWindowProc,[hwnd],ebx,[wparam],[lparam]
        jmp     .finish
  .wmcreate:
        invoke  GetDC,[hwnd]
        mov     [Wnd.hdc], eax
        mov     ebx, eax  ; hdc

        ; initialize OpenGL
        ;mov     edi,pfd
        ;mov     ecx,sizeof.PIXELFORMATDESCRIPTOR shr 2
        ;xor     eax,eax
        ;rep     stosd
        mov     esi, Wnd.pfd
        mov     [esi + (Wnd.pfd.nSize - Wnd.pfd)], sizeof.PIXELFORMATDESCRIPTOR
        mov     [esi + (Wnd.pfd.nVersion - Wnd.pfd)], 1
        mov     [esi + (Wnd.pfd.dwFlags - Wnd.pfd)], PFD_SUPPORT_OPENGL+PFD_DOUBLEBUFFER+PFD_DRAW_TO_WINDOW
        mov     [esi + (Wnd.pfd.iLayerType - Wnd.pfd)], PFD_MAIN_PLANE
        mov     [esi + (Wnd.pfd.iPixelType - Wnd.pfd)], PFD_TYPE_RGBA
        mov     [esi + (Wnd.pfd.cColorBits - Wnd.pfd)], 16
        mov     [esi + (Wnd.pfd.cDepthBits - Wnd.pfd)], 16
        ;mov     [Wnd.pfd.cAccumBits], 0 ; ALREADY ZERO
        ;mov     [Wnd.pfd.cStencilBits], 0
        invoke  ChoosePixelFormat, ebx, esi
        invoke  SetPixelFormat, ebx, eax, esi

        ; create gl context
        invoke  wglCreateContext, ebx
        mov     [Wnd.hrc], eax
        invoke  wglMakeCurrent, ebx, eax;[hrc]

        ; set fone color
        xor     eax, eax
        invoke  glClearColor, eax,eax,eax,1.0;0.07, 0.13, 0.17, 1.0

        ; set clock
        invoke  GetTickCount
        mov     [clock], eax
        mov     [Game.CurTick], eax
        xor     eax, eax
        jmp     .finish
  .wmsize:
        xor     ebx, ebx
        invoke  GetClientRect, [hwnd], Wnd.rc
        invoke  glViewport, ebx, ebx, [Wnd.rc.right], [Wnd.rc.bottom]

        sub     esp, 4; reserve stack for cell width
        ; get rect size
        fild    dword [Wnd.rc.bottom]
        fdiv    [DFIELD_H]
        fst     dword [esp]; save cell width

        fmul    [RECT_MODIFIER]; modify (rect should be < than cell on screen)
        frndint  ; round
        fst     [rect_size]
        fchs
        fistp   [Wnd.fontSz]

        ; get width ratio
        fild    [Wnd.rc.right]
        ; use saved cell width
        fdiv    dword [esp]
        ; move stack back
        add     esp, 4
        ; get result
        fstp    [DFIELD_W]

        ; create font DUPLICATED TEST!!!
        mov     esi, Wnd.font; ptr to font struct
        stdcall View.CreateFont

        ; set projection
        invoke  glMatrixMode, GL_PROJECTION
        invoke  glLoadIdentity

        xor     ebx, ebx ; double 0.0 == double push 0
        invoke  glOrtho, ebx, ebx, double [DFIELD_W], double [DFIELD_H], ebx, ebx, double -1.0, double 1.0

        invoke  glMatrixMode, GL_MODELVIEW

        ; exit with success
        xor     eax,eax
        jmp     .finish
  .wmpaint:
        invoke  GetTickCount
        push    eax; copy res

        ;stdcall SoundPlayer.LineEventUpdate; got eax in [esp] as param
        mov     eax, dword [esp]
        stdcall SoundPlayer.EndEventUpdate; got eax in [esp] as param

        ; CHECK IF GAME RUNNING
        cmp     [Game.Playing], TRUE
        jne     .animation
        cmp     [Game.Pause], FALSE
        jne     .animation

        ; update keypress
        ;mov     eax, dword [esp]
        ;sub     ax, [Keyboard.Clock]
        ;cmp     ax, KEY_EVENT_UPDATE;300; temp
        ;jb      @F
        ;add     [Keyboard.Clock], ax
        ;xor     ax, ax
        ;stdcall Game.KeyEvent
    ;@@:

        ; check on snd
        test    [Game.MusicOff], 1
        jnz     @F
        mov     eax, dword [esp]
        stdcall SoundPlayer.Update ; got eax in [esp] as param
@@:

        ; define game tick update
        mov     eax, dword [esp]
        sub     eax, [Game.CurTick]
        movzx   edx, [Game.TickSpeed]
        and     [Game.SoftDrop], 1
        jz      @F
        shr     edx, 2
@@:
        cmp     eax, edx;300; temp
        jb      @F
        add     [Game.CurTick], eax
        add     [Game.TicksPlayed], eax
        ; call game update
        mov     eax, 7; key with ID 7 is undefined
        stdcall Game.KeyEvent ; Safe call?
@@:
.animation:
        ; define animation
        pop     eax
        sub     eax,[clock]
        cmp     eax, 10
        jb      .finish
        add     [clock], eax; reset timer

      ;.animation_ok:
        invoke  glClear,GL_COLOR_BUFFER_BIT
        invoke  glLoadIdentity

        cmp     [View.MenuChosen], 0
        je      .ViewMenu_1

        ; #####################
        ; #     -MENU #2-     #
        ; # draw other fields #
        ; #####################
   .ViewMenu_2:
        ; get scale factor
        xor     eax, eax ; pow
        xor     ebx, ebx ; scale f
        inc     ebx
        xor     ecx, ecx ; loop ctr
        mov     esi, Client.ClientsDataArr ;+ CLIENT_CL_RCD_LEN ; 2nd rcd (check if correspond to cur user?)
  .ClientsDataArrLoop:
        mov     dx, word [esi + NICKNAME_LEN] ; get ping
        test    dx, dx
        jz      .ClientsDataArrLoopEnd
        js      .ClientsDataArrLoopNext
        ; get rcd info
        ; skip if cur user rcd
        ; inc counter
        inc     ecx
        ; if ctr > pow
        cmp     ecx, eax
        jle     @F
        ; yes -- set new pow
        inc     ebx ; ??
        mov     eax, ebx
        mul     eax ; edx is corrypted here
@@:
   .ClientsDataArrLoopNext:
        add     esi, CLIENT_CL_RCD_LEN
        jmp     .ClientsDataArrLoop
   .ClientsDataArrLoopEnd:
        ; SET OFFSET
        mov     edi, sub_
        ; now scale factor is in ebx (int)
        cmp     dword [edi + (sub_scale - sub_)], ebx
        je      .PrevScaleIsOk
        mov     dword [edi + (sub_scale - sub_)], ebx  ; its buf (temp)
        fild    dword [edi + (sub_scale - sub_)]
        ; get rect sz here
        fld     dword [rect_size]
        fdiv    st0, st1
        fst     dword [edi + (sub_rect_size - sub_)]
        ; get font sz
        fchs
        fistp   dword [edi + (sub_font_sz - sub_)]
        ; get inverted scale
        fld1
        fdiv    st0, st1
        fstp    dword [edi + (sub_inv_scale_f - sub_)]
        fstp    dword [edi + (sub_scale_f - sub_)]
        ;fst     dword [sub_inv_scale_f]
        ;fstp    dword [sub_scale_f]
        ;mov     eax, 7F000000H
        ;sub     eax, dword [sub_inv_scale_f]
        ;mov     dword [sub_inv_scale_f], eax
        push    edi ; save sub_ offset
        ; create font DUPLICATED TEST!!!
        mov     esi, sub_font; ptr to font struct
        stdcall View.CreateFont

        ; restore sub_ offset
        pop     edi ; restore sub_ offset

        ; we're ready!
.PrevScaleIsOk:
        ; set font
        invoke  glListBase, [edi + (sub_font_base - sub_)]
        ; translate draw point
        invoke  glTranslatef, 22.0, 0.0, 0.0  ; DFIELD_W + 3 - 1 + 8 = 23
        ; scale
        invoke  glScalef, [edi + (sub_inv_scale_f - sub_)], [edi + (sub_inv_scale_f - sub_)], 1.0
        ; set draw
        invoke  glPointSize, [edi + (sub_rect_size - sub_)] ; pixels!!!!
        ; Now loop through ClientsDataArr again!
        xor     ebx, ebx ; loop ctr
        mov     esi, Client.ClientsDataArr ;+ CLIENT_CL_RCD_LEN ; 2nd rcd (check if correspond to cur user?)
  .ClientsDataArrLoop2:
        mov     dx, word [esi + NICKNAME_LEN] ; get ping
        test    dx, dx
        jz      .ClientsDataArrLoopEnd2
        js      .ClientsDataArrLoopNext2
        ; get rcd info
        ; skip if cur user rcd
        ; draw user
        stdcall View.DrawGame ; loop ctr in ebx, pos in esi+2 (save it)
        ; inc counter
        inc     ebx
@@:
   .ClientsDataArrLoopNext2:
        add     esi, CLIENT_CL_RCD_LEN
        jmp     .ClientsDataArrLoop2
   .ClientsDataArrLoopEnd2:
        ; restore sub_ offset
        mov     edi, sub_
        ; Scale Back
        invoke  glScalef, [edi + (sub_scale_f - sub_)], [edi + (sub_scale_f - sub_)], 1.0
        ; translate draw point back
        invoke  glTranslatef, -22.0, 0.0, 0.0  ; DFIELD_W + 3 - 1 + 8 = 23
        ; set rect sz back
        invoke  glPointSize, [rect_size] ; pixels!!!!
        ; Return text draw
        invoke  glListBase, [Wnd.nFontBase]

        jmp     .ViewMenu_End
        ; #####################
        ; #     -MENU #1-     #
        ; # draw leaderboard  #
        ; #####################
  .ViewMenu_1:
        ; set rect sz
        invoke  glPointSize, [rect_size] ; pixels!!!!
        ; text draw set
        invoke  glListBase, [Wnd.nFontBase]
        ; DRAW text SCOREBOARD
        stdcall View.DrawText, FIELD_W + 3 - 1 + 8, 2        , LB_ISTR_RCD_LEN  , eax, Str.Scoreboard
        ; DRAW Scoreboard
        stdcall Client.ThSafeCall, View.DrawLeaderboard
        ; DRAW connections
        if (SERVER_DEFINED)
        stdcall View.DrawConnections
        end if
   .ViewMenu_End:
        ;#######################
        if (SERVER_DEFINED)
        ; check connection
        mov     ebx, Client.StrError
        mov     dx,  CLIENT_STR_LEN
        movzx   eax, word [Client.State]
        mul     dx
        add     ebx, eax
        ; DRAW text connection
        stdcall View.DrawText, FIELD_W + 3, FIELD_H, CLIENT_STR_LEN, eax, ebx
        end if

        ; draw
        invoke  glBegin, GL_POINTS
        ; draw field
        mov     eax, Game.BlocksArr
        stdcall View.DrawField
        ; draw figure figure
        mov     bx,  word [Game.CurFig]; figure
        movzx   esi, word [Game.FigX]  ; X
        push    bx esi ; save
        movzx   edi, word [Game.FigPreviewY]  ; Y
        stdcall View.DrawFigure, 2
        ; draw figure
        pop     esi bx
        movzx   edi, word [Game.FigY]  ; Y
        movzx   eax, byte [Game.CurFigColor]; movzx
        stdcall View.DrawFigure, eax
        ; draw next figure
        mov     bx,  word [Game.NextFig]
        mov     esi, FIELD_W + 3; X
        mov     edi, 2  ; Y
        stdcall View.DrawFigure, 3;//????
        ; draw holded figure
        mov     bx,  word [Game.HoldedFig]
        mov     esi, FIELD_W + 3; X
        mov     edi, 2  +  4  +  2 ; Y
        stdcall View.DrawFigure, 3;//????
        ; end draw points
        invoke  glEnd

        ; draw glow
        stdcall View.DrawGlow

        ; draw text NEXT FIG
        stdcall View.DrawText, FIELD_W + 3 - 1, 2            , Str.NextFig.Len  , eax, Str.NextFig
        ; draw text HOLDED FIG
        stdcall View.DrawText, FIELD_W + 3 - 1, 2 + 6        , Str.HoldedFig.Len, eax, Str.HoldedFig
        ; DRAW text SCORE
        stdcall View.DrawText, FIELD_W + 3    , 2 + 4 + 6 + 2, SCOLE_LEN_CONST  , eax, Str.Score
        ; DRAW text SCORE HIGH
        stdcall View.DrawText, FIELD_W + 3    , 2 + 4 + 6 + 3, SCOLE_LEN_CONST  , eax, Str.HighScore

        ; Draw CurNickName
        stdcall View.DrawText, FIELD_W + 3 - 1 + 1, FIELD_H - 3, 8, eax, Game.NickName
        ; Draw TmpNickName
        mov     ebx, Settings.strTempNickNameBlocked
        ; If setup mode activated
        test    [Settings.SetupNickNameActive], TRUE
        jz      @F
        ; set str
        mov     ebx, Settings.strTempNickName
        ; set Special color
        mov     eax, 1.0
        invoke  glColor3f, eax, ebx, ebx
        ; Draw HighLight
        invoke  glRasterPos2f, 15.0 , 21.7 ;FIELD_W + 3 - 1 , FIELD_H - 1 + 1;
        invoke  glCallLists, 8, GL_UNSIGNED_BYTE, Settings.strTempNickNameHighlight
        ; set Special color
        stdcall View.FastWhiteColor
@@:
        ; Draw Main Str
        stdcall View.DrawText, FIELD_W + 3 - 1 + 1, FIELD_H - 2, 8, eax, ebx

        cmp     [Game.Playing], 1
        je      @F
        ; DRAW text GAME OVER
        stdcall View.DrawText, FIELD_W / 2 - 2, 2, 9, eax, Str.Loose
        jmp     .end_draw
@@:
        cmp     [Game.Pause], 1
        jne     @F
        ; DRAW text PAUSE
        stdcall View.DrawText, FIELD_W / 2 - 1, 2, 6, eax, Str.Pause
@@:
        ; end draw;
.end_draw:
        invoke  SwapBuffers,[Wnd.hdc]

        xor     eax,eax
        jmp     .finish
  .wmkeydown:
        ; save key pressed
        mov     ebx, [wparam]
        ; get key state
        invoke  GetKeyState, VK_CONTROL
        ; swap registers
        xchg    ebx, eax
        ; check if keyboard mode activated
        test    ebx, 0x00'00'80'00
        jz      .regularKeyEvent
        ; check if game ended
        cmp    [Game.Score], 0
        jnz     .regularKeyEvent
        ; check if connected to network with fixed nickname
        if (SERVER_DEFINED)
        cmp     [Client.State], CLIENT_STATE_REGISTERED
        je      .regularKeyEvent
        cmp     [Client.State], CLIENT_STATE_ONLINE
        je      .regularKeyEvent
        end if
        ; activate edit mode
        mov     [Settings.SetupNickNameActive], TRUE

        include 'nickname_setup.asm'

.regularKeyEvent:
        ; check regular key events
        cmp     eax, 'R' ; restart
        jne     @F
        stdcall Game.End
        stdcall Game.Initialize
@@:
        cmp     eax, 'P'
        jne     @F
        stdcall SoundPlayer.Pause
        xor     [Game.Pause], 1
@@:
        if (SERVER_DEFINED)
        ; MENU CHANGE VIEW
        cmp     eax, VK_F2
        jne     @F
        ;mov     ax, [View.MenuChosen]
        inc     word [View.MenuChosen]
        and     word [View.MenuChosen], 1; Menus amount
@@:
        ; CLIENT START
        cmp     eax, VK_F3
        jne     @F
        ; ini client if not ini
        stdcall Client.Init
@@:
        ; CLIENT REQUEST GAME (SAME SEED)
        cmp     eax, VK_F4
        jne     @F
        cmp     [Game.Playing], TRUE
        je      @F
        ; send msg
        stdcall Client.RequestGame
@@:
        end if
        ; MUSIC
        cmp     eax, 'M'
        jne     @F
        stdcall SoundPlayer.Pause
        xor     [Game.MusicOff], 1
@@:
        cmp     eax, 0xDB ; '['
        jne     @F
        cmp     [SoundPlayer.Volume], 0x07
        jbe     @F
        sub     [SoundPlayer.Volume], 0x0F
@@:
        cmp     eax, 0xDD ; ']'
        jne     @F
        cmp     [SoundPlayer.Volume], 0x7F
        jae     @F
        add     [SoundPlayer.Volume], 0x0F
@@:
        cmp     eax, VK_SHIFT
        jne     @F
        mov     [Game.SoftDrop], TRUE
@@:
        ; TEMP
        cmp     [Game.Playing], TRUE
        jne     @F
        cmp     [Game.Pause], FALSE
        jne     @F
        stdcall Game.KeyEvent
@@:
        ;cmp     eax, VK_LEFT
        ;jb      @F
        ;cmp     eax, VK_RIGHT
        ;ja      @F
        ; check press of key
        ;mov     ecx, eax
        ;sub     ecx, VK_LEFT
        ;mov     dl, 1
        ;shl     dl, cl
        ;or      byte [Keyboard.Pressed], dl
;@@:
        cmp     eax, VK_ESCAPE
        jne     .defwndproc
        cmp     [Game.Playing], FALSE
        je      .wmdestroy
        ; stop game
        stdcall Game.End
        jmp     .defwndproc
  .wmkeyup:
        mov     eax, [wparam]
        cmp     eax, VK_SHIFT
        jne     @F
        mov     [Game.SoftDrop], FALSE
@@:
        cmp     eax, VK_CONTROL
        jne     @F
        ; deactivate edit mode
        mov     [Settings.SetupNickNameActive], FALSE
@@:
        ;cmp     eax, VK_LEFT
        ;jb      @F
        ;cmp     eax, VK_RIGHT
        ;ja      @F
        ; check press of key
        ;mov     ecx, eax
        ;sub     ecx, VK_LEFT
        ;mov     dl, 1
        ;shl     dl, cl
        ;xor     byte [Keyboard.Pressed], dl
;@@:
        jmp     .defwndproc
  .wmdestroy:
        ; server conn
        if (SERVER_DEFINED)
        stdcall Client.Destroy
        ; del critical section
        invoke  DeleteCriticalSection, Client.CritSection
        ; end if
        end if
        ; save last logged nickname?
        stdcall Settings.SetLastNick, Settings.File.Name, Game.NickName, NICKNAME_LEN
        ; music
        stdcall SoundPlayer.Close
        ; zero
        xor     ebx, ebx
        ; font lists
        invoke  glDeleteLists, ebx, NUM_OF_CHARACTERS
        ; gl & window
        invoke  wglMakeCurrent, ebx, ebx
        invoke  wglDeleteContext, [Wnd.hrc]
        invoke  ReleaseDC, [hwnd], [Wnd.hdc]
        invoke  PostQuitMessage, ebx
        xor     eax, eax
  .finish:
        ret
endp



        include 'game.asm'
        include 'view.asm'
        include 'settings.asm'
        include 'units\random.h'

        DWORDS_TO_COUNT_CONTROL_SUM     = ($ - start) / 4

        include 'music.asm'

        include 'client.asm'

;===========================

section '.idata' import data readable writeable

        library gdi32,'GDI32.DLL',\
        kernel32,'KERNEL32.DLL',\
        user32,'USER32.DLL',\
        winmm,'WINMM.DLL',\
        opengl,'OPENGL32.DLL',\
        ws2_32, 'ws2_32.dll',\
        AdvApi32, 'AdvApi32.dll',\
        iphlpapi, 'iphlpapi.dll'

        include 'api\gdi32.inc'
        include 'api\kernel32.inc'
        include 'api\user32.inc'
                
        include 'opengl.inc'

import iphlpapi,\
        GetIpAddrTable , 'GetIpAddrTable'
        ; THIS STRUCTURES GOT FROM INTERNET. THEY MAY BE CHANGED!
        struct MIB_IPADDRROW
               dwAddr           dd              ?
               dwIndex          dd              ?
               dwMask           dd              ?
               dwBCastAddr      dd              ?
               dwReasmSize      dd              ?
               unused1          dw              ?
               wType            dw              ?
        ends
        struct MIB_IPADDRTABLE
               dwNumEntries     dd              ?
               table            MIB_IPADDRROW   ?
        ends

        struct RTL_CRITICAL_SECTION
                DebugInfo       dd      ?;  Its ptr
                LockCount       dd      ?;  LONG
                RecursionCount  dd      ?;  LONG
                OwningThread    dd      ?;  HANDLE      // from the thread's ClientId->UniqueThread
                LockSemaphore   dd      ?;  HANDLE
                SpinCount       dd      ?;  ULONG_PTR   // force size on 64-bit systems when packed
        ends

import AdvApi32,\
        RegGetValueA , 'RegGetValueA',\
        RegQueryValueExA, 'RegQueryValueExA',\
        RegOpenKeyA, 'RegOpenKeyA',\
        RegOpenKeyExA, 'RegOpenKeyExA'

import winmm,\
        mciSendString,'mciSendStringA',\
        PlaySound , 'PlaySound',\
        midiOutOpen,'midiOutOpen',\
        midiOutShortMsg, 'midiOutShortMsg',\
        midiOutClose, 'midiOutClose',\
        midiOutLongMsg, 'midiOutLongMsg'

import opengl,\
         glBegin,'glBegin',\
         glCallLists,'glCallLists',\
         glClear,'glClear',\
         glClearColor,'glClearColor',\
         glColor3f,'glColor3f',\
         glDeleteLists,'glDeleteLists',\
         glEnd,'glEnd',\
         glGenLists,'glGenLists',\
         glLoadIdentity,'glLoadIdentity',\
         glMatrixMode,'glMatrixMode',\
         glOrtho,'glOrtho',\
         glPointSize,'glPointSize',\
         glPopMatrix,'glPopMatrix',\
         glPushMatrix,'glPushMatrix',\
         glRasterPos2i,'glRasterPos2i',\
         glRenderMode,'glRenderMode',\
         glRotatef,'glRotatef',\
         glTranslatef,'glTranslatef',\
         glVertex2f,'glVertex2f',\
         glVertex2i,'glVertex2i',\
         glViewport,'glViewport',\
         wglCreateContext,'wglCreateContext',\
         wglDeleteContext,'wglDeleteContext',\
         wglMakeCurrent,'wglMakeCurrent',\
         wglUseFontBitmapsA,'wglUseFontBitmapsA',\
         glListBase, 'glListBase',\
         glRasterPos2f, 'glRasterPos2f',\
         glScalef, 'glScalef'
import ws2_32,\
        WSAStartup, 'WSAStartup',\
        socket, 'socket',\
        bind, 'bind',\
        sendto, 'sendto',\
        recvfrom, 'recvfrom',\
        setsockopt, 'setsockopt',\
        closesocket, 'closesocket',\
        WSACleanup, 'WSACleanup'

; ####### DATA HERE ###################
        include 'tetrisdata.asm'