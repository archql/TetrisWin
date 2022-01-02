;========Game Settings==============
        ;Settings.strFilename      db    '_ARCHQL_.ttr', 0
        ;Settings.strTempFilename  db    '________'
        ;Settings.strTempLen       dw    0

        ;Settings.buffer           db    4 dup ?
        ;Settings.BytesProceed     dd    ?
        ;FILE_SZ_TO_READ           = 2



;#############GET HIGH SCORE####################
; ret high score in ax
proc Settings.GetHigh

        xor     ebx, ebx
        ; createfile
        invoke  CreateFileA, Settings.strFilename, GENERIC_READ, FILE_SHARE_READ, ebx, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, ebx
        xchg    eax, ebx ; save handle
        cmp     eax, INVALID_HANDLE_VALUE
        je      .EndProc
@@:
        ; read high
        invoke  ReadFile, ebx, Settings.buffer, FILE_SZ_TO_READ, Settings.BytesProceed, 0
        ; close file
        invoke  CloseHandle, ebx
        ; check if smth readed
        cmp     [Settings.BytesProceed], 0
        je      .EndProc
        ; set high
        mov     ax, word [Settings.buffer]
        jmp     @F ; skip reset score
.EndProc:
        xor     ax, ax
@@:
        mov     word [Game.HighScore], ax  ;[Settings.strHighScore]

        ret
endp

;#############SET HIGH SCORE####################
; got high score in ax
proc Settings.SetHigh
        ; convert num to str
        ;cinvoke wsprintfA, Settings.buffer, buf_format, eax
        ; mov high to buffer
        mov     word [Settings.buffer], ax
        ; temp set pos!!!!!
        xor     ebx, ebx
        ; createfile
        invoke  CreateFileA, Settings.strFilename, GENERIC_WRITE, FILE_SHARE_READ, ebx, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, ebx
        xchg    eax, ebx ; save handle
        cmp     eax, INVALID_HANDLE_VALUE
        je      .EndProc
        ; write high
        invoke  WriteFile, ebx, Settings.buffer, FILE_SZ_TO_READ, Settings.BytesProceed, 0
        ; close file
        invoke  CloseHandle, ebx
        ;invoke  GetLastError
        ;xor     ax, ax
        ; !!!!
.EndProc:
        ret
endp

;#############GET ALL RCD FILES####################
proc Settings.LdScoreboard

        invoke  FindFirstFile, Settings.strFileFilter, Settings.fileData
        xchg    eax, ebx; ebx is file lookup handle
        test    ebx, ebx
        jz      @F
        mov     ecx, 0
.Loop_Find:
        push    ecx; loop ctr
        ; write got str to rcd
        mov     esi, Settings.fileData.cFileName; ptr to filename str
        mov     edi, ecx
        shl     edi, LB_ISTR_RCD_LEN_POW ; get cur pos in rcds (dep on LB_ISTR_RCD_LEN)
        add     edi, Settings.LeaderBoardArr;Settings.LeaderBoardArr + 3
        push    edi
        ; clear mem
        mov     ecx, 2 shl LB_ISTR_RCD_LEN_POW
        xor     eax, eax
        rep     stosb
        ; return to start
        mov     edi, [esp]
        add     edi, 3 ; 3 reserved symbols
        mov     ecx, LB_NAME_STR_LEN
        rep     movsb
        ; read file
        invoke  CreateFileA, Settings.fileData.cFileName, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
        cmp     eax, INVALID_HANDLE_VALUE
        je      .EndTryLdFile; failed :/
        ; read high
        push    eax ; save handle
        invoke  ReadFile, eax, Settings.buffer, FILE_SZ_TO_READ, Settings.BytesProceed, 0 ; [nSize]
        ; close file handle
        invoke  CloseHandle ; uses file handle in stack
        ; check if smth readed
        cmp     [Settings.BytesProceed], 0
        jne     @F; jmp if good
        mov     word [Settings.buffer], 0
@@:
        ; set high
        inc     edi
        movzx   eax, word [Settings.buffer]
        push    eax ; save score sa num
        ; write score
        cinvoke wsprintfA, edi, Str.Score.Format, eax
        ; save score and rcd nmb
        pop     eax
        mov     edi, [esp + 4]; get loop counter
        mov     esi, [esp]; get rcd place in arr
        add     esi, (1 shl LB_ISTR_RCD_LEN_POW) - LB_PRIO_RCD_LEN;3 reserved symbols
        mov     [esi], ax
        mov     [esi + LB_PRIO_RCD_LEN / 2], di ;??
        ; sort loop
        mov     edi, esi ; same value ptr to cur rcd
.SortLoop:
        sub     esi, (1 shl LB_ISTR_RCD_LEN_POW); go back
        cmp     esi, Settings.LeaderBoardArr; while not less than begining of arr
        jl      .EndTryLdFile
        ; here is sort loop
        mov     eax, [esi]
        mov     ecx, [edi]
        cmp     ax, cx
        jge     @F ; if inorder skip
        ; swap
        mov     [esi], ecx
        mov     [edi], eax
@@:
        ; sort loop end
        mov     edi, esi
        jmp     .SortLoop

.EndTryLdFile:
        ; reset stack
        pop     edi
        ; write cur
        ; invoke  MessageBox, 0, Settings.LeaderBoardArr, Caption, MB_OK or MB_ICONERROR;
        ; find next
        invoke  FindNextFile, ebx, Settings.fileData
        ; loop
        pop     ecx
        inc     ecx
        test    eax, eax; find next file result in eax
        jnz     .Loop_Find
.EndProc:
        ret
endp

