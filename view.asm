
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

        ;invoke  glEnd

        ret
endp



;#############DRAW FIELD####################
proc    View.DrawField uses esi edi ebx;ecx ebx edx

        ;invoke  glBegin, GL_POINTS

        mov     edi, FIELD_H ; Y
        mov     ebx, FIELD_H*FIELD_W-1

DrawLoopW:
        mov     esi, FIELD_W ; X
; innnr start
.DrawLoopH:
        ; get color
        movzx   eax, byte [Game.BlocksArr + ebx]
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

        ;invoke  glEnd

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