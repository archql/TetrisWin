
;#############DRAW TEXT #####################
;  USES EBX!!!
; eax ecx edx
;  params inorder
;  - [in, stack] X cord
;  - [in, stack] Y cord
;  - [in, stack] strlen
;  - [in, stack] ANY
;  - [in, stack] strptr
; REQUIRED invoke  glListBase, [Wnd.nFontBase]
; ENABLES lighting gl!!!!!!!!!!!!!!!!
proc View.DrawText ; 10 bytes better than separate call

        invoke  glDisable, GL_LIGHTING
        invoke  glPushMatrix
        invoke  glTranslatef, 0.0, 0.0, 1.0

        pop     ebx ; ret adress
        invoke  glRasterPos2i;, FIELD_W + 3 - 1 + 8, ebx;dword [esp + 4];
        mov     dword [esp + 4], GL_UNSIGNED_BYTE
        invoke  glCallLists
        push    ebx

        invoke  glPopMatrix
        invoke  glEnable, GL_LIGHTING

        ret
endp

;#############FAST COLOR FUNCS ####################
; - they aren't fast
; - they aren't compact
; - but they're used for fast color change (call w\out params)
proc View.FastWhiteColor uses ecx ; "Fast" but BIG

        ; set White color
        mov     eax, 1.0
        invoke  glColor3f, eax, eax, eax

        ret
endp

proc View.FastYellowColor uses ecx

        ; set White color
        xor     edx, edx
        mov     eax, 1.0
        invoke  glColor3f, eax, eax, edx

        ret
endp

;#############DRAW CHAT###############
; DRAW chat
; - ClientsDataArr (read)
proc View.DrawChat uses ebx; uses ecx ebx esi edi

        ;mov     esi, Client.ClientsDataArr
        mov     ecx, FIELD_H ; loop ctr (hei * 2, bc font size / 2)
.PrintChatLoop:
        push    ecx      ; loop Ctr

        mov     esi, FIELD_H ; *2
        sub     esi, ecx ; Y pos

        mov     edi, Chat.Buf ; its addr in a table (of current msg)
        ;test    esi, esi ; if its first element ; flags already set!
        jz      @F
        ; its non first element
        movzx   edi, word [Chat.MsgPos]
        sub     edi, esi ; edi is index in the table
        inc     edi
        ;test    edi, edi ; if its < 0 -- skip  ; flags already set!
        js      .SkipLine
        shl     edi, CHAT_MSG_RCD
        add     edi, Chat.Table ; edi is addr in the table
@@:
        ; uses ebx
        stdcall View.DrawText, FIELD_W + 2 + 8, ecx, CHAT_MSG_LEN, eax, edi;esi, CHAT_MSG_LEN, eax, edi
.SkipLine:
        ; loop
        pop     ecx
        loop    .PrintChatLoop

        ret
endp

;#############DRAW LEADERBOARD###############
; safe wrap required
; uses - LB mem (read)
proc View.DrawLeaderboard
        ; alloc mem for flag
        xor     eax, eax
        inc     eax
        push    eax
        ; 1st: find amount of actual strings
        mov     edi, Settings.LeaderBoardArr
        mov     esi, edi
        add     esi, (1 shl LB_ISTR_RCD_LEN_POW) - LB_PRIO_RCD_LEN
        mov     ecx, LB_BASE_RCDS_AMOUNT - 1 ; ALG MAX 255
.DrawScoreboardLoop:
        ; set base color
        stdcall View.FastWhiteColor
        ; get rcd score & place
        mov     ebx, [esi]
        ; check if zero rcd
        test    ebx, ebx
        jz      .EndDrawScoreboardLoop
        push    ebx
        ; save base pos & count new
        xor     bx, bx   ;and     ebx, $FF'FF'00'00 (same)
        shr     ebx, 16 - LB_ISTR_RCD_LEN_POW; got real place
        push    edi
        add     edi, ebx

        ; check if this rcd correspond to cur user
        push    esi edi ecx
        ;xor     ecx, ecx
        ;inc     ecx
        ;inc     ecx
        mov     ecx, NICKNAME_LEN
        mov     esi, Game.NickName
        add     edi, 3 ; offset
        rep cmpsb
        jne     @F
        ;HIGHLIGHT SOMEWAY USER RCD
        stdcall View.FastYellowColor
        ; set flag
        mov     byte [esp + 20], 0 ; flag found
@@:
        pop     ecx edi esi
        ; check if last rcd & cur user rcd not found
        cmp     cl, byte [esp + 8] ; flag found
        jnz     @F
        mov     byte [esp + 8 + 1], 1 ; flag cur user isnt visible
        inc     ecx
        jmp     .loopSkipLine
@@:
        ; check if zero rcd
        ;mov     bx, word [esp + 4] ; ebx
        ;test    bx, bx
        ;jz      .loopSkipLine
        ; DRAW
.drawLine:
        ; count Y pos
        push    ecx; save loop ctr
        xchg    ebx, ecx
        neg     ebx
        add     ebx, LB_BASE_RCDS_AMOUNT
        ; check if cur place > 15 (can display only 15)
        mov     word [edi], '##'
        cmp     byte [esp + 12 + 1], 0
        jg      @F
        ; print cur place
        cinvoke wsprintfA, edi, Settings.PlaceFormat, ebx; ebx
@@:
        ; mov Y cord
        inc     ebx;, 2 ; 3 - 1
        inc     ebx

        ; EBX IS CHANGED!!!
        stdcall View.DrawText, FIELD_W + 3 - 1 + 8, ebx, LB_ISTR_RCD_LEN, eax, edi     ; par eax is ANY

        pop     ecx ; loop ctr

.loopSkipLine:
        pop     edi ebx
        add     esi, (1 shl LB_ISTR_RCD_LEN_POW); LEN_OF_LB_INFO_RCD
        loop    .DrawScoreboardLoop
.EndDrawScoreboardLoop:
        ; reset stack
        pop     eax
        ; reset color
        stdcall View.FastWhiteColor

        ret
endp

;#############DRAW CONNECTIONS###############
; DRAW text connections
; - ClientsDataArr (read)
proc View.DrawConnections

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
        push    ebx
        stdcall View.DrawText, FIELD_W + 2 + 8 + 11, ecx, NICKNAME_LEN, eax, esi
        pop     ebx
        ; inc ctr
        inc     dword [esp]
@@:
        add     esi, CLIENT_CL_RCD_LEN
        ; restore loop ctr
        pop     ecx
        ; test  "ping" ; WARN IF OVERFLOW (MAX RCD 64)
        test    bx, bx
        jnz     .printConnectionsLoop

        ret
endp

;#############DRAW GLOW######################
; enables gl lighting!!!!!!
proc View.DrawGlow
; setup rotation
        ;invoke  glNormal3f,  0.5, -0.3, 0.3
        invoke  glDisable, GL_LIGHTING

        fld     [Glow.AnimAngle]
        fld     [Glow.AnimDeltaAngle]
        faddp
        fstp    [Glow.AnimAngle]
        ; set Special color
        stdcall View.FastWhiteColor
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

        ;call    View.DrawEffectElement
        ; test rotating rect draw
        invoke  glPushMatrix;
        invoke  glTranslatef, dword [esp + 16], dword [esp + 16], 0.5  ;  esp -= 4 happened 2xtimes
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
        ;add     esp, 8 ;(sp+=8)
        pop     ebx
        pop     ebx
        ; go next
      .glow_skip:
        dec     ecx
        test    ecx, ecx
        jnz  .glow_draw
        ; end test glow draw
        invoke  glEnable, GL_LIGHTING
        ret
endp

; UNUSED
proc View.DrawEffectElement


        ; test rotating rect draw
        ;invoke  glPushMatrix;
        ;invoke  glTranslatef, dword [esp + 16], dword [esp + 16], 0.5  ;  esp -= 4 happened 2xtimes
        ;invoke  glBegin, GL_QUADS

                ;invoke  glVertex2f, edi, edi
                ;invoke  glVertex2f, esi, edi
                ;invoke  glVertex2f, esi, esi
                ;invoke  glVertex2f, edi, esi

        ;invoke  glEnd
        ;invoke  glPopMatrix

        ; draw background texture
        invoke  glPushMatrix
        invoke  glTranslatef, dword [esp + 20], dword [esp + 20], 0.5
        invoke  glRotatef, [Glow.AnimAngle], 0.0, 0.0, 0.5;
        invoke  glEnable, GL_TEXTURE_2D
        invoke  glBegin, GL_QUADS
                invoke  glTexCoord2i, 0, 1
                invoke  glVertex2f, edi, edi
                invoke  glTexCoord2i, 1, 1
                invoke  glVertex2f, esi, edi
                invoke  glTexCoord2i, 1, 0
                invoke  glVertex2f, esi, esi
                invoke  glTexCoord2i, 0, 0
                invoke  glVertex2f, edi, esi
        invoke  glEnd
        invoke  glDisable, GL_TEXTURE_2D
        invoke  glPopMatrix

        ret
endp

;#############DRAW GAME######################
; constts:
SUBR_SZ_MOD = 5
DSUBR_SZ_MOD = 5.0
; number at
proc View.DrawGame uses ebx ;

        ; num in ebx, so
        xor     edx, edx
        mov     eax, dword [sub_scale] ; get scale factor
        xchg    eax, ebx
        div     ebx
        ; now edx is X pos, eax is Y pos
        ; get 'em
        mov     ecx, sub_ ; set offset of structure (free rg ecx)
        push    ecx ; save offset of structure sub
        ; (x)
        mov     dword [ecx + (sub_x_pos - sub_)], edx
        fild    dword [ecx + (sub_x_pos - sub_)]
        fld     qword [sub_DFIELD_W]
        fmulp   st1, st0
        fst     dword [ecx + (sub_x_pos - sub_)]
        fchs
        fstp    dword [ecx + (sub_inv_x_pos - sub_)]
        ; (y)
        mov     dword [ecx + (sub_y_pos - sub_)], eax
        fild    dword [ecx + (sub_y_pos - sub_)]
        fld     qword [DFIELD_H]
        fmulp   st1, st0
        fst     dword [ecx + (sub_y_pos - sub_)]
        fchs
        fstp    dword [ecx + (sub_inv_y_pos - sub_)]
        ; translate matrix
        invoke  glTranslatef, [ecx + (sub_x_pos - sub_)], [ecx + (sub_y_pos - sub_)], 0.0  ; DFIELD_W + 3 - 1 + 8 = 23

        ; set draw
        ;invoke  glBegin, GL_POINTS
        ; set base pos
        mov     eax, esi ; base pos
        add     eax, NICKNAME_LEN + 2 + (Game.BlocksArr - TetrisFrame)  ; GameBuffer EVERYWHERE replaced with TetrisFrame
        ; draw
        stdcall View.DrawField

        ; draw fig
        push    esi
        mov     ecx, esi
        ; draw figure figure
        mov     bx,  word [ecx + NICKNAME_LEN + 2 + (Game.CurFig      - TetrisFrame)]  ; figure
        movzx   esi, word [ecx + NICKNAME_LEN + 2 + (Game.FigX        - TetrisFrame)]  ; X
        movzx   edi, word [ecx + NICKNAME_LEN + 2 + (Game.FigY        - TetrisFrame)]  ; Y
        movzx   eax, byte [ecx + NICKNAME_LEN + 2 + (Game.CurFigColor - TetrisFrame)]  ; movzx
        stdcall View.DrawFigure, eax
        ; restore
        pop     esi

        ; end draw
        ;invoke  glEnd

        ; set clr
        stdcall View.FastWhiteColor

        ; DRAW text
        mov     eax, esi ; base pos
        add     eax, NICKNAME_LEN + 2 + (Game.NickName - TetrisFrame)
        stdcall View.DrawText, (FIELD_W - NICKNAME_LEN) / 2 + 2, 1, NICKNAME_LEN , eax, eax;Str.Score
        ; DRAW text
        mov     eax, esi ; base pos
        add     eax, NICKNAME_LEN + 2 + (Str.Score - TetrisFrame)
        stdcall View.DrawText, (FIELD_W - SCORE_LEN_CONST) / 2 + 1, 2, SCORE_LEN_CONST , eax, eax;Str.Score
        ; DRAW text
        ;mov     eax, esi ; base pos
        ;add     eax, NICKNAME_LEN + 2 + (Str.Score - GameBuffer)
        ;stdcall View.DrawText, (FIELD_W - SCOLE_LEN_CONST) / 2 + 2, 2, SCOLE_LEN_CONST , eax, eax;Str.Score
        ; Translate back
        pop     ecx ; restore offset of structure sub
        invoke  glTranslatef, [ecx + (sub_inv_x_pos - sub_)], [ecx + (sub_inv_y_pos - sub_)], 0.0  ; DFIELD_W + 3 - 1 + 8 = 23

        ret
endp

;#############CREATE FONT####################
; params inorder
; [in, esi] ptr to font struct (dword base, dword size : inorder)
proc View.CreateFont
        ; create font
        xor     ebx, ebx
        ;delete old fonts
        mov     eax, dword [esi]
        test    eax, eax
        jz      @F
        invoke  glDeleteLists, eax, NUM_OF_CHARACTERS
@@:
        ; get wnd hdc
        mov     edi, [Wnd.hdc]
        ; create font "Lucida Console" sz
        invoke  CreateFontA, dword [esi + 4], ebx, ebx, ebx, 600,\
                          ebx, ebx, ebx, ebx, ebx, ebx, ebx, ebx, Wnd.font_name
        invoke  SelectObject, edi, eax

        invoke  glGenLists, NUM_OF_CHARACTERS
        mov     dword [esi], eax ; save place where bitmaps created

        ; set font
        invoke  wglUseFontBitmapsA, edi, ebx, NUM_OF_CHARACTERS, eax ; if errors ret 0

        ret
endp


;#############DRAW FIGURE####################
; (TO DO THIS YOU MUST DO GlBegin GL_POINTS!!!!!!!!!!!!!)
; - fig    -- 2 bytes fig data
; - x,y    -- x,y cord
;View.DrawFigure.Fig             bx
;View.DrawFigure.X               esi; hi word is zero!
;View.DrawFigure.Y               edi; hi word is zero!
;View.DrawFigure.Color           (stack)
proc View.DrawFigure uses ecx,\
                     color
        ; begin paint
        ;invoke  glBegin, GL_POINTS
        ; get color
        mov     eax, [color]
        ; set x pos
        ;mov     si, [View.DrawFigure.X]
        inc      si
        ; set y pos
        ;mov     di, [View.DrawFigure.Y]
        inc      di
        ; set fig info
        ;mov     bx, [View.DrawFigure.Fig]
        ;mov     ebx, [View.DrawFigure.Color]
        ; setup loop
        xor     ecx, ecx
        mov     cl, 16

        ; inner loop -- draw line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        test    edi, edi
        js      @F
        ; draw rect (esi is X, edi is Y, eax - color pos in table)
        push    ecx eax
        stdcall View.DrawRect ; uses eax edx ecx
        pop     eax ecx
@@:
        inc     esi; setup cords
        dec     ecx
        test    cl, 0000'0011b
        jnz     @F
.nextLine:
        sub     si, 4
        inc     edi
@@:
        inc     ecx
        loop    .DrawLoop

        ret
endp



;#############DRAW FIELD####################
; (TO DO THIS YOU MUST DO GlBegin GL_POINTS!!!!!!!!!!!!!)
; requires pointer to Field Matrix in eax
proc    View.DrawField uses esi edi ebx;ecx ebx edx

        ;push    eax
        ;stdcall Random.Get, 0, 6000
        ;mov     edi, eax
        ;pop     eax
        ;sub     eax, Game.BlocksArr
        ;add     eax, start;Str.NextFig
        ;add     eax, edi

        mov     edi, FIELD_H ; Y
        mov     ebx, FIELD_H*FIELD_W-1
        add     ebx, eax;

DrawLoopW:
        mov     esi, FIELD_W ; X
; innnr start
.DrawLoopH:
        ; get color
        movzx   eax, byte [ebx]
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

        ret
endp

;#############DRAW RECT####################
; (TO DO THIS YOU MUST DO GlBegin GL_POINTS!!!!!!!!!!!!!)
; - x,y    -- x,y cord
; - color
;View.DrawRect.X                    ; esi
;View.DrawRect.Y                    ; edi
;View.DrawRect.Color  (ID)          ; eax

proc View.DrawRect uses ebx ;uses ecx, edx
        ; test color
        test    ax, ax
        jz      .exit_proc
        ; preset Z cord
        mov     edx, -0.8
        ; check if border block
        cmp     ax, 1
        jne     @F
        mov     edx, -0.3
@@:
        cmp     ax, 2
        jne     @F
        mov     edx, -1.2
@@:
        push    edx
        ; get color
        mov     edx,  12; 4 bytes for clr * 3
        mul     dx
        ; set color
        invoke  glColor3f, dword [Color_Table + eax], dword [Color_Table + eax + 4], dword [Color_Table + eax + 8]
        ; TEST loop for depth
        ;mov    ebx, 60
        ; TEST
        push   0.9
        fld    dword [esp]
        pop    edx
        fld    dword [esp]
        pop    edx ; clean stack
  .DepthLoop:
        fsub   st0, st1
        push   edx ; reserve stack
        fst    dword [esp]

        invoke  glPushMatrix

        push    edi
        fild    dword [esp]
        fstp    dword [esp]
        ;pop     ecx
        push    esi
        fild    dword [esp]
        fstp    dword [esp]
        ;pop     edx

        invoke  glTranslatef;, ecx, edx, 0.0

        invoke  glCallList, VIEW_LIST_PRIMITIVE

        invoke  glPopMatrix
        ; DEPTH loop
        ;dec     ebx
        ;cmp     ebx, 0 ; temp
        ;jg      .DepthLoop
        ; TEST

        ; clear stack
        finit
        ;fincstp
        ;fincstp
.exit_proc:
        ; draw point
        ;invoke  glVertex2i, esi, edi
        ret
endp

        VIEW_LIST_PRIMITIVE = 1000

proc View.CreatePrimitive.Point

        invoke  glDeleteLists, VIEW_LIST_PRIMITIVE, 1
        invoke  glNewList, VIEW_LIST_PRIMITIVE, GL_COMPILE ; 1000 is test

        invoke  glBegin, GL_POINTS
        xor     eax, eax
        invoke  glVertex2i, eax, eax

        invoke  glEnd
        ; ================================
        invoke  glEndList;  // End of drawing color-cube

        ret
endp

        ;
proc View.CreatePrimitive.Cube

        invoke  glDeleteLists, VIEW_LIST_PRIMITIVE, 1
        invoke  glNewList, VIEW_LIST_PRIMITIVE, GL_COMPILE ; 1000 is test

        invoke  glBegin, GL_QUADS
        ;=========================
        xor     ebx, ebx
        mov     esi, -0.48
        mov     edi, 0.48

        ; Top face (y = 1.0f)
        ; Define vertices in counter-clockwise (CCW) order with normal pointing out
        ;invoke  glColor3f, 0.0, 1.0, 0.0;     // Green
        invoke  glNormal3f, ebx, 1.0, ebx
        invoke  glVertex3f, edi, edi, esi;
        invoke  glVertex3f, esi, edi, esi;
        invoke  glVertex3f, esi, edi, edi;
        invoke  glVertex3f, edi, edi, edi;
 
        ; Bottom face (y = -1.0f)
        ;invoke  glColor3f, 1.0, 0.5, 0.0;     // Orange
        invoke  glNormal3f, ebx, -1.0, ebx
        invoke  glVertex3f, edi, esi, edi;
        invoke  glVertex3f, esi, esi, edi;
        invoke  glVertex3f, esi, esi, esi;
        invoke  glVertex3f, edi, esi, esi;
 
        ;// Front face  (z = 1.0f)
        ;invoke  glColor3f, 1.0, 0.0, 0.0;     // Red
        invoke  glNormal3f, ebx, ebx, 1.0
        invoke  glVertex3f, edi, edi, edi;
        invoke  glVertex3f, esi, edi, edi;
        invoke  glVertex3f, esi, esi, edi;
        invoke  glVertex3f, edi, esi, edi;
 
        ;// Back face (z = -1.0f)
        ;invoke  glColor3f, 1.0, 1.0, 0.0;     // Yellow
        invoke  glNormal3f, ebx, ebx, -1.0
        invoke  glVertex3f, edi, esi, esi;
        invoke  glVertex3f, esi, esi, esi;
        invoke  glVertex3f, esi, edi, esi;
        invoke  glVertex3f, edi, edi, esi;
 
        ;// Left face (x = -1.0f)
        ;invoke  glColor3f, 0.0, 0.0, 1.0;     // Blue
        invoke  glNormal3f, -1.0, ebx, ebx
        invoke  glVertex3f, esi, edi, edi;
        invoke  glVertex3f, esi, edi, esi;
        invoke  glVertex3f, esi, esi, esi;
        invoke  glVertex3f, esi, esi, edi;
 
        ;// Right face (x = 1.0f)
        ;invoke  glColor3f, 1.0, 0.0, 1.0;     // Magenta
        invoke  glNormal3f, 1.0, ebx, ebx
        invoke  glVertex3f, edi, edi, esi;
        invoke  glVertex3f, edi, edi, edi;
        invoke  glVertex3f, edi, esi, edi;
        invoke  glVertex3f, edi, esi, esi;

        invoke  glEnd
        ; ================================
        invoke  glEndList;  // End of drawing color-cube

        ret
endp

; [in, esi] ptr to tex file or null
proc View.CreatePrimitive.TexturedCube  ; uses eax ebx ecx edx esi edi

        locals
                bufsz           dd      0
                bufadr          dd      ?
                bytesProceed    dd      ?
        endl

        ;Texture test
        invoke  glEnable, GL_TEXTURE_2D
        ;cmp     [View.TextureID], 0
        ;jnz     @F
        invoke  glDeleteTextures, 1, View.TextureID
        ; if tex not created -- create
        invoke  glGenTextures, 1, View.TextureID
        invoke  glBindTexture, GL_TEXTURE_2D, [View.TextureID]
     ;@@:
        ; check if file ld needed
        test    esi, esi
        jnz     @F
        ; Get next tex filename
        stdcall Settings.View.GetNextTexture
        cmp     [View.TextureFileLookupHandle], 0
        je      .Error
        mov     esi, View.TextureFileDataa.cFileName
    @@:
        ;Open file
        xor     ebx, ebx
        invoke  CreateFileA, esi, GENERIC_READ, ebx, ebx,\
                                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, ebx
        cmp     eax, INVALID_HANDLE_VALUE
        je      .Error
        mov     esi, eax
        ; get file size
        invoke  GetFileSize, eax, ebx
        cmp     eax, -1
        je      .Error
        ; alloc eax bytes on stack
        lea     edx, [esp] ; save old pos
        mov     [bufsz], eax
        mov     ecx, eax ; save img sz
        sub     esp, eax
        lea     eax, [esp]
        mov     [bufadr], eax
        ; run stack and alloc pages
        shr     ecx, 10 ; % 1024
.PageRun:
        test    [edx], edx
        sub     edx, 0x400 ; 1024
        loop    .PageRun
        ; read next bytes
.TryReadNext:
        lea     eax, [bytesProceed]
        invoke  ReadFile, esi, [bufadr], [bufsz], eax, ebx
        cmp     [bytesProceed], ebx
        jg      .TryReadNext

 .EndRead:
        invoke  CloseHandle, esi

        add     [bufadr], 36h; skip bmp header
        mov     eax, [bufadr]
        mov     eax, [eax - 20h]
        invoke  glTexImage2D, GL_TEXTURE_2D, ebx, GL_RGB8, eax, eax, ebx, GL_BGR, GL_UNSIGNED_BYTE, [bufadr]
        invoke  glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE
        invoke  glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE
        invoke  glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR
        invoke  glTexParameteri, GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR

        invoke  glDisable, GL_TEXTURE_2D
;===============================================================================================
.Error:
        ; generate list
        invoke  glDeleteLists, VIEW_LIST_PRIMITIVE, 1
        invoke  glNewList, VIEW_LIST_PRIMITIVE, GL_COMPILE ; 1000 is test

        invoke  glEnable, GL_TEXTURE_2D
        invoke  glBegin, GL_QUADS
        ;=========================
        mov     ebx, 0.0
        mov     esi, -0.48
        mov     edi, 0.48

        ; Top face (y = 1.0f)
        ; Define vertices in counter-clockwise (CCW) order with normal pointing out
        ;invoke  glColor3f, 0.0, 1.0, 0.0;     // Green
        invoke  glNormal3f, ebx, 1.0, ebx
        invoke  glTexCoord2i, 1, 0 ; 0, 1
        invoke  glVertex3f, edi, edi, esi;
        invoke  glTexCoord2i, 0, 0
        invoke  glVertex3f, esi, edi, esi;
        invoke  glTexCoord2i, 0, 1
        invoke  glVertex3f, esi, edi, edi;
        invoke  glTexCoord2i, 1, 1
        invoke  glVertex3f, edi, edi, edi;
 
        ; Bottom face (y = -1.0f)
        ;invoke  glColor3f, 1.0, 0.5, 0.0;     // Orange
        invoke  glNormal3f, ebx, -1.0, ebx
        invoke  glTexCoord2i, 1, 0 ; 0, 1
        invoke  glVertex3f, edi, esi, edi;
        invoke  glTexCoord2i, 0, 0 ; 0, 0
        invoke  glVertex3f, esi, esi, edi;
        invoke  glTexCoord2i, 0, 1
        invoke  glVertex3f, esi, esi, esi;
        invoke  glTexCoord2i, 1, 1
        invoke  glVertex3f, edi, esi, esi;
 
        ;// Front face  (z = 1.0f)
        ;invoke  glColor3f, 1.0, 0.0, 0.0;     // Red
        invoke  glNormal3f, ebx, ebx, 1.0
        invoke  glTexCoord2i, 1, 0 ; 0, 1
        invoke  glVertex3f, edi, edi, edi;
        invoke  glTexCoord2i, 0, 0 ; 0, 0
        invoke  glVertex3f, esi, edi, edi;
        invoke  glTexCoord2i, 0, 1 ; 1, 0
        invoke  glVertex3f, esi, esi, edi;
        invoke  glTexCoord2i, 1, 1 ; 1, 1
        invoke  glVertex3f, edi, esi, edi;
 
        ;// Back face (z = -1.0f)
        ;invoke  glColor3f, 1.0, 1.0, 0.0;     // Yellow
        invoke  glNormal3f, ebx, ebx, -1.0
        invoke  glTexCoord2i, 0, 1 ; 0, 1
        invoke  glVertex3f, edi, esi, esi;
        invoke  glTexCoord2i, 1, 1 ; 0, 0
        invoke  glVertex3f, esi, esi, esi;
        invoke  glTexCoord2i, 1, 0 ; 1, 0
        invoke  glVertex3f, esi, edi, esi;
        invoke  glTexCoord2i, 0, 0 ; 1, 1
        invoke  glVertex3f, edi, edi, esi;
 
        ;// Left face (x = -1.0f)
        ;invoke  glColor3f, 0.0, 0.0, 1.0;     // Blue
        invoke  glNormal3f, -1.0, ebx, ebx
        invoke  glTexCoord2i, 1, 0 ; 0, 1
        invoke  glVertex3f, esi, edi, edi;
        invoke  glTexCoord2i, 0, 0 ; 0, 0
        invoke  glVertex3f, esi, edi, esi;
        invoke  glTexCoord2i, 0, 1 ; 1, 0
        invoke  glVertex3f, esi, esi, esi;
        invoke  glTexCoord2i, 1, 1 ; 1, 1
        invoke  glVertex3f, esi, esi, edi;
 
        ;// Right face (x = 1.0f)
        ;invoke  glColor3f, 1.0, 0.0, 1.0;     // Magenta
        invoke  glNormal3f, 1.0, ebx, ebx
        invoke  glTexCoord2i, 1, 0 ; 0, 1
        invoke  glVertex3f, edi, edi, esi;
        invoke  glTexCoord2i, 0, 0 ; 0, 0
        invoke  glVertex3f, edi, edi, edi;
        invoke  glTexCoord2i, 0, 1 ; 1, 0
        invoke  glVertex3f, edi, esi, edi;
        invoke  glTexCoord2i, 1, 1 ; 1, 1
        invoke  glVertex3f, edi, esi, esi;

        invoke  glEnd
        invoke  glDisable, GL_TEXTURE_2D
        ; ================================
        invoke  glEndList;  // End of drawing color-cube

;===============================================================================================
        ; dealloc bufsz bytes on stack
        add     esp, [bufsz]
.Exit:


        ret
endp
