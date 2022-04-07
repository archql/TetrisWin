
        ; set cur name
        mov     esi, Game.NickName
        mov     edi, Chat.Buf
        mov     ecx, NICKNAME_LEN
        rep movsb

        ; add 2 buf smls
        ;mov     edi, 2
        movzx   edi, [Chat.InpPos]

        ; check if enter pressed
        cmp     eax, VK_RETURN
        jne     @F
        ; send
        call    Client.SendChatMsg
@@:

        ; continue event work
        cmp     eax, VK_BACK
        jne     @F
        ; clear one symbol if can
        test    edi, edi
        jz      .defwndproc
        ; dec to cur symbol
        dec     edi
        ; ld new symbol
        mov     [edi + CHAT_MSG_OFF + Chat.Buf], ' '
        jmp     .endMsgGet
@@:
        cmp     eax, VK_LEFT ; go one smbl left
        jne     @F
        test    edi, edi; if can go left
        jz      .defwndproc
        dec     edi
        jmp     .endMsgGet
@@:
        cmp     eax, VK_RIGHT ; go one smbl right
        jne     @F
        cmp     edi, CHAT_MSG_MAX; if can go right
        jae     .defwndproc
        inc     edi
        jmp     .endMsgGet
@@:
        ; check if normal key pressed
        cmp     eax, 32
        jb      .endMsgIn
        cmp     eax, 126
        ja      .endMsgIn
        ; if >= MAX -- stop!
        cmp     edi, CHAT_MSG_MAX
        jae     .defwndproc
        ; ld new symbol
        mov     [edi + CHAT_MSG_OFF + Chat.Buf], al
        inc     edi
        ; return
.endMsgGet:
        ; save new pos
        mov     word [Chat.InpPos], di
.endMsgIn:
        ; do updated higligtion
        ;jmp     .defwndproc

; defwndproc -- is to exit this context