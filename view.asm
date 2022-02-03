
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