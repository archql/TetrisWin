
;#############DRAW TEXT #####################
;  USES EBX!!!
;  params inorder
;  - [in, stack] X cord
;  - [in, stack] Y cord
;  - [in, stack] strlen
;  - [in, stack] ANY
;  - [in, stack] strptr
; REQUIRED invoke  glListBase, [Wnd.nFontBase]
proc View.DrawText ; 10 bytes better than separate call

        pop     ebx ; ret adress
        invoke  glRasterPos2i;, FIELD_W + 3 - 1 + 8, ebx;dword [esp + 4];
        mov     dword [esp + 4], GL_UNSIGNED_BYTE
        invoke  glCallLists
        push    ebx

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
proc View.DrawChat

        ;mov     esi, Client.ClientsDataArr
        mov     ecx, FIELD_H ; loop ctr (hei * 2, bc font size / 2)
.PrintChatLoop:
        push    ecx      ; loop Ctr

        mov     esi, FIELD_H ; *2
        sub     esi, ecx ; Y pos

        mov     edi, Chat.Buf ; its addr in a table (of current msg)
        ;test    esi, esi ; if its first element
        jz      @F
        ; its non first element
        movzx   edi, word [Chat.MsgPos]
        sub     edi, esi ; edi is index in the table
        inc     edi
        ;test    edi, edi ; if its < 0 -- skip
        js      .SkipLine
        shl     edi, CHAT_MSG_RCD
        add     edi, Chat.Table ; edi is addr in the table
@@:
        push    ebx
        stdcall View.DrawText, FIELD_W + 2 + 8, ecx, CHAT_MSG_LEN, eax, edi;esi, CHAT_MSG_LEN, eax, edi
        pop     ebx
.SkipLine:
        ; loop
        pop     ecx
        loop    .PrintChatLoop



        ret
endp

;#############DRAW LEADERBOARD###############
; safe wrap required
; uses - LB mem (read)
; first -- alloc mem for flag (if cur usr founded)
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
proc View.DrawGlow
; setup rotation
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
        mov     eax, dword [sub_scale] ; get scale f
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
        invoke  glBegin, GL_POINTS
        ; set base pos
        mov     eax, esi ; base pos
        add     eax, NICKNAME_LEN + 2 + (Game.BlocksArr - GameBuffer)
        ; draw
        stdcall View.DrawField

        ; draw fig
        push    esi
        mov     ecx, esi
        ; draw figure figure
        mov     bx,  word [ecx + NICKNAME_LEN + 2 + (Game.CurFig      - GameBuffer)]  ; figure
        movzx   esi, word [ecx + NICKNAME_LEN + 2 + (Game.FigX        - GameBuffer)]  ; X
        movzx   edi, word [ecx + NICKNAME_LEN + 2 + (Game.FigY        - GameBuffer)]  ; Y
        movzx   eax, byte [ecx + NICKNAME_LEN + 2 + (Game.CurFigColor - GameBuffer)]  ; movzx
        stdcall View.DrawFigure, eax
        ; restore
        pop     esi

        ; end draw
        invoke  glEnd

        ; set clr
        stdcall View.FastWhiteColor

        ; DRAW text
        mov     eax, esi ; base pos
        add     eax, NICKNAME_LEN + 2 + (Game.NickName - GameBuffer)
        stdcall View.DrawText, (FIELD_W - NICKNAME_LEN) / 2 + 2, 1, NICKNAME_LEN , eax, eax;Str.Score
        ; DRAW text
        mov     eax, esi ; base pos
        add     eax, NICKNAME_LEN + 2 + (Str.Score - GameBuffer)
        stdcall View.DrawText, (FIELD_W - SCOLE_LEN_CONST) / 2 + 1, 2, SCOLE_LEN_CONST , eax, eax;Str.Score
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
; - ptr to font struct (esi) (dword base, dword size : inorder)
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
        inc     si
        ; set y pos
        ;mov     di, [View.DrawFigure.Y]
        inc     di
        ; set fig info
        ;mov     bx, [View.DrawFigure.Fig]
        ;mov     ebx, [View.DrawFigure.Color]
        ; setup loop
        mov     ecx, 16

        ; inner loop -- draw line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        test    di, 0x80'00 ; check if Y cord < 0
        jnz     @F
        ; draw rect (esi is X, edi is Y, eax - color pos in table)
        push    ecx eax
        stdcall View.DrawRect ; uses eax edx ecx
        pop     eax ecx
@@:
        inc     si; setup cords
        dec     ecx
        test    ecx, 0000'0000'0000'0000_0000'0000'0000'0011b
        jnz     @F
.nextLine:
        sub     si, 4
        inc     di
@@:
        inc     ecx
        loop    .DrawLoop

        ret
endp



;#############DRAW FIELD####################
; (TO DO THIS YOU MUST DO GlBegin GL_POINTS!!!!!!!!!!!!!)
; requires pointer to Field Matrix in eax
proc    View.DrawField uses esi edi ebx;ecx ebx edx

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