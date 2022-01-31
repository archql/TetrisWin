;include '%fasminc%/win32a.inc' ;;ax
;include '%fasminc%/win32a.inc'

format PE GUI 5.0

include '%fasminc%/macro/proc32.inc'
include 'win32ax.inc'

entry start

;===========================
; consts
        SERVER_DEFINED              = TRUE

        FIELD_W = 12; 12
        FIELD_H = 23

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
        ; 0x0000ffff | 0x00010000 = RRF_RT_ANY | RRF_SUBKEY_WOW6464KEY
        invoke  RegGetValueA, HKEY_LOCAL_MACHINE, Client.QuaryValue, Client.QuaryKey, 0x0000ffff or 0x00010000, ebx, Client.PCID, Client.PCIDBufLen
        test    eax, eax
        jnz     creation_error
        end if

        ; set admin nickname
        mov     ecx, NICKNAME_LEN
        mov     edi, Game.NickName
        mov     esi, Str.AdminNickName
        rep     movsb
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
        mov     [Wnd.wc.lpfnWndProc], WindowProc
        mov     [Wnd.wc.lpszClassName], Wnd.class
        ; window creation process
        invoke  GetModuleHandle, ebx
        mov     [Wnd.wc.hInstance],  eax

        invoke  LoadCursor, ebx, IDC_ARROW
        mov     [Wnd.wc.hCursor], eax

        invoke  LoadIcon, ebx, IDI_APPLICATION
        mov     [Wnd.wc.hIcon], eax

        invoke  RegisterClass, Wnd.wc
        test    eax, eax ; check if success
        jz      creation_error; err_reg_class

        ; push wnd data
        push    ebx [Wnd.wc.hInstance] ebx ebx
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
        invoke  GetMessage, Wnd.msg, ebx, ebx, ebx
        or      eax, eax
        jz      end_loop
        invoke  TranslateMessage, Wnd.msg
        invoke  DispatchMessage, Wnd.msg
        jmp     msg_loop

creation_error:
        invoke  MessageBox, ebx, Wnd.Text, Wnd.title, MB_OK or MB_ICONERROR;
  end_loop:
        invoke  ExitProcess, [Wnd.msg.wParam]

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
        mov     [Wnd.pfd.nSize], sizeof.PIXELFORMATDESCRIPTOR
        mov     [Wnd.pfd.nVersion], 1
        mov     [Wnd.pfd.dwFlags], PFD_SUPPORT_OPENGL+PFD_DOUBLEBUFFER+PFD_DRAW_TO_WINDOW
        mov     [Wnd.pfd.iLayerType], PFD_MAIN_PLANE
        mov     [Wnd.pfd.iPixelType], PFD_TYPE_RGBA
        mov     [Wnd.pfd.cColorBits], 16
        mov     [Wnd.pfd.cDepthBits], 16
        ;mov     [Wnd.pfd.cAccumBits], 0 ; ALREADY ZERO
        ;mov     [Wnd.pfd.cStencilBits], 0
        invoke  ChoosePixelFormat, ebx, Wnd.pfd
        invoke  SetPixelFormat, ebx, eax, Wnd.pfd

        ; create gl context
        invoke  wglCreateContext, ebx
        mov     [Wnd.hrc], eax
        invoke  wglMakeCurrent, ebx, eax;[hrc]

        ; set fone color
        invoke  glClearColor, 0.0,0.0,0.0,1.0;0.07, 0.13, 0.17, 1.0



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
        fistp   [font_size]

        ; get sub rect sz
        fld     [rect_size]
        mov     [sub_rect_size], 5
        fild    [sub_rect_size]
        fdivp
        fstp    [sub_rect_size]

        ; get width ratio
        fild    [Wnd.rc.right]
        ; use saved cell width
        fdiv    dword [esp]
        ; move stack back
        add     esp, 4
        ; get result
        fstp    [DFIELD_W]

        ; set font
        xor     ebx, ebx

        ;delete old fonts
        invoke  glDeleteLists, ebx, NUM_OF_CHARACTERS
        ; create font "Lucida Console" sz
        invoke  CreateFontA,[font_size], ebx, ebx, ebx, 600,\
                          ebx, ebx, ebx, ebx, ebx, ebx, ebx, ebx, Wnd.font_name
        invoke  SelectObject, [Wnd.hdc], eax

        invoke  glGenLists, NUM_OF_CHARACTERS
        mov     [Wnd.nFontBase], eax ; save place where bitmaps created
        invoke  wglUseFontBitmapsA, [Wnd.hdc], ebx, NUM_OF_CHARACTERS, eax ; if errors ret 0
        ;invoke  GetLastError

        ; set projection
        invoke  glMatrixMode, GL_PROJECTION
        invoke  glLoadIdentity

        invoke  glOrtho, double 0.0, double [DFIELD_W], double [DFIELD_H], double 0.0, double -1.0, double 1.0

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
        stdcall Game.KeyEvent
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



        ; #####################
        ; # draw other fields #
        ; #####################
        ; set projection
        ;invoke  glMatrixMode, GL_PROJECTION
        ;invoke  glLoadIdentity

        ;invoke  glOrtho, double [DFIELD_LW_SUB], double [DFIELD_W_SUB], double [DFIELD_H_SUB], double [DFIELD_LH_SUB], double -1.0, double 1.0

        ;invoke  glMatrixMode, GL_MODELVIEW
        ; set sz
        ;invoke  glPointSize, [sub_rect_size] ; pixels!!!!
        ; draw
        ;invoke  glBegin, GL_POINTS
        ; draw field
        ;mov     eax, Game.BlocksArr
        ;stdcall View.DrawField
        ; draw figure figure
        ;mov     bx,  word [Game.CurFig]; figure
        ;movzx   esi, word [Game.FigX]  ; X
        ;push    bx esi ; save
        ;movzx   edi, word [Game.FigPreviewY]  ; Y
        ;stdcall View.DrawFigure, 2
        ; draw figure
        ;pop     esi bx
        ;movzx   edi, word [Game.FigY]  ; Y
        ;movzx   eax, byte [Game.CurFigColor]; movzx
        ;stdcall View.DrawFigure, eax
        ; .........
        ;invoke  glEnd
        ; #####################
        ; set projection back
        ;invoke  glMatrixMode, GL_PROJECTION
        ;invoke  glLoadIdentity

        ;invoke  glOrtho, double 0.0, double [DFIELD_W], double [DFIELD_H], double 0.0, double -1.0, double 1.0

        ;invoke  glMatrixMode, GL_MODELVIEW
        ; othre

        invoke  glPointSize, [rect_size] ; pixels!!!!

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

        invoke  glEnd
        ; setup rotation
        fld     [Glow.AnimAngle]
        fld     [Glow.AnimDeltaAngle]
        faddp
        fstp    [Glow.AnimAngle]
        ; set Special color
        mov     eax, 0.9
        ;mov     edi, [Settings.AllocatedMem] ; where mem allocated?
        invoke  glColor3f, eax, eax, eax
        ; draw special effect
        mov     ecx, FIELD_H-1
     .glow_draw:
        movzx  ebx, byte [ecx + Glow.Arr] ;AllocatedMem.glowArr
        ;mov     ebx, 5; tmp
        cmp    ebx, 0
        je     .glow_skip
        ; dec effect
        dec    byte [ecx + Glow.Arr]  ; where mem allocated?
        ; check if effect is too big
        cmp    ebx, GLOW_TIME_TICKS+1
        jg     .glow_skip
        cmp    ebx, GLOW_TIME_TICKS+1
        jl     @F
        ; equal -- so delete line (uses eax, edi, edx)

        mov     edi, Game.BlocksArr + 1
        mov     dx, FIELD_W
        mov     eax, ecx
        dec     eax
        mul     dx ; ax is cur cord
        add     edi, eax

        ; clear line
        xor     eax, eax
        push    ecx
        mov     ecx, FIELD_W - 2
        rep stosb
        pop     ecx

@@:
        ; DO EFFECT
        push   ebx ; copy for fld mul (sp-=4)
        ; count cur effect sz
        fld    [Glow.SZ_delta]
        fild   dword [esp]
        fmulp  st1, st0
        fst    dword [Glow.right]
        fchs
        fstp   dword [Glow.left]
        ; load it to regs
        mov    esi, [Glow.right]
        mov    edi, [Glow.left]

        ; load ebx to fpu (Y cord)
        mov    dword [esp], ecx; load Y cord
        fild   dword [esp]     ; load Y cord to FPU
        fstp   dword [esp]     ; convert to float Y cord

        sub     esp, 4 ; reserve place on stack to float X cord  (sp-=4)

        push    ecx            ; (sp-=4)
        mov     ecx, FIELD_W - 2
     .inner_glow_draw:
        push    ecx            ; (sp-=4)
        ; timed sol
        inc     ecx
        push    ecx
        ; load X cord (ecx) to FPU
        fild    dword [esp]    ; cur int X cord
        add     esp, 4         ; reset stack (temp)
        fstp    dword [esp + 8]

        ; test rotating rect draw
        invoke  glPushMatrix;
        invoke  glTranslatef, dword [esp + 16], dword [esp + 16], 0.0  ;  esp -= 4 happened 2xtimes
        invoke  glRotatef, [Glow.AnimAngle], 0.0, 0.0, 5.0;
        invoke  glBegin, GL_QUADS

                invoke  glVertex2f, edi, edi
                invoke  glVertex2f, esi, edi
                invoke  glVertex2f, esi, esi
                invoke  glVertex2f, edi, esi

        invoke  glEnd
        invoke  glPopMatrix

        ; load loop cntr (X cord)
        pop     ecx    ;(sp+=4)
        loop    .inner_glow_draw
        ; load loop cntr (Y cord)
        pop     ecx    ;(sp+=4)
        ; free stack (from reserved for X and Y cord)
        add     esp, 8 ;(sp+=8)
        ; go next
      .glow_skip:
        dec     ecx
        test    ecx, ecx
        jnz  .glow_draw
        ; end test glow draw

        ; BEGIN text draw
        invoke  glListBase, [Wnd.nFontBase]
        ; draw text NEXT FIG
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2;
        invoke  glCallLists, Str.NextFig.Len, GL_UNSIGNED_BYTE, Str.NextFig
        ; draw text HOLDED FIG
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2 + 6;
        invoke  glCallLists, Str.HoldedFig.Len, GL_UNSIGNED_BYTE, Str.HoldedFig
        ; DRAW text SCORE
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2 + 4 + 6 + 2;
        invoke  glCallLists, SCOLE_LEN_CONST, GL_UNSIGNED_BYTE, Str.Score
        ; DRAW text SCORE HIGH
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2 + 4 + 6 + 3;
        invoke  glCallLists, SCOLE_LEN_CONST, GL_UNSIGNED_BYTE, Str.HighScore

        ; DRAW text SCOREBOARD
        invoke  glRasterPos2i, FIELD_W + 3 - 1 + 8, 2;
        invoke  glCallLists, LB_ISTR_RCD_LEN, GL_UNSIGNED_BYTE, Str.Scoreboard
        ; DRAW Scoreboard
        ; 1st: find amount of actual strings
        ; ERROR!!
        mov     edi, Settings.LeaderBoardArr
        mov     esi, edi
        add     esi, (1 shl LB_ISTR_RCD_LEN_POW) - LB_PRIO_RCD_LEN
        mov     ecx, LB_BASE_RCDS_AMOUNT - 1
.DrawScoreboardLoop:
        ; check if null user
        mov     ebx, [esi]
        test    bx, bx
        jz      .loopSkipLine
        ; save base pos
        and     ebx, $FF'FF'00'00
        shr     ebx, 16 - LB_ISTR_RCD_LEN_POW; got real place
        push    edi
        add     edi, ebx

        ; count Y pos
        push    ecx; save loop ctr
        xchg    ebx, ecx
        neg     ebx
        add     ebx, LB_BASE_RCDS_AMOUNT
        ; print cur place
        cinvoke wsprintfA, edi, Settings.PlaceFormat, ebx
        ; mov Y cord
        add     ebx, 2 ; 3 - 1

        ; draw
        invoke  glRasterPos2i, FIELD_W + 3 - 1 + 8, ebx;dword [esp + 4];
        invoke  glCallLists, LB_ISTR_RCD_LEN, GL_UNSIGNED_BYTE, edi

        pop     ecx
        pop     edi

.loopSkipLine:
        add     esi, (1 shl LB_ISTR_RCD_LEN_POW); LEN_OF_LB_INFO_RCD
        loop    .DrawScoreboardLoop

        ; Draw CurNickName
        invoke  glRasterPos2i, FIELD_W + 3 - 1 + 8, FIELD_H - 2;
        invoke  glCallLists, 8, GL_UNSIGNED_BYTE, Game.NickName

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
        invoke  glRasterPos2f, 22.0 , 22.7 ;FIELD_W + 3 - 1 + 8, FIELD_H - 1 + 1;
        invoke  glCallLists, 8, GL_UNSIGNED_BYTE, Settings.strTempNickNameHighlight
        ; set Special color
        mov     eax, 1.0
        invoke  glColor3f, eax, eax, eax
@@:
        ; Draw Main Str
        invoke  glRasterPos2i, FIELD_W + 3 - 1 + 8, FIELD_H - 1;
        invoke  glCallLists, 8, GL_UNSIGNED_BYTE, ebx

        if (SERVER_DEFINED)
        ; check connection
        mov     ebx, Client.StrError
        mov     dx, 11
        movzx   eax, word [Client.State]
        mul     dx
        add     ebx, eax

        ; DRAW text connection
        invoke  glRasterPos2i, FIELD_W + 2, FIELD_H;
        invoke  glCallLists, CLIENT_STR_LEN, GL_UNSIGNED_BYTE, ebx
        ; DRAW text connections
        mov     esi, Client.ClientsDataArr
        mov     ecx, 2 ; loop ctr
.printConnectionsLoop:
        ; save loop ctr
        push    ecx
        ; check if not null (ping > 0)
        mov     bx, word [esi + NICKNAME_LEN]
        cmp     bx, 0
        jle     @F
        ; DRAW text connection
        ; TEMP
        ;mov     ax, bx  ; !!!! || THREAD CAN CHANGE IT
        ;add     ax, 'AA'
        ;mov     word [GameBuffer], ax
        invoke  glRasterPos2i, FIELD_W + 2 + 8 + 11, ecx;
        invoke  glCallLists, NICKNAME_LEN, GL_UNSIGNED_BYTE, esi   ; TEST -- CLIENT_CL_RCD_LEN
        ;invoke  glCallLists, 2, GL_UNSIGNED_BYTE, GameBuffer   ; TEST -- CLIENT_CL_RCD_LEN
        ; inc ctr
        inc     dword [esp]
@@:
        add     esi, CLIENT_CL_RCD_LEN
        ; restore loop ctr
        pop     ecx
        ; test  "ping" ; WARN IF OVERFLOW (MAX RCD 64)
        test    bx, bx
        jnz     .printConnectionsLoop
        end if

        cmp     [Game.Playing], 1
        je      @F
        ; DRAW text GAME OVER
        invoke  glRasterPos2i, FIELD_W / 2 - 2, 2;
        invoke  glCallLists, 9, GL_UNSIGNED_BYTE, Str.Loose
        jmp     .end_draw
@@:
        cmp     [Game.Pause], 1
        jne     @F
        ; DRAW text PAUSE
        invoke  glRasterPos2i, FIELD_W / 2 - 1, 2;
        invoke  glCallLists, 6, GL_UNSIGNED_BYTE, Str.Pause
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
        cmp     [Client.State], 2
        je      .regularKeyEvent
        cmp     [Client.State], 1
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
        end if
        ; music
        stdcall SoundPlayer.Close
        ; font lists
        invoke  glDeleteLists, 0, NUM_OF_CHARACTERS
        ; gl & window
        invoke  wglMakeCurrent, 0, 0
        invoke  wglDeleteContext, [Wnd.hrc]
        invoke  ReleaseDC, [hwnd], [Wnd.hdc]
        invoke  PostQuitMessage, 0
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
        RegGetValueA , 'RegGetValueA'

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
         glRasterPos2f, 'glRasterPos2f'
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