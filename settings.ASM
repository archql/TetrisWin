;========Game Settings==============
        Settings.strFilename      db    '_ARCHQL_.ttr', 0
        Settings.strTempFilename  db    '________'
        Settings.tempLen          dw    0
        ;Settings.fileHandle       dd    -1; INVALID_FILE_HANDLE
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
Settings.fileData           WIN32_FIND_DATAA

LB_RCDS_AMOUNT              = 16
LB_NAME_STR_LEN             = 8

Settings.LeaderBoardArr:    times (LB_RCDS_AMOUNT) db (LB_NAME_STR_LEN) dup ' ', ':', (SCOLE_LEN_CONST) dup ' ', 0

;#############GET ALL RCD FILES####################
proc Settings.LdScoreboard
        invoke  FindFirstFile, Settings.strFileFilter, Settings.fileData
        xchg    eax, ebx; ebx is file lookup handle
        test    ebx, ebx
        jz      @F
        mov     ecx, 0
.Loop_Find:
        push    ecx; loop ctr
        ; write got str
        mov     esi, Settings.fileData.cFileName; ptr to filename str
        mov     edi, ecx
        shl     edi, 4                          ; get cur pos in rcds
        add     edi, Settings.LeaderBoardArr
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
        je      .EndTryLdFile
        ; set high
        inc     edi
        movzx   eax, word [Settings.buffer]
        cinvoke wsprintfA, edi, Str.Score.Format, eax

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
        test    eax, eax
        jnz     .Loop_Find
@@:

        ret
endp

