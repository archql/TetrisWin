
        ; check if control key
        cmp     eax, VK_RETURN
        jne     @F

        ; set cur name
        mov     esi, Settings.strTempNickName
        mov     edi, Game.NickName
        mov     ecx, LB_NAME_STR_LEN
        rep movsb
        ; ld new file
        mov     eax, Game.NickName
        stdcall Settings.GetHigh; ret high in eax
        ;TEMP WRITE HIGH
        mov     word [Game.HighScore], ax
        cinvoke wsprintfA, Str.HighScore, Str.Score.Format, eax
        ;
        xor     edi, edi
        jmp     .endFileNameGet
@@:
        ; get new symbol place
        movzx   edi, word [Settings.strTempLen]

        ; continue event work
        cmp     eax, VK_BACK
        jne     @F
        ; clear one symbol if can
        test    edi, edi
        jz      .defwndproc
        ; dec to cur symbol
        dec     edi
        ; ld new symbol
        mov     byte [edi + Settings.strTempNickName], '_'  ; got 4 bytes
        jmp     .endFileNameGet
@@:
        cmp     eax, VK_LEFT ; go one smbl left
        jne     @F
        test    edi, edi; if can go left
        jz      .defwndproc
        dec     edi
        jmp     .endFileNameGet
@@:
        cmp     eax, VK_RIGHT ; go one smbl right
        jne     @F
        cmp     edi, LB_NAME_STR_LEN; if can go right
        jae     .defwndproc
        inc     edi
        jmp     .endFileNameGet
@@:
        ; check if normal key pressed
        cmp     eax, 'A'
        jb      .highLightUpdate
        cmp     eax, 'Z'
        ja      .highLightUpdate
        ; if >= 8 -- stop!
        cmp     edi, LB_NAME_STR_LEN
        jae     .defwndproc
        ; ld new symbol
        mov     byte [edi + Settings.strTempNickName], al  ; got 8 bytes
        ; go to next
        inc     edi
        ; return
.endFileNameGet:
        ; save new pos
        mov     word [Settings.strTempLen], di
.highLightUpdate:
        ; clear highligtion
        ; save pos
        push    edi
        ;
        mov     eax, ' '
        mov     edi, Settings.strTempNickNameHighlight
        mov     ecx, 8 + 1
        rep stosb
        ; restore pos
        pop     edi
        ; highlight it
        mov     [Settings.strTempNickNameHighlight + edi], '^'

        jmp     .defwndproc

; defwndproc -- is to exit this context