;include '%fasminc%/win32a.inc' ;;ax
;include '%fasminc%/win32a.inc'

format PE GUI 4.0
stack 0x100000

include 'win32ax.inc'

entry start

;===========================
; consts
        SERVER_DEFINED              = FALSE

        TRUE    = 1
        FALSE   = 0

        START_TICK_SPEED = 1000
        GLOW_TIME_TICKS  = 15

        NUM_OF_CHARACTERS = 128

        INC_EVERY_FIGS=15 ;2^N-1

        BRIGHTNESS_COEFF_BIG = TRUE
        VIEW_3D = TRUE

;===========================
section '.code' code executable readable  ; code section
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
           KEY_WOW64_64KEY = 0x0100
        invoke  RegOpenKeyExA, HKEY_LOCAL_MACHINE, Client.QuaryValue, ebx, KEY_READ or KEY_WOW64_64KEY, Client.KeyHandle
        test    eax, eax
        jnz     @F
        ; Client.QuaryKey - 1 = NULL STRING  ;[Client.KeyHandle], Client.QuaryKey - 1, Client.QuaryKey, 0x0000ffff, ebx, Client.PCID, Client.PCIDBufLen
        invoke  RegQueryValueExA, [Client.KeyHandle], Client.QuaryKey, ebx, ebx, Client.PCID, Client.PCIDBufLen
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
        invoke  InitializeCriticalSection, Client.CritSection
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

proc WindowProc ,\;uses ebx esi edi,\
                hwnd, wmsg, wparam, lparam
        mov     ebx, [wmsg]
        cmp     ebx, WM_MOUSEMOVE
        je      .wmmousemove
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
        pop     ebp
        jmp     [DefWindowProc]
  .wmmousemove:
        cmp     [Game.Pause], 1
        je      .IgnoreFigMove
        cmp     [Game.Playing], 1
        jne     .IgnoreFigMove
        movzx   eax, word [lparam]
        push    eax
        fild    dword [esp]
        fdiv    [rect_size]
        fistp   dword [esp]

        pop     eax
        sub     eax, 2
        cmp     ax, 0
        jl      .IgnoreFigMove
        cmp     ax, FIELD_W - 3
        jg      .IgnoreFigMove

        ; TEST TEST !!!!!!!!!!!!!!!!!!!!!!!
        movzx   ebx, [Game.CurFigNumber]
        shl     bx, 2
        mov     ecx, ebx
        mov     esi, eax ; collider X
        movzx   edi, word [Game.FigY] ; initial Y
        mov     dx, word [Game.CurFigRotation]
        ; get figure place at fig array
        push    .IgnoreFigMove
        push    eax
        xor     eax, eax
        jmp     Game.KeyEvent.NonKeyPositionChange ; pops eax
   .IgnoreFigMove:
        jmp     .finish
  .wmcreate:
        invoke  GetDC,[hwnd]
        mov     [Wnd.hdc], eax
        mov     ebx, eax  ; hdc

        ; initialize OpenGL
        mov     esi, Wnd.pfd
        mov     [esi + (Wnd.pfd.nSize - Wnd.pfd)], sizeof.PIXELFORMATDESCRIPTOR
        mov     [esi + (Wnd.pfd.nVersion - Wnd.pfd)], 1
        mov     [esi + (Wnd.pfd.dwFlags - Wnd.pfd)], PFD_SUPPORT_OPENGL + PFD_DOUBLEBUFFER + PFD_DRAW_TO_WINDOW
        mov     [esi + (Wnd.pfd.iLayerType - Wnd.pfd)], PFD_MAIN_PLANE
        mov     [esi + (Wnd.pfd.iPixelType - Wnd.pfd)], PFD_TYPE_RGBA
        mov     [esi + (Wnd.pfd.cColorBits - Wnd.pfd)], 16
        mov     [esi + (Wnd.pfd.cDepthBits - Wnd.pfd)], 16
        invoke  ChoosePixelFormat, ebx, esi
        invoke  SetPixelFormat, ebx, eax, esi

        ; create gl context
        invoke  wglCreateContext, ebx
        mov     [Wnd.hrc], eax
        invoke  wglMakeCurrent, ebx, eax;[hrc]

        ; set fone color
        xor     eax, eax
        invoke  glClearColor, eax, eax, eax, 1.0;0.07, 0.13, 0.17, 1.0

        ;invoke  glEnable, GL_MULTISAMPLE
        ;invoke  glHint, GL_MULTISAMPLE_FILTER_HINT_NV, GL_NICEST

        invoke  glEnable, GL_DEPTH_TEST
        invoke  glEnable, GL_LIGHTING
        invoke  glEnable, GL_LIGHT0
        ;invoke  glEnable, GL_LIGHT1

        push    0.0 0.5 -0.2 0.2
        push    ebp
        mov     ebp, esp
        add     ebp, 4
        invoke  glLightfv, GL_LIGHT0, GL_POSITION, ebp
        pop     ebp
        add     esp, 4 * 4
    if BRIGHTNESS_COEFF_BIG
        mov     eax, 2.0; BRIGHTNESS_COEFF
    else
        mov     eax, 1.0
    end if
        push    1.0 eax eax eax
        push    ebp
        mov     ebp, esp
        add     ebp, 4
        invoke  glLightfv, GL_LIGHT0, GL_DIFFUSE, ebp
        pop     ebp
        add     esp, 4 * 4

        invoke  glColorMaterial, GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE
        invoke  glEnable, GL_COLOR_MATERIAL

        ; set Gl List
        xor     esi, esi
        stdcall View.CreatePrimitive.TexturedCube ; Point;


        ; set clock
        invoke  GetTickCount
        mov     [clock], eax
        mov     [Game.CurTick], eax
        xor     eax, eax
        jmp     .finish
  .wmsize:
        xor     ebx, ebx
        mov     esi, Wnd.rc
        invoke  GetClientRect, [hwnd], esi
        add     esi, Wnd.font - Wnd.rc
        invoke  glViewport, ebx, ebx, [esi + (Wnd.rc.right - Wnd.font)], [esi + (Wnd.rc.bottom - Wnd.font)]

         ; get screen ratio
        fild    dword [esi + (Wnd.rc.right - Wnd.font)]; wdt
        fidiv   dword [esi + (Wnd.rc.bottom - Wnd.font)] ; hei
        fchs
        fstp    [ratio] ; screen ratio
        ; reserve stack for cell width
        push    eax
        ; get rect size
        fild    dword [esi + (Wnd.rc.bottom - Wnd.font)]
        fdiv    [DFIELD_H]
        fst     dword [esp]; save cell width

        fmul    [RECT_MODIFIER]; modify (rect should be < than cell on screen)
        frndint  ; round
        fst     [rect_size]
        fchs
        fistp   [esi + (Wnd.fontSz - Wnd.font)]

        ; get width ratio
        fild    [esi + (Wnd.rc.right - Wnd.font)]
        ; use saved cell width
        fdiv    dword [esp]
        ; move stack back
        pop     eax
        ; get result
        fstp    [DFIELD_W]

        ; create font DUPLICATED TEST!!!
        ;mov     esi, Wnd.font; ptr to font struct; already in the esi
        stdcall View.CreateFont

        ;===============================================================
        ; 3D TEST TEST TEST
    if VIEW_3D
        invoke  glMatrixMode, GL_PROJECTION
        invoke  glLoadIdentity

        invoke  gluPerspective, double -30.0, double [ratio], double 0.1, double 100.0  ; 2nd is w / h

        invoke  glMatrixMode, GL_MODELVIEW
        ; 3D TEST TEST TEST
    else
        ;===============================================================
        ; set projection (THIS IS 2D version)
        invoke  glMatrixMode, GL_PROJECTION
        invoke  glLoadIdentity

        xor     ebx, ebx ; double 0.0 == double push 0
        invoke  glOrtho, ebx, ebx, double [DFIELD_W], double [DFIELD_H], ebx, ebx, double -1.0, double 1000.0

        invoke  glMatrixMode, GL_MODELVIEW
    end if
        ;===============================================================

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
        xor     ax, ax
        cmp     [Game.Playing], ax
        je      .animation
        cmp     [Game.Pause], ax
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
        cmp     [Game.MusicOff], ax
        jne     @F
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

        ; here draw procedure
        include 'drawproc.asm'

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
        ; check if chat activated
        cmp     [View.MenuChosen], 2
        je      .regularKeyEvent_except_R_P
        ; check if keyboard mode activated
        test    bx, bx ; ebx, 0x00'00'80'00
        jns     .regularKeyEvent
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
.regularKeyEvent_except_R_P:
        if (SERVER_DEFINED)
        ; MENU CHANGE VIEW
        cmp     eax, VK_F2
        jne     @F
        ;mov     ax, [View.MenuChosen]
        inc     word [View.MenuChosen]
        and     word [View.MenuChosen], 11b; Menus amount
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
        ; JUST STUPID TEST
        cmp     eax, VK_F5
        jne     @F
        ; mk snd
        push    eax
        invoke  midiOutShortMsg, [midihandle], 0x006F2B99
        ; ini client if not ini
        xor     esi, esi
        stdcall View.CreatePrimitive.TexturedCube
        pop     eax
@@:
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
        ; close texture find lookup
        stdcall Settings.View.GetNextTexture.Close
        ; zero
        xor     ebx, ebx
        ; font lists
        invoke  glDeleteLists, ebx, NUM_OF_CHARACTERS
        ; gl texture
        invoke  glDeleteTextures, 1, View.TextureID
        ; primitive list
        invoke  glDeleteLists, VIEW_LIST_PRIMITIVE, 1
        ; gl & window
        invoke  wglMakeCurrent, [Wnd.hdc], ebx
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
        glu,'GLU32.DLL',\
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
         glScalef, 'glScalef',\
         glVertex3f, 'glVertex3f',\
         glNormal3f, 'glNormal3f',\
         glVertex3i, 'glVertex3i',\
         glNormal3i, 'glNormal3i',\
         glNewList, 'glNewList',\
         glEndList, 'glEndList',\
         glCallList, 'glCallList',\
         glEnable, 'glEnable',\
         glLightfv, 'glLightfv',\
         glLightiv, 'glLightiv',\
         glColorMaterial, 'glColorMaterial',\
         glRasterPos3i, 'glRasterPos3i',\
         glHint, 'glHint',\
         glBlendFunc, 'glBlendFunc',\
         glGenTextures, 'glGenTextures',\
         glBindTexture, 'glBindTexture',\
         glTexImage2D, 'glTexImage2D',\
         glTexParameteri, 'glTexParameteri',\
         glTexCoord2i, 'glTexCoord2i',\
         glDisable, 'glDisable',\
         glDeleteTextures, 'glDeleteTextures'

import glu,\
         gluPerspective, 'gluPerspective',\
         gluLookAt, 'gluLookAt'

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