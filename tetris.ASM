;include '%fasminc%/win32a.inc' ;;ax
;include '%fasminc%/win32a.inc'

format PE GUI 5.0

include '%fasminc%/macro/proc32.inc'
include 'win32ax.inc'

entry start

;===========================
; consts
        FIELD_W = 12; 12
        FIELD_H = 23

        TRUE    = 1
        FALSE   = 0

        START_TICK_SPEED = 500;500
        ;KEY_EVENT_UPDATE = 40
        GLOW_TIME_TICKS  = 15

        NUM_OF_CHARACTERS = 128

        ;MY_FALSE          = 0
        ;MY_TRUE           = 1

        INC_EVERY_FIGS=15;15;2^N-1

        _style equ WS_VISIBLE+WS_OVERLAPPEDWINDOW
;===========================
;section '.data' data readable writable
section '.code' code executable readable writable  ; code section
        Caption         db 'ERROR',0
        Text            db 'Window creation fail', 0;,0

        _font_name      db "Verdana", 0  ;


        _class          TCHAR    'FASMW32',0
        _title          TCHAR    'TETRIS WIN v.1.2.0 by Artiom Drankevich',0

        wc              WNDCLASS 0, WindowProc, 0, 0, NULL, NULL, NULL, NULL, NULL, _class

        msg             MSG
        paintstruct     PAINTSTRUCT
        pfd             PIXELFORMATDESCRIPTOR

        hwnd            dd      ?
        hrc             dd      ?
        hdc             dd      ?

        rc              RECT

        ;========
        DFIELD_H        dq      24.0 ; FIELD_H + 1
        DFIELD_W        dq      ?
        RECT_MODIFIER   dq      0.90;0.9
        clock           dd      ?
        rect_size       dd      10.0

        blocksArr:      times (FIELD_H-1) db $01, (FIELD_W-2) dup $00, $01    ;1A
                db    FIELD_W dup $01
        ;blocksArrCopy:  times (FIELD_H-1) db $01, (FIELD_W-2) dup $00, $01    ;1A
        ;        db    FIELD_W dup $01

        ; =======TEXT==============================
        font_size                 dd    ?

        SCOLE_LEN_CONST           = 6
        Str.NextFig               db    'NEXT FIGURE'
        Str.NextFig.Len           dd    $ - Str.NextFig
        Str.HoldedFig             db    'HOLDED FIGURE'
        Str.HoldedFig.Len         dd    $ - Str.HoldedFig
        Str.HighScore             db    SCOLE_LEN_CONST dup ' '
        Str.Score                 db    SCOLE_LEN_CONST dup ' '
        Str.Score.Format          db    '%5d', 0
        Str.Pause                 db    'PAUSED'
        Str.Loose                 db    'GAME OVER'
        ;========ANIMATIONS========================
        tmp_tmp                   dd    0.0
        tmp_tmp_delta             dd    20.0
        Glow.SZ_delta             dd    0.05
        Glow.right                dd    ?
        Glow.left                 dd    ?
        glowArr:                  db     FIELD_H dup $00
        ;========KEYBOARD==========================
        ;Keyboard.Pressed          db    ?
        ;Keyboard.Clock            dw    0
        
;===========================
section '.code' code executable readable writable  ; code section
start:
        xor      ebx, ebx
        ; window creation process
        invoke  GetModuleHandle, ebx
        mov     [wc.hInstance],  eax

        invoke  LoadCursor, ebx, IDC_ARROW
        mov     [wc.hCursor], eax

        invoke  LoadIcon, ebx, IDI_APPLICATION
        mov     [wc.hIcon], eax

        invoke  RegisterClass, wc
        test    eax, eax ; check if success
        jz      creation_error; err_reg_class

        ; push wnd data
        push    ebx [wc.hInstance] ebx ebx
        ; push wnd szs
        ; get screen ratio
        invoke  GetSystemMetrics, SM_CYSCREEN   ; hei
        push    eax
        invoke  GetSystemMetrics, ebx  ; width
        push    eax

        invoke  CreateWindowEx, ebx, _class, _title,WS_POPUP+WS_VISIBLE+WS_SYSMENU,\          ;+WS_VISIBLE+WS_OVERLAPPEDWINDOW+WS_CLIPCHILDREN+WS_CLIPSIBLINGS
                                     ebx, ebx
        test    eax, eax ; check if success
        jz      creation_error; err_reg_class
        mov     [hwnd], eax

        ; call music ini
        stdcall SoundPlayer.Ini
        ; call game initialization
        call    Random.Initialize
        stdcall Game.GenNewFig; its for ini new fig -> cur fig
        stdcall Game.Initialize

        ; loop
  msg_loop:
        invoke  GetMessage, msg, NULL, 0, 0
        or      eax, eax
        jz      end_loop
        ;invoke  TranslateMessage, msg
        invoke  DispatchMessage, msg
        jmp     msg_loop

creation_error:
        invoke  MessageBox, ebx, Text, Caption, MB_OK or MB_ICONERROR;
  end_loop:
        invoke  ExitProcess,[msg.wParam]

proc WindowProc uses ebx esi edi,\
                hwnd,wmsg,wparam,lparam
        mov     ebx, [wmsg]
        cmp     ebx, WM_CREATE
        je      .wmcreate
        cmp     ebx, WM_SIZE
        je      .wmsize
        cmp     ebx, WM_PAINT
        je      .wmpaint
        cmp     ebx, WM_KEYDOWN
        je      .wmkeydown
        ;cmp     ebx, WM_KEYUP
        ;je      .wmkeyup
        cmp     ebx, WM_DESTROY
        je      .wmdestroy
  .defwndproc:
        invoke  DefWindowProc,[hwnd],ebx,[wparam],[lparam]
        jmp     .finish
  .wmcreate:
        invoke  GetDC,[hwnd]
        mov     [hdc], eax
        mov     ebx, eax  ; hdc

        ; initialize OpenGL
        ;mov     edi,pfd
        ;mov     ecx,sizeof.PIXELFORMATDESCRIPTOR shr 2
        ;xor     eax,eax
        ;rep     stosd
        mov     [pfd.nSize], sizeof.PIXELFORMATDESCRIPTOR
        mov     [pfd.nVersion], 1
        mov     [pfd.dwFlags], PFD_SUPPORT_OPENGL+PFD_DOUBLEBUFFER+PFD_DRAW_TO_WINDOW
        mov     [pfd.iLayerType], PFD_MAIN_PLANE
        mov     [pfd.iPixelType], PFD_TYPE_RGBA
        mov     [pfd.cColorBits], 16
        mov     [pfd.cDepthBits], 16
        mov     [pfd.cAccumBits], 0
        mov     [pfd.cStencilBits], 0
        invoke  ChoosePixelFormat,ebx, pfd
        invoke  SetPixelFormat,ebx,eax, pfd

        ; create gl context
        invoke  wglCreateContext, ebx
        mov     [hrc], eax
        invoke  wglMakeCurrent, ebx, eax;[hrc]

        ; set fone color
        invoke  glClearColor, 0.0,0.0,0.0,1.0;0.07, 0.13, 0.17, 1.0



        ; set clock
        invoke  GetTickCount
        mov     [clock], eax
        mov     [Game.CurTick], ax
        xor     eax, eax
        jmp     .finish
  .wmsize:
        xor     ebx, ebx
        invoke  GetClientRect, [hwnd], rc
        invoke  glViewport, ebx, ebx, [rc.right], [rc.bottom]

        sub     esp, 4; reserve stack for cell width
        ; get rect size
        fild    dword [rc.bottom]
        fdiv    [DFIELD_H]
        fst     dword [esp]; save cell width

        fmul    [RECT_MODIFIER]; modify (rect should be < than cell on screen)
        frndint  ; round
        fst     [rect_size]
        fchs
        fistp   [font_size]

        ; get width ratio
        fild    [rc.right]
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
                          ebx, ebx, ebx, ebx, ebx, ebx, ebx, ebx, _font_name
        invoke  SelectObject, [hdc], eax

        invoke  wglUseFontBitmapsA, [hdc], ebx, NUM_OF_CHARACTERS, ebx ; if errors ret 0
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
        mov     eax, dword [esp]
        stdcall SoundPlayer.Update ; got eax in [esp] as param

        ; define game tick update
        mov     eax, dword [esp]
        sub     ax, [Game.CurTick]
        cmp     ax, [Game.TickSpeed];300; temp
        jb      @F
        add     [Game.CurTick], ax
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

        invoke  glPointSize, [rect_size] ; pixels!!!!

        ; draw
        invoke  glBegin, GL_POINTS
        ; draw field
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
        fld     [tmp_tmp]
        fld     [tmp_tmp_delta]
        faddp
        fstp    [tmp_tmp]
        ; set Special color
        mov     eax, 0.9
        invoke  glColor3f, eax, eax, eax
        ; draw special effect
        mov     ecx, FIELD_H-1
     .glow_draw:
        movzx  ebx, byte [ecx + glowArr]
        ;mov     ebx, 5; tmp
        cmp    ebx, 0
        je     @F
        push   ebx ; copy for fld mul (sp-=4)
        ; dec effect
        dec    byte [ecx + glowArr]
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
        invoke  glRotatef, [tmp_tmp], 0.0, 0.0, 5.0;
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
      @@:
        dec     ecx
        test    ecx, ecx
        jnz  .glow_draw

        ; end test glow draw
        ; draw text NEXT FIG
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2;
        invoke  glCallLists, dword[Str.NextFig.Len], GL_UNSIGNED_BYTE, Str.NextFig
        ; draw text HOLDED FIG
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2 + 6;
        invoke  glCallLists, dword[Str.HoldedFig.Len], GL_UNSIGNED_BYTE, Str.HoldedFig
        ; DRAW text SCORE
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2 + 4 + 6 + 2;
        invoke  glCallLists, SCOLE_LEN_CONST, GL_UNSIGNED_BYTE, Str.Score
        ; DRAW text SCORE HIGH
        invoke  glRasterPos2i, FIELD_W + 3 - 1, 2 + 4 + 6 + 3;
        invoke  glCallLists, SCOLE_LEN_CONST, GL_UNSIGNED_BYTE, Str.HighScore

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
.end_draw:
        invoke  SwapBuffers,[hdc]

        xor     eax,eax
        jmp     .finish
  .wmkeydown:
        ; save key pressed
        mov     eax, [wparam]

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
  ;.wmkeyup:
        ;mov     eax, [wparam]
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
        ;jmp     .defwndproc
  .wmdestroy:
        ; misuc
        stdcall SoundPlayer.Close
        ; file
        invoke  CloseHandle, [Settings.fileHandle]
        invoke  glDeleteLists, 0, NUM_OF_CHARACTERS
        ; gl & window
        invoke  wglMakeCurrent, 0, 0
        invoke  wglDeleteContext,[hrc]
        invoke  ReleaseDC,[hwnd],[hdc]
        invoke  PostQuitMessage, 0
        xor     eax, eax
  .finish:
        ret
endp



        include 'game.asm'
        include 'view.asm'
        include 'settings.asm'
        include 'music.asm'
        include 'units\random.h'



;===========================

section '.idata' import data readable writeable

        library gdi32,'GDI32.DLL',\
        kernel32,'KERNEL32.DLL',\
        user32,'USER32.DLL',\
        winmm,'WINMM.DLL',\
        opengl,'OPENGL32.DLL',\
        glu, 'GLU32.DLL'

        include 'api\gdi32.inc'
        include 'api\kernel32.inc'
        include 'api\user32.inc'
                
        include 'opengl.inc'
        include 'glut.inc'

import winmm,\
        mciSendString,'mciSendStringA',\
        PlaySound , 'PlaySound',\
        midiOutOpen,'midiOutOpen',\
        midiOutShortMsg, 'midiOutShortMsg',\
        midiOutClose, 'midiOutClose',\
        midiOutLongMsg, 'midiOutLongMsg'

import opengl,\
         glAccum,'glAccum',\
         glAlphaFunc,'glAlphaFunc',\
         glAreTexturesResident,'glAreTexturesResident',\
         glArrayElement,'glArrayElement',\
         glBegin,'glBegin',\
         glBindTexture,'glBindTexture',\
         glBitmap,'glBitmap',\
         glBlendFunc,'glBlendFunc',\
         glCallList,'glCallList',\
         glCallLists,'glCallLists',\
         glClear,'glClear',\
         glClearAccum,'glClearAccum',\
         glClearColor,'glClearColor',\
         glClearDepth,'glClearDepth',\
         glClearIndex,'glClearIndex',\
         glClearStencil,'glClearStencil',\
         glClipPlane,'glClipPlane',\
         glColor3b,'glColor3b',\
         glColor3bv,'glColor3bv',\
         glColor3d,'glColor3d',\
         glColor3dv,'glColor3dv',\
         glColor3f,'glColor3f',\
         glColor3fv,'glColor3fv',\
         glColor3i,'glColor3i',\
         glColor3iv,'glColor3iv',\
         glColor3s,'glColor3s',\
         glColor3sv,'glColor3sv',\
         glColor3ub,'glColor3ub',\
         glColor3ubv,'glColor3ubv',\
         glColor3ui,'glColor3ui',\
         glColor3uiv,'glColor3uiv',\
         glColor3us,'glColor3us',\
         glColor3usv,'glColor3usv',\
         glColor4b,'glColor4b',\
         glColor4bv,'glColor4bv',\
         glColor4d,'glColor4d',\
         glColor4dv,'glColor4dv',\
         glColor4f,'glColor4f',\
         glColor4fv,'glColor4fv',\
         glColor4i,'glColor4i',\
         glColor4iv,'glColor4iv',\
         glColor4s,'glColor4s',\
         glColor4sv,'glColor4sv',\
         glColor4ub,'glColor4ub',\
         glColor4ubv,'glColor4ubv',\
         glColor4ui,'glColor4ui',\
         glColor4uiv,'glColor4uiv',\
         glColor4us,'glColor4us',\
         glColor4usv,'glColor4usv',\
         glColorMask,'glColorMask',\
         glColorMaterial,'glColorMaterial',\
         glColorPointer,'glColorPointer',\
         glCopyPixels,'glCopyPixels',\
         glCopyTexImage1D,'glCopyTexImage1D',\
         glCopyTexImage2D,'glCopyTexImage2D',\
         glCopyTexSubImage1D,'glCopyTexSubImage1D',\
         glCopyTexSubImage2D,'glCopyTexSubImage2D',\
         glCullFace,'glCullFace',\
         glDeleteLists,'glDeleteLists',\
         glDeleteTextures,'glDeleteTextures',\
         glDepthFunc,'glDepthFunc',\
         glDepthMask,'glDepthMask',\
         glDepthRange,'glDepthRange',\
         glDisable,'glDisable',\
         glDisableClientState,'glDisableClientState',\
         glDrawArrays,'glDrawArrays',\
         glDrawBuffer,'glDrawBuffer',\
         glDrawElements,'glDrawElements',\
         glDrawPixels,'glDrawPixels',\
         glEdgeFlag,'glEdgeFlag',\
         glEdgeFlagPointer,'glEdgeFlagPointer',\
         glEdgeFlagv,'glEdgeFlagv',\
         glEnable,'glEnable',\
         glEnableClientState,'glEnableClientState',\
         glEnd,'glEnd',\
         glEndList,'glEndList',\
         glEvalCoord1d,'glEvalCoord1d',\
         glEvalCoord1dv,'glEvalCoord1dv',\
         glEvalCoord1f,'glEvalCoord1f',\
         glEvalCoord1fv,'glEvalCoord1fv',\
         glEvalCoord2d,'glEvalCoord2d',\
         glEvalCoord2dv,'glEvalCoord2dv',\
         glEvalCoord2f,'glEvalCoord2f',\
         glEvalCoord2fv,'glEvalCoord2fv',\
         glEvalMesh1,'glEvalMesh1',\
         glEvalMesh2,'glEvalMesh2',\
         glEvalPoint1,'glEvalPoint1',\
         glEvalPoint2,'glEvalPoint2',\
         glFeedbackBuffer,'glFeedbackBuffer',\
         glFinish,'glFinish',\
         glFlush,'glFlush',\
         glFogf,'glFogf',\
         glFogfv,'glFogfv',\
         glFogi,'glFogi',\
         glFogiv,'glFogiv',\
         glFrontFace,'glFrontFace',\
         glFrustum,'glFrustum',\
         glGenLists,'glGenLists',\
         glGenTextures,'glGenTextures',\
         glGetBooleanv,'glGetBooleanv',\
         glGetClipPlane,'glGetClipPlane',\
         glGetDoublev,'glGetDoublev',\
         glGetError,'glGetError',\
         glGetFloatv,'glGetFloatv',\
         glGetIntegerv,'glGetIntegerv',\
         glGetLightfv,'glGetLightfv',\
         glGetLightiv,'glGetLightiv',\
         glGetMapdv,'glGetMapdv',\
         glGetMapfv,'glGetMapfv',\
         glGetMapiv,'glGetMapiv',\
         glGetMaterialfv,'glGetMaterialfv',\
         glGetMaterialiv,'glGetMaterialiv',\
         glGetPixelMapfv,'glGetPixelMapfv',\
         glGetPixelMapuiv,'glGetPixelMapuiv',\
         glGetPixelMapusv,'glGetPixelMapusv',\
         glGetPointerv,'glGetPointerv',\
         glGetPolygonStipple,'glGetPolygonStipple',\
         glGetString,'glGetString',\
         glGetTexEnvfv,'glGetTexEnvfv',\
         glGetTexEnviv,'glGetTexEnviv',\
         glGetTexGendv,'glGetTexGendv',\
         glGetTexGenfv,'glGetTexGenfv',\
         glGetTexGeniv,'glGetTexGeniv',\
         glGetTexImage,'glGetTexImage',\
         glGetTexLevelParameterfv,'glGetTexLevelParameterfv',\
         glGetTexLevelParameteriv,'glGetTexLevelParameteriv',\
         glGetTexParameterfv,'glGetTexParameterfv',\
         glGetTexParameteriv,'glGetTexParameteriv',\
         glHint,'glHint',\
         glIndexMask,'glIndexMask',\
         glIndexPointer,'glIndexPointer',\
         glIndexd,'glIndexd',\
         glIndexdv,'glIndexdv',\
         glIndexf,'glIndexf',\
         glIndexfv,'glIndexfv',\
         glIndexi,'glIndexi',\
         glIndexiv,'glIndexiv',\
         glIndexs,'glIndexs',\
         glIndexsv,'glIndexsv',\
         glIndexub,'glIndexub',\
         glIndexubv,'glIndexubv',\
         glInitNames,'glInitNames',\
         glInterleavedArrays,'glInterleavedArrays',\
         glIsEnabled,'glIsEnabled',\
         glIsList,'glIsList',\
         glIsTexture,'glIsTexture',\
         glLightModelf,'glLightModelf',\
         glLightModelfv,'glLightModelfv',\
         glLightModeli,'glLightModeli',\
         glLightModeliv,'glLightModeliv',\
         glLightf,'glLightf',\
         glLightfv,'glLightfv',\
         glLighti,'glLighti',\
         glLightiv,'glLightiv',\
         glLineStipple,'glLineStipple',\
         glLineWidth,'glLineWidth',\
         glListBase,'glListBase',\
         glLoadIdentity,'glLoadIdentity',\
         glLoadMatrixd,'glLoadMatrixd',\
         glLoadMatrixf,'glLoadMatrixf',\
         glLoadName,'glLoadName',\
         glLogicOp,'glLogicOp',\
         glMap1d,'glMap1d',\
         glMap1f,'glMap1f',\
         glMap2d,'glMap2d',\
         glMap2f,'glMap2f',\
         glMapGrid1d,'glMapGrid1d',\
         glMapGrid1f,'glMapGrid1f',\
         glMapGrid2d,'glMapGrid2d',\
         glMapGrid2f,'glMapGrid2f',\
         glMaterialf,'glMaterialf',\
         glMaterialfv,'glMaterialfv',\
         glMateriali,'glMateriali',\
         glMaterialiv,'glMaterialiv',\
         glMatrixMode,'glMatrixMode',\
         glMultMatrixd,'glMultMatrixd',\
         glMultMatrixf,'glMultMatrixf',\
         glNewList,'glNewList',\
         glNormal3b,'glNormal3b',\
         glNormal3bv,'glNormal3bv',\
         glNormal3d,'glNormal3d',\
         glNormal3dv,'glNormal3dv',\
         glNormal3f,'glNormal3f',\
         glNormal3fv,'glNormal3fv',\
         glNormal3i,'glNormal3i',\
         glNormal3iv,'glNormal3iv',\
         glNormal3s,'glNormal3s',\
         glNormal3sv,'glNormal3sv',\
         glNormalPointer,'glNormalPointer',\
         glOrtho,'glOrtho',\
         glPassThrough,'glPassThrough',\
         glPixelMapfv,'glPixelMapfv',\
         glPixelMapuiv,'glPixelMapuiv',\
         glPixelMapusv,'glPixelMapusv',\
         glPixelStoref,'glPixelStoref',\
         glPixelStorei,'glPixelStorei',\
         glPixelTransferf,'glPixelTransferf',\
         glPixelTransferi,'glPixelTransferi',\
         glPixelZoom,'glPixelZoom',\
         glPointSize,'glPointSize',\
         glPolygonMode,'glPolygonMode',\
         glPolygonOffset,'glPolygonOffset',\
         glPolygonStipple,'glPolygonStipple',\
         glPopAttrib,'glPopAttrib',\
         glPopClientAttrib,'glPopClientAttrib',\
         glPopMatrix,'glPopMatrix',\
         glPopName,'glPopName',\
         glPrioritizeTextures,'glPrioritizeTextures',\
         glPushAttrib,'glPushAttrib',\
         glPushClientAttrib,'glPushClientAttrib',\
         glPushMatrix,'glPushMatrix',\
         glPushName,'glPushName',\
         glRasterPos2d,'glRasterPos2d',\
         glRasterPos2dv,'glRasterPos2dv',\
         glRasterPos2f,'glRasterPos2f',\
         glRasterPos2fv,'glRasterPos2fv',\
         glRasterPos2i,'glRasterPos2i',\
         glRasterPos2iv,'glRasterPos2iv',\
         glRasterPos2s,'glRasterPos2s',\
         glRasterPos2sv,'glRasterPos2sv',\
         glRasterPos3d,'glRasterPos3d',\
         glRasterPos3dv,'glRasterPos3dv',\
         glRasterPos3f,'glRasterPos3f',\
         glRasterPos3fv,'glRasterPos3fv',\
         glRasterPos3i,'glRasterPos3i',\
         glRasterPos3iv,'glRasterPos3iv',\
         glRasterPos3s,'glRasterPos3s',\
         glRasterPos3sv,'glRasterPos3sv',\
         glRasterPos4d,'glRasterPos4d',\
         glRasterPos4dv,'glRasterPos4dv',\
         glRasterPos4f,'glRasterPos4f',\
         glRasterPos4fv,'glRasterPos4fv',\
         glRasterPos4i,'glRasterPos4i',\
         glRasterPos4iv,'glRasterPos4iv',\
         glRasterPos4s,'glRasterPos4s',\
         glRasterPos4sv,'glRasterPos4sv',\
         glReadBuffer,'glReadBuffer',\
         glReadPixels,'glReadPixels',\
         glRectd,'glRectd',\
         glRectdv,'glRectdv',\
         glRectf,'glRectf',\
         glRectfv,'glRectfv',\
         glRecti,'glRecti',\
         glRectiv,'glRectiv',\
         glRects,'glRects',\
         glRectsv,'glRectsv',\
         glRenderMode,'glRenderMode',\
         glRotated,'glRotated',\
         glRotatef,'glRotatef',\
         glScaled,'glScaled',\
         glScalef,'glScalef',\
         glScissor,'glScissor',\
         glSelectBuffer,'glSelectBuffer',\
         glShadeModel,'glShadeModel',\
         glStencilFunc,'glStencilFunc',\
         glStencilMask,'glStencilMask',\
         glStencilOp,'glStencilOp',\
         glTexCoord1d,'glTexCoord1d',\
         glTexCoord1dv,'glTexCoord1dv',\
         glTexCoord1f,'glTexCoord1f',\
         glTexCoord1fv,'glTexCoord1fv',\
         glTexCoord1i,'glTexCoord1i',\
         glTexCoord1iv,'glTexCoord1iv',\
         glTexCoord1s,'glTexCoord1s',\
         glTexCoord1sv,'glTexCoord1sv',\
         glTexCoord2d,'glTexCoord2d',\
         glTexCoord2dv,'glTexCoord2dv',\
         glTexCoord2f,'glTexCoord2f',\
         glTexCoord2fv,'glTexCoord2fv',\
         glTexCoord2i,'glTexCoord2i',\
         glTexCoord2iv,'glTexCoord2iv',\
         glTexCoord2s,'glTexCoord2s',\
         glTexCoord2sv,'glTexCoord2sv',\
         glTexCoord3d,'glTexCoord3d',\
         glTexCoord3dv,'glTexCoord3dv',\
         glTexCoord3f,'glTexCoord3f',\
         glTexCoord3fv,'glTexCoord3fv',\
         glTexCoord3i,'glTexCoord3i',\
         glTexCoord3iv,'glTexCoord3iv',\
         glTexCoord3s,'glTexCoord3s',\
         glTexCoord3sv,'glTexCoord3sv',\
         glTexCoord4d,'glTexCoord4d',\
         glTexCoord4dv,'glTexCoord4dv',\
         glTexCoord4f,'glTexCoord4f',\
         glTexCoord4fv,'glTexCoord4fv',\
         glTexCoord4i,'glTexCoord4i',\
         glTexCoord4iv,'glTexCoord4iv',\
         glTexCoord4s,'glTexCoord4s',\
         glTexCoord4sv,'glTexCoord4sv',\
         glTexCoordPointer,'glTexCoordPointer',\
         glTexEnvf,'glTexEnvf',\
         glTexEnvfv,'glTexEnvfv',\
         glTexEnvi,'glTexEnvi',\
         glTexEnviv,'glTexEnviv',\
         glTexGend,'glTexGend',\
         glTexGendv,'glTexGendv',\
         glTexGenf,'glTexGenf',\
         glTexGenfv,'glTexGenfv',\
         glTexGeni,'glTexGeni',\
         glTexGeniv,'glTexGeniv',\
         glTexImage1D,'glTexImage1D',\
         glTexImage2D,'glTexImage2D',\
         glTexParameterf,'glTexParameterf',\
         glTexParameterfv,'glTexParameterfv',\
         glTexParameteri,'glTexParameteri',\
         glTexParameteriv,'glTexParameteriv',\
         glTexSubImage1D,'glTexSubImage1D',\
         glTexSubImage2D,'glTexSubImage2D',\
         glTranslated,'glTranslated',\
         glTranslatef,'glTranslatef',\
         glVertex2d,'glVertex2d',\
         glVertex2dv,'glVertex2dv',\
         glVertex2f,'glVertex2f',\
         glVertex2fv,'glVertex2fv',\
         glVertex2i,'glVertex2i',\
         glVertex2iv,'glVertex2iv',\
         glVertex2s,'glVertex2s',\
         glVertex2sv,'glVertex2sv',\
         glVertex3d,'glVertex3d',\
         glVertex3dv,'glVertex3dv',\
         glVertex3f,'glVertex3f',\
         glVertex3fv,'glVertex3fv',\
         glVertex3i,'glVertex3i',\
         glVertex3iv,'glVertex3iv',\
         glVertex3s,'glVertex3s',\
         glVertex3sv,'glVertex3sv',\
         glVertex4d,'glVertex4d',\
         glVertex4dv,'glVertex4dv',\
         glVertex4f,'glVertex4f',\
         glVertex4fv,'glVertex4fv',\
         glVertex4i,'glVertex4i',\
         glVertex4iv,'glVertex4iv',\
         glVertex4s,'glVertex4s',\
         glVertex4sv,'glVertex4sv',\
         glVertexPointer,'glVertexPointer',\
         glViewport,'glViewport',\
         wglGetProcAddress,'wglGetProcAddress',\
         wglCopyContext,'wglCopyContext',\
         wglCreateContext,'wglCreateContext',\
         wglCreateLayerContext,'wglCreateLayerContext',\
         wglDeleteContext,'wglDeleteContext',\
         wglDescribeLayerPlane,'wglDescribeLayerPlane',\
         wglGetCurrentContext,'wglGetCurrentContext',\
         wglGetCurrentDC,'wglGetCurrentDC',\
         wglGetLayerPaletteEntries,'wglGetLayerPaletteEntries',\
         wglMakeCurrent,'wglMakeCurrent',\
         wglRealizeLayerPalette,'wglRealizeLayerPalette',\
         wglSetLayerPaletteEntries,'wglSetLayerPaletteEntries',\
         wglShareLists,'wglShareLists',\
         wglSwapLayerBuffers,'wglSwapLayerBuffers',\
         wglSwapMultipleBuffers,'wglSwapMultipleBuffers',\
         wglUseFontBitmapsA,'wglUseFontBitmapsA',\
         wglUseFontOutlinesA,'wglUseFontOutlinesA',\
         wglUseFontBitmapsW,'wglUseFontBitmapsW',\
         wglUseFontOutlinesW,'wglUseFontOutlinesW',\
         glDrawRangeElements,'glDrawRangeElements',\
         glTexImage3D,'glTexImage3D',\
         glBlendColor,'glBlendColor',\
         glBlendEquation,'glBlendEquation',\
         glColorSubTable,'glColorSubTable',\
         glCopyColorSubTable,'glCopyColorSubTable',\
         glColorTable,'glColorTable',\
         glCopyColorTable,'glCopyColorTable',\
         glColorTableParameteriv,'glColorTableParameteriv',\
         glColorTableParameterfv,'glColorTableParameterfv',\
         glGetColorTable,'glGetColorTable',\
         glGetColorTableParameteriv,'glGetColorTableParameteriv',\
         glGetColorTableParameterfv,'glGetColorTableParameterfv',\
         glConvolutionFilter1D,'glConvolutionFilter1D',\
         glConvolutionFilter2D,'glConvolutionFilter2D',\
         glCopyConvolutionFilter1D,'glCopyConvolutionFilter1D',\
         glCopyConvolutionFilter2D,'glCopyConvolutionFilter2D',\
         glGetConvolutionFilter,'glGetConvolutionFilter',\
         glSeparableFilter2D,'glSeparableFilter2D',\
         glGetSeparableFilter,'glGetSeparableFilter',\
         glConvolutionParameteri,'glConvolutionParameteri',\
         glConvolutionParameteriv,'glConvolutionParameteriv',\
         glConvolutionParameterf,'glConvolutionParameterf',\
         glConvolutionParameterfv,'glConvolutionParameterfv',\
         glGetConvolutionParameteriv,'glGetConvolutionParameteriv',\
         glGetConvolutionParameterfv,'glGetConvolutionParameterfv',\
         glHistogram,'glHistogram',\
         glResetHistogram,'glResetHistogram',\
         glGetHistogram,'glGetHistogram',\
         glGetHistogramParameteriv,'glGetHistogramParameteriv',\
         glGetHistogramParameterfv,'glGetHistogramParameterfv',\
         glMinmax,'glMinmax',\
         glResetMinmax,'glResetMinmax',\
         glGetMinmax,'glGetMinmax',\
         glGetMinmaxParameteriv,'glGetMinmaxParameteriv',\
         glGetMinmaxParameterfv,'glGetMinmaxParameterfv'

import glu,\
         gluPerspective,'gluPerspective',\
         gluOrtho2D, 'gluOrtho2D'



