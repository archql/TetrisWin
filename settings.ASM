;========Game Settings==============
        Settings.strFilename      db    '_ARCHQL_.ttr', 0
        Settings.strTempFilename  db    '________'
        Settings.tempLen          dw    0
        Settings.buffer           db    4 dup ?
        Settings.BytesProceed     dd    ?
        FILE_SZ_TO_READ           = 2



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

; addl data to ld scoreboard
Settings.strFileFilter      db    '*.ttr', 0
Settings.PlaceFormat        db    '#%X', 0
Settings.fileData           WIN32_FIND_DATAA

LB_NAME_STR_LEN             = 8


Settings.AllocatedMem       dd  ?
         LB_ISTR_RCD_LEN      = 17
         LB_ISTR_RCD_LEN_POW  = 5; Real mem sz allocated 2^LB_RCDS_AMOUNT
;Settings.LeaderBoardPrio:   times (LB_BASE_RCDS_AMOUNT) dw 0, 0 ; place, score
         LB_PRIO_RCD_LEN      = 4

LB_BASE_RCDS_AMOUNT         = 16
struct AllocatedMem
        ;blocksArr1:        db     FIELD_W*FIELD_H dup ?
        ;glowArr:           db     FIELD_H dup ?
        LeaderBoardSz       dd     ?
        LeaderBoardArr      db     LB_BASE_RCDS_AMOUNT*(1 shl LB_ISTR_RCD_LEN_POW) dup ? ; 4 is base sz, last 4 bytes is for place & score sort
ends        

;#############GET ALL RCD FILES####################
proc Settings.LdScoreboard uses ebp
        mov     ebp, [Settings.AllocatedMem] ; save ptr to allocated mem on stack

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
        add     edi, AllocatedMem.LeaderBoardArr + 3;Settings.LeaderBoardArr + 3; 3 reserved symbols
        add     edi, ebp
        push    edi ; save adr to write it on screen
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
        ;pop     eax
        invoke  CloseHandle
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
        add     esi, (1 shl LB_ISTR_RCD_LEN_POW) - LB_PRIO_RCD_LEN - 3 ;3 reserved symbols
        mov     [esi], ax
        mov     [esi + LB_PRIO_RCD_LEN / 2], di ;??
        ; set start of arr
        push    ebp
        add     ebp, AllocatedMem.LeaderBoardArr
        ; sort loop
        mov     edi, esi ; same value ptr to cur rcd
.SortLoop:
        sub     esi, (1 shl LB_ISTR_RCD_LEN_POW); go back
        cmp     esi, ebp; while not less than begining of arr
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
        pop     ebp edi
        ; write cur
        ; invoke  MessageBox, 0, Settings.LeaderBoardArr, Caption, MB_OK or MB_ICONERROR;
        ; find next
        invoke  FindNextFile, ebx, Settings.fileData
        ; loop
        pop     ecx
        inc     ecx
        mov     esi, [ebp + AllocatedMem.LeaderBoardSz]; get cur sz
        test    ecx, esi
        jz      @F ; protection if 16 rcds exeeded
        ; realloc heap
        invoke  GetProcessHeap
        mov     edx, esi
        shl     edx, LB_ISTR_RCD_LEN_POW
        add     edx, sizeof.AllocatedMem - LB_BASE_RCDS_AMOUNT*(1 shl LB_ISTR_RCD_LEN_POW); sz wout dynamic array
        invoke  HeapReAlloc, eax, ebp, edx; new sz
        test    eax, eax
        jz      .EndProc ; if fails its just skips
        ; heap allocated successfully
        mov     [Settings.AllocatedMem], eax
        shl     [ebp + AllocatedMem.LeaderBoardSz], 1
        shl     esi, LB_ISTR_RCD_LEN_POW
@@:
        test    eax, eax
        jnz     .Loop_Find
.EndProc:
        ret
endp

