;include '%fasminc%/win32a.inc' ;;ax
;include '%fasminc%/win32a.inc'

format PE GUI 4.0

include '%fasminc%/macro/proc32.inc'
include 'win32ax.inc'




entry start

;===========================
; consts
        FIELD_W = 12; 12
        FIELD_H = 23

        BLOCK_W = 7

        TRUE    = 1
        FALSE   = 0

        START_TICK_SPEED = 10

        _style equ WS_VISIBLE+WS_OVERLAPPEDWINDOW
;===========================
section '.data' data readable writable
        Caption          db 'Моя первая программа.',0
        Text             db 'Всем привет!', 13;,0
        Text.Random      db 16 dup ?, 0
        _wav_play        db 'play c:\windows\media\tada.wav',0 ; 'play c:\windows\media\tada.wav wait'

        buf_format       db '%10d', 0
        buffer           db 16 dup ' ', 0


        _class          TCHAR    'FASMW32',0
        _title          TCHAR    'Hello from FASM!',0

        ;wc              WNDCLASS 0, WindowProc, 0, 0, NULL, NULL, NULL, NULL, NULL, _class ;COLOR_BTNFACE + 1
        wc              WNDCLASS 0, WindowProc, 0, 0, NULL, NULL, NULL, NULL, NULL, _class

        msg             MSG

        hdc             dd      ?
        paintstruct     PAINTSTRUCT
        pfd             PIXELFORMATDESCRIPTOR
        ; Windowproc is proc, where window events handled

        hwnd            dd      ?
        hrc             dd      ?
                ;соотношение разрешений экрана по горизонтали и вертикали
        ratio           dq ?

        Rect            RECT    10, 10, 110, 110
        rc              RECT

        length          dd      120

        ;========Game model==============
        ;FIELD_H         dd      23
        DFIELD_H        dq      24.0
        DFIELD_W        dq      ?
        RECT_MODIFIER   dq      0.9
        clock           dd      ?
        rect_size       dd      10.0

        blocksArr:      times (FIELD_H-1) db $01, (FIELD_W-2) dup $00, $01    ;1A
                db    FIELD_W dup $01
        blocksArrCopy:  times (FIELD_H-1) db $01, (FIELD_W-2) dup $00, $01    ;1A
                db    FIELD_W dup $01

        Color_Table     dd      0.1, 0.1, 0.6,\
                                0.3, 0.9, 0.3,\
                                1.0, 1.0, 1.0,\
                                1.0, 1.0, 1.0,\
                                1.0, 1.0, 1.0,\
                                1.0, 1.0, 1.0,\
                                1.0, 1.0, 1.0
        colorsNum       dw      ($ - Color_Table)/12 - 1

        figArr          dw      0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b,\
                        0100'0100_0100'0100b, 0000'1111_0000'0000b, 0100'0100_0100'0100b, 0000'1111_0000'0000b,\
                        0100'0100_0110'0000b, 0010'1110_0000'0000b, 1100'0100_0100'0000b, 0000'1110_1000'0000b,\
                        0100'0100_1100'0000b, 0000'1110_0010'0000b, 0110'0100_0100'0000b, 1000'1110_0000'0000b,\
                        0100'1110_0000'0000b, 0100'0110_0100'0000b, 0000'1110_0100'0000b, 0100'1100_0100'0000b,\
                        1000'1100_0100'0000b, 0000'0110_1100'0000b, 1000'1100_0100'0000b, 0000'0110_1100'0000b,\
                        0100'1100_1000'0000b, 0000'1100_0110'0000b, 0100'1100_1000'0000b, 0000'1100_0110'0000b
                        ;0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b,\
                        ;0000'1110_1010'0000b, 0110'0100_0110'0000b, 1010'1110_0000'0000b, 1100'0100_1100'0000b,\;
        figNum          dw      ($ - figArr)/8 - 1

        ;========Game model==============
        Game.CurFig             dw      ?
        Game.CurFigColor        dw      ?
        Game.CurFigRotation     dw      ?
        Game.CurFigNumber       dw      ?
        Game.NextFig            dw      ?
        Game.NextFigNumber      dw      ?
        Game.FigX               dw      ?
        Game.FigY               dw      ?
        Game.FigPreviewY        dw      ?
        Game.TickSpeed          dw      ?
        Game.CurTick            dw      ?
        Game.Score              dw      ?
        Game.Playing            dw      ?
        Game.Pause              dw      ?
        Game.FigsPlaced         dw      ?
        Game.CurSoundTick       dw      ?
        
;===========================

section '.code' code executable readable  ; code section

start:
        ; test playsound
        invoke  mciSendString, _wav_play, 0, 0, 0

        call    Random.Initialize

        mov     ecx, 16
        mov     ebx, Text.Random
.RandTextLoop:
        stdcall Random.Get, $41, $5A
        mov     [ebx], al
        inc     ebx
        loop    .RandTextLoop

        ; setup game
        ;call    Game.Initialize
        xor      ebx, ebx

        ; params:
        ; - handle of owner
        ; - adress of message text 1st letter
        ; - adress of caption text 1st letter
        ; - window style
        invoke  MessageBox, ebx, Text, Caption, MB_OK; invoke -- special windows macro; waits for user reaction!!;

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

        invoke  CreateWindowEx, ebx, _class, _title, WS_VISIBLE+WS_OVERLAPPEDWINDOW+WS_CLIPCHILDREN+WS_CLIPSIBLINGS,\
                                     CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, ebx, ebx, [wc.hInstance], ebx
        test    eax, eax ; check if success
        jz      creation_error; err_reg_class
        mov     [hwnd], eax

        ; call game initialization
        stdcall Game.GenNewFig; its for ini new fig -> cur fig
        stdcall Game.Initialize

        ; loop
  msg_loop:
        invoke  GetMessage, msg, NULL, 0, 0
        or      eax, eax
        jz      end_loop
        invoke  TranslateMessage, msg
        invoke  DispatchMessage, msg
        jmp     msg_loop

creation_error:
        invoke  MessageBox, ebx, Text, Caption, MB_OK or MB_ICONERROR;
  end_loop:
        invoke  ExitProcess,[msg.wParam]

proc WindowProc uses ebx esi edi,\
                hwnd,wmsg,wparam,lparam
        cmp     [wmsg],WM_CREATE
        je      .wmcreate
        cmp     [wmsg],WM_SIZE
        je      .wmsize
        cmp     [wmsg],WM_PAINT
        je      .wmpaint
        cmp     [wmsg],WM_KEYDOWN
        je      .wmkeydown
        cmp     [wmsg],WM_DESTROY
        je      .wmdestroy
  .defwndproc:
        invoke  DefWindowProc,[hwnd],[wmsg],[wparam],[lparam]
        jmp     .finish
  .wmcreate:
        invoke  GetDC,[hwnd]
        mov     [hdc],eax

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
        invoke  ChoosePixelFormat,[hdc], pfd
        invoke  SetPixelFormat,[hdc],eax, pfd

        ; create gl context
        invoke  wglCreateContext, [hdc]
        mov     [hrc], eax
        invoke  wglMakeCurrent, [hdc], eax;[hrc]

        ; set fone color
        invoke  glClearColor, 0.07, 0.13, 0.17, 1.0


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

        ; get screen ratio
        invoke  GetSystemMetrics, SM_CYSCREEN   ; hei
        push    eax
        invoke  GetSystemMetrics, ebx  ; width
        push    eax

        fild    dword [esp]; wdt
        fidiv   dword [esp+4] ; hei
        fstp    [ratio] ; screen ratio


        add     esp, 4; reserve stack for cell width
        ; get rect size
        fild    dword [rc.bottom]
        fdiv    [DFIELD_H]
        fst     dword [esp]; save cell width

        fmul    [RECT_MODIFIER]; modify (rect should be < than cell on screen)
        frndint  ; round
        fstp    [rect_size]
        ; get width ratio
        fild    [rc.right]
        ; use saved cell width
        fdiv    dword [esp]
        ; move stack back
        sub     esp, 4
        ; get result
        fstp    [DFIELD_W]

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
        ; define game tick update
        sub     ax, [Game.CurTick]
        cmp     ax, 300; temp
        jb      @F
        add     [Game.CurTick], ax
        mov     eax, 7; key with ID 7 is undefined
        stdcall Game.KeyEvent
@@:
        ; define animation
        pop     eax
        sub     eax,[clock]
        cmp     eax, 10
        jb      .finish
        add     [clock], eax; reset timer
        ;invoke  glRotatef,[theta],0.0,0.0,1.0
      ;.animation_ok:
        invoke  glClear,GL_COLOR_BUFFER_BIT
        invoke  glLoadIdentity

        invoke  glPointSize, [rect_size] ; pixels!!!!

        invoke  glBegin, GL_QUADS
        invoke  glColor3f,1.0,0.1,0.1
        invoke  glVertex3f,-0.6,-0.6,0.0
        invoke  glColor3f,0.1,0.1,0.1
        invoke  glVertex3f,0.6,-0.6,0.0
        invoke  glColor3f,0.1,0.1,1.0
        invoke  glVertex3f,0.6,0.6,0.0
        invoke  glColor3f,1.0,0.1,1.0
        invoke  glVertex3f,-0.6,0.6,0.0
        invoke  glEnd

        ; draw field
        stdcall View.DrawField
        ; draw figure figure
        mov     bx,  word [Game.CurFig]; figure
        movzx   esi, word [Game.FigX]  ; X
        push    bx esi ; save
        movzx   edi, word [Game.FigPreviewY]  ; Y
        stdcall View.DrawFigure, 1
        ; draw figure
        pop     esi bx
        movzx   edi, word [Game.FigY]  ; Y
        movzx   eax, byte [Game.CurFigColor]; movzx
        stdcall View.DrawFigure, eax
        ; draw next figure
        mov     bx,  word [Game.NextFig]
        mov     esi, FIELD_W + 3; X
        mov     edi, 2  ; Y
        stdcall View.DrawFigure, 2;//????

        invoke  SwapBuffers,[hdc]
        xor     eax,eax
        jmp     .finish
  .wmkeydown:
        ; save key pressed
        mov     eax, [wparam]

        stdcall Game.KeyEvent

        cmp     eax, VK_ESCAPE
        jne     .defwndproc
  .wmdestroy:
        invoke  wglMakeCurrent, 0, 0
        invoke  wglDeleteContext,[hrc]
        invoke  ReleaseDC,[hwnd],[hdc]
        invoke  PostQuitMessage, 0
        xor     eax, eax
  .finish:
        ret
endp

;#############GAME INITIALIZATION####################
proc Game.Initialize

        call    Random.Initialize

        ; clear screen

        ; clear field
        mov     esi, blocksArrCopy
        mov     edi, blocksArr
        mov     ecx, FIELD_W*FIELD_H
        rep movsb

        ; write score
        ;mov     word [Game.ScoreStrEnd - 3], $0000; clear string for score
        ;mov     word [Game.ScoreStrEnd - 1], $0000

        mov     [Game.Score], 0; set score to 0

        ; write high scoree
        stdcall Game.GenNewFig


        mov     [Game.TickSpeed], START_TICK_SPEED
        mov     [Game.Pause], TRUE;
        mov     [Game.Playing], FALSE

        mov     [Game.CurSoundTick], 0

        mov     [Game.FigPreviewY], 0

        ;fld     [Game.SpeedMul]

        ; update screen
                ; CLEAR
                ; WRITE SCORE
                ; WRITE HIGH
        ; DRAW FIELD
                ; DRAW NEXT FIGURE
        ;stdcall Screen.Update

        ret
endp

;#############GEN NEW FIGURE####################
proc Game.GenNewFig

        ; setup start place
        mov     [Game.FigX], FIELD_W/2-2
        mov     [Game.FigY], 0
        mov     [Game.CurFigRotation], 0

        ; setup new color
        movzx   eax, [colorsNum]
        stdcall Random.Get, 3, eax
        mov     [Game.CurFigColor], ax

        ; setup cur fig
        mov     ax, [Game.NextFigNumber]
        mov     [Game.CurFigNumber], ax
        mov     ax, [Game.NextFig]
        mov     [Game.CurFig], ax

        ; setup next fig
        movzx   eax, [figNum]
        stdcall Random.Get, 0, eax
        mov     [Game.NextFigNumber], ax
        movzx   ebx, ax
        shl     ebx, 3
        mov     ax, [figArr + ebx]
        mov     [Game.NextFig], ax

        ret
endp

;############### KEY EVENT ############
; - processes a key code, stored in eax
proc Game.KeyEvent uses eax

        ; LD figure data and save initial fig state
        xor     ebx, ebx
        movzx   esi, word [Game.FigX] ; initial X
        movzx   edi, word [Game.FigY] ; initial Y
        movzx   ecx, [Game.CurFigNumber]
        shl     cx, 2; bc figs are stored as 2 bytes * 4 states
        mov     bx, cx; save cx
        mov     dx, [Game.CurFigRotation]

        ; game logics here
        ; get figure (duplicated!)
        add     bx, dx ; apply rotation
        shl     bx, 1  ; each fig is 2 bytes long
        mov     bx, [figArr + ebx] ; is cur figure
        ; check timer update
        cmp     eax, 7; reserved for timer update
        jne     @F
        inc     di
@@:
        ; save old di
        mov     word [Game.FigY], di
        ; go down loop
.GoDownLoop:
        ; check on collision
        push    ebx esi edx eax ecx edi
        stdcall Game.CollideFigure; esi - X edi - Y bx - FIG
        pop     edi ; reset Y to new
        inc     edi
        test    ax, ax
        pop     ecx eax edx esi ebx
        jz      .GoDownLoop
        ; collided
        sub     di, 2
        ; speed up on space
        cmp     eax, ' '
        je      .Collided
        cmp     di, [Game.FigY]
        jb      .Collided
        ; save new di as preview Y
        mov     [Game.FigPreviewY], di
        ; restore old Y
        mov     di, word [Game.FigY]
        ; move left-right-rotate
        cmp     eax, 'A';VK_LEFT;'a'
        jne     @F
        dec     si
@@:
        cmp     eax, 'D';VK_RIGHT ;'d'
        jne     @F
        inc     si
@@:
        ; decode key and apply rotation
        cmp     eax, 'W'  ; rotation
        jne     @F
        inc     dx
        and     dx, 0000'0000'0000'0011b
@@:
        cmp     eax, 'S' ; rotation
        jne     @F
        dec     dx
        and     dx, 0000'0000'0000'0011b
@@:
        ; get figure
        add     cx, dx ; apply rotation
        shl     cx, 1  ; each fig is 2 bytes long
        mov     bx, [figArr + ecx] ; is cur figure

        ; check collisions
        push    ebx esi edi edx
        stdcall Game.CollideFigure
        pop     edx edi esi ebx
        test    ax, ax

        jnz     .End_key_event; ignore changes if collided

        ; noncollided
        ; EVERYTHING IS GOOD
        mov     [Game.FigX], si
        mov     [Game.FigY], di
        mov     [Game.CurFig], bx
        mov     [Game.CurFigRotation], dx
        jmp     .End_key_event

.Collided:
        ; 1st place figure
        mov     cl, byte [Game.CurFigColor]
        push    ebx esi edi edx
        stdcall Game.PlaceFigure
        pop     edx edi esi ebx
        ; check on loose
        ;stdcall Game.CheckOnEnd
        ; check on scrore
        ;stdcall Game.CheckOnLine
        ; gen new fig (temp)
        stdcall Game.GenNewFig
        ;mov     [Game.FigY], 0

.End_key_event:
        ret
endp

;#############CHECK ON END OF GAME ####################
; - rets TRUE in ax if game ends
proc Game.CheckOnEnd uses ebx ecx

        xor     eax, eax

        mov     ecx, FIELD_W - 2
        mov     ebx, FIELD_W * 3 + 1; from 3rd line
.CheckLoop:
        cmp     byte [ebx + blocksArr], 0
        je      @F
        mov     eax, TRUE
        jmp     .EndProc
@@:
        inc     bx
        loop    .CheckLoop
.EndProc:
        ret
endp

;#############CHECK ON FULL LINES AND ENCOUNT SCORE ####################
proc Game.CheckOnLine uses dx ebx ecx

        xor     ax, ax; score
        mov     ebx, 1           ; full w
        mov     ecx, FIELD_H - 1 ; full hei - 1
.CheckLoop:
        push    ecx
        push    ebx

        mov     ecx, FIELD_W - 2
.InnerCheckLoop:
        cmp     byte [ebx + blocksArr], 0
        je      .skipLine

        inc     ebx
        loop    .InnerCheckLoop
        ; if non skipped -- rm line

        sub     ebx, FIELD_W
        mov     ecx, ebx
.RmLineLoop:
        mov     dl, byte [ebx + blocksArr]
        cmp     dl, $01; check if it is border block
        je      @F
        mov     [ebx + blocksArr + FIELD_W], dl
@@:
        dec     ebx
        loop    .RmLineLoop
        ; rm line end
        inc     ax; add score

.skipLine:
        pop     ebx
        add     ebx, FIELD_W

        pop     ecx
        loop    .CheckLoop
 ; END LOOP
        test    ax, ax  ; add score
        jz      .EndProc

        mov     cx, 2   ; count
        xchg    ax, cx
        shl     ax, cl
        dec     ax
        shl     ax, 2

        add     [Game.Score], ax ; add

        ;push    0
        ;push    [Game.Score]; SCORE
        ;push    Game.ScoreStrEnd
        ;call    DecimalWrite.ExtMem
        ;stdcall Screen.DrawRect, FIELD_W*(BLOCK_W+1)+30, 90, 20*5, 5, $00
        ;stdcall Screen.WriteStr.Mode13h, FIELD_W*(BLOCK_W+1)+30, 90, Game.ScoreStr, $1F, alCustom
                ; WRITE SCORE

.EndProc:
        ret
endp


;#############MOVES FIGURE TO FIELD ARRAY ####################
; - fig   -- 2 bytes figure
; - x     -- x cord
; - y     -- y cord
; - color -- fig color
;Game.PlaceFigure.Fig            bx
;Game.PlaceFigure.X              esi
;Game.PlaceFigure.Y              edi
;Game.PlaceFigure.Color          cl
;Game.PlaceFigure.Field          ???

proc Game.PlaceFigure ;uses eax ecx esi edi ebx

        ; prep cords
        mov     eax, FIELD_W
        mul     di
        add     esi, eax; esi is cord in matrix


        xchg    al, cl ; mov color to al
        mov     ecx, 16; setup loop

        ; inner loop -- line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        ; paste figure
        mov     byte [esi + blocksArr], al
@@:
        inc     esi ; setup cords
        dec     ecx
        test    ecx, 0000'0000'0000'0000_0000'0000'0000'0011b; if % 4 => move to next line
        jnz     @F
        add     esi, FIELD_W - 4
@@:
        inc     ecx
        loop    .DrawLoop

        ret
endp

;#############CHECK ON COLLISION####################
; - fig   -- 2 bytes figure
; - x     -- x cord
; - y     -- y cord
;View.CollideFigure.Fig             bx
;View.CollideFigure.X               esi
;View.CollideFigure.Y               edi;dw      ?

proc Game.CollideFigure ;uses ebx ecx eax edx esi edi
        ; prep cords
        mov     eax, FIELD_W
        mul     di
        add     esi, eax; esi is cord in matrix

        ; result set
        xor     eax, eax

        mov     ecx, 16

        ; inner loop -- draw line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        ; check collision
        cmp     byte [esi + blocksArr], 0
        jne     .Collided
@@:
        inc     esi; setup cords
        dec     ecx
        test    ecx, 0000'0000'0000'0000_0000'0000'0000'0011b
        jnz     @F
        add     esi, FIELD_W - 4
@@:
        inc     ecx
        loop    .DrawLoop

        jmp     .EndProc
.Collided:
        mov     eax, TRUE
.EndProc:
        ret
endp


;#############DRAW FIGURE####################
; - fig    -- 2 bytes fig data
; - x,y    -- x,y cord
;View.DrawFigure.Fig             bx
;View.DrawFigure.X               esi
;View.DrawFigure.Y               edi;dw      ?
;View.DrawFigure.Color           (stack)
proc View.DrawFigure uses ecx,\
                     color
        ; begin paint
        invoke  glBegin, GL_POINTS
        ; get color
        mov     eax, [color]
        ; set x pos
        ;mov     si, [View.DrawFigure.X]
        inc     esi
        ; set y pos
        ;mov     di, [View.DrawFigure.Y]
        inc     edi
        ; set fig info
        ;mov     bx, [View.DrawFigure.Fig]
        ;mov     ebx, [View.DrawFigure.Color]
        ; setup loop
        mov     ecx, 16

        ; inner loop -- draw line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        ; draw rect (esi is X, edi is Y, eax - color pos in table)
        push    ecx eax
        stdcall View.DrawRect ; uses eax edx ecx
        pop     eax ecx
@@:
        inc     esi; setup cords
        dec     ecx
        test    ecx, 0000'0000'0000'0000_0000'0000'0000'0011b
        jnz     @F
        sub     esi, 4
        inc     edi
@@:
        inc     ecx
        loop    .DrawLoop

        invoke  glEnd

        ret
endp



;#############DRAW FIELD####################
proc    View.DrawField uses esi edi ebx;ecx ebx edx

        invoke  glBegin, GL_POINTS

        mov     edi, FIELD_H ; Y
        mov     ebx, FIELD_H*FIELD_W-1

DrawLoopW:
        mov     esi, FIELD_W ; X
; innnr start
.DrawLoopH:
        ; get color
        movzx   eax, byte [blocksArr + ebx]
        ; draw rect (esi is X, edi is Y, ebx - color pos in table)
        stdcall View.DrawRect
        ; go next
        dec     ebx
        dec     esi
        test    esi, esi
        jnz     .DrawLoopH
; inner end
        dec     edi
        test    edi, edi
; outer end
        jnz     DrawLoopW

        invoke  glEnd

        ret
endp

;#############DRAW RECT####################
; (TO DO THIS YOU MUST DO GlBegin!!!!!!!!!!!!!)
; - x,y    -- x,y cord
; - color
;View.DrawRect.X                    ; esi
;View.DrawRect.Y                    ; edi
;View.DrawRect.Color  (ID)          ; eax

proc View.DrawRect ;uses ecx, edx
        ; get color

        mov     dx,  12; 4 bytes for clr * 3
        mul     dx
        ; set color
        invoke  glColor3f, dword [Color_Table + eax], dword [Color_Table + eax + 4], dword [Color_Table + eax + 8]
        ; draw point
        invoke  glVertex2i, esi, edi
        ret
endp



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
        ;include 'lib\gdi32.lib'
                
        include 'opengl.inc'

        ;import  opengl,\
        ;wglCreateContext,'wglCreateContext'
        ;include 'include\imports.inc'
        ;include '..\include\opengl_const.inc'
        ;include '..\include\opengl_macros.inc'
        ;import kernel32,\
        ;ExitProcess,'ExitProcess',\
        ;GetTickCount,'GetTickCount',\
        ;GetModuleHandle, 'GetModuleHandle'

        ;import user32,\
        ;MessageBox,'MessageBoxA',\
        ;LoadCursor, 'LoadCursor',\
        ;LoadIcon, 'loadIcon',\
        ;RegisterClass, 'RegisterClass',\
        ;CreateWindowEx, 'CreateWindowEx',\
        ;DefWindowProc, 'DefWindowProc',\
        ;PostQuitMessage, 'PostQuitMessage'


        ;include 'GDIplusEffects.inc'
        ;include
        ;import  gdi,\
        ;TextOutA,'TextOutA',\
        ;CreatePen, 'CreatePen',\
        ;SelectObject, 'SelectObject',\
        ;MoveToEx, 'MoveToEx',\
        ;LineTo, 'LineTo',\
        ;CreateSolidBrush, 'CreateSolidBrush'

        import winmm,\
        mciSendString,'mciSendStringA'

        ;include 'api\kernel32.inc'
        ;include 'api\user32.inc'

        include 'units/random.h'



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


