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

LB_RCDS_AMOUNT              = 16
LB_NAME_STR_LEN             = 8


Settings.AllocatedMem       dd  ?
Settings.LeaderBoardArr:    times (LB_RCDS_AMOUNT) db '#', ' ',' ',(LB_NAME_STR_LEN) dup ' ', (SCOLE_LEN_CONST) dup ' ', '15 EMPTYBYTES**'
         LB_ISTR_RCD_LEN      = 17
         LB_ISTR_RCD_LEN_POW  = 5; Real mem sz allocated 2^LB_RCDS_AMOUNT
Settings.LeaderBoardPrio:   times (LB_RCDS_AMOUNT) dw 0, 0 ; place, score
         LB_INFO_RCD_LEN      = 4
         
struct AllocatedMem
        ;blocksArr1:          db     FIELD_W*FIELD_H dup ?
        ;glowArr:            db     FIELD_H dup ?
        leaderBoardSz       dd     ?
        leaderBoardArr      db     400000*(2 shl LB_ISTR_RCD_LEN_POW) dup ? ; 4 is base sz
ends        

;#############GET ALL RCD FILES####################
proc Settings.LdScoreboard
        invoke  FindFirstFile, Settings.strFileFilter, Settings.fileData
        xchg    eax, ebx; ebx is file lookup handle
        test    ebx, ebx
        jz      @F
        mov     ecx, 0
.Loop_Find:     ; WARN!!!!! LENGTH OF SCOREBOARD IS LIMITED AND ITS UNCONTROLLED!!!!
        push    ecx; loop ctr
        ; write got str to rcd
        mov     esi, Settings.fileData.cFileName; ptr to filename str
        mov     edi, ecx
        shl     edi, LB_ISTR_RCD_LEN_POW ; get cur pos in rcds (dep on LB_ISTR_RCD_LEN)
        add     edi, Settings.LeaderBoardArr + 3; 3 reserved sumbols
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
        pop     eax
        invoke  CloseHandle, eax
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
        mov     esi, [esp + LB_INFO_RCD_LEN]; get rcd place
        mov     edi, esi ; save it
        shl     esi, LB_INFO_RCD_LEN / 2
        add     esi, Settings.LeaderBoardPrio
        mov     [esi], ax
        mov     [esi + LB_INFO_RCD_LEN / 2], di ;??
        ; sort loop
        mov     edi, esi ; same value ptr to cur rcd
.SortLoop:
        sub     esi, LB_INFO_RCD_LEN; go back
        cmp     esi, Settings.LeaderBoardPrio
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
@@:
        ; write cur
        ; invoke  MessageBox, 0, Settings.LeaderBoardArr, Caption, MB_OK or MB_ICONERROR;
        ; find next
        invoke  FindNextFile, ebx, Settings.fileData
        ; loop
        pop     ecx
        inc     ecx
        test    ecx, LB_RCDS_AMOUNT
        jnz     .EndProc ; protection if 16 rcds exeeded
        test    eax, eax
        jnz     .Loop_Find
@@:
.EndProc:
        ret
endp

