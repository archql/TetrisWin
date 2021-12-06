;========Game Settings==============
        Settings.strFilename      db    'settings.txt', 0
        Settings.tempLen          dw    0
        Settings.fileHandle       dd    -1; INVALID_FILE_HANDLE
        Settings.buffer           db    4 dup ?
        Settings.BytesProceed     dd    ?



;#############GET HIGH SCORE####################
; ret high score in ax
proc Settings.GetHigh

        ; check if created handle still valid
        cmp     [Settings.fileHandle], INVALID_HANDLE_VALUE
        jne     @F
        ; createfile
        invoke  CreateFileA, Settings.strFilename, GENERIC_WRITE + GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
        cmp     eax, INVALID_HANDLE_VALUE
        je      .EndProc
        mov     [Settings.fileHandle], eax ; save file handler
@@:
        ; temp set pos!!!!!
        invoke  SetFilePointer, [Settings.fileHandle] , 0, 0, FILE_BEGIN
        ; get sz
        invoke GetFileSize, [Settings.fileHandle], 0;
        inc eax
        ; read high
        invoke  ReadFile, [Settings.fileHandle], Settings.buffer, eax, Settings.BytesProceed, 0 ; [nSize]

        cmp     [Settings.BytesProceed], 0
        je      .EndProc
        ; !!!!
        ;invoke CloseHandle, [Settings.fileHandle]
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
; high score in ax
proc Settings.SetHigh
        ; convert num to str
        ;cinvoke wsprintfA, Settings.buffer, buf_format, eax
        ; mov high to buffer
        mov     word [Settings.buffer], ax
        ; temp set pos!!!!!
        invoke  SetFilePointer, [Settings.fileHandle] , 0, 0, FILE_BEGIN
        ; write high
        invoke  WriteFile, [Settings.fileHandle], Settings.buffer, 2, Settings.BytesProceed, 0 ; [nSize]
        ;invoke  GetLastError
        ;xor     ax, ax
        ; !!!!
        jmp     @F ; skip reset score   
.EndProc:
        xor     ax, ax
@@:
        ret
endp

; addl data to ld scoreboard
Settings.strFileFilter      db    '*.txt', 0
Settings.fileData           WIN32_FIND_DATAA

LB_RCDS_AMOUNT              = 5
LB_NAME_STR_LEN             = 8

Settings.LeaderBoardArr:    times (LB_RCDS_AMOUNT) db (LB_NAME_STR_LEN) dup ' ', ':', (SCOLE_LEN_CONST) dup ' ', 0

;#############GET ALL RCD FILES####################
proc Settings.LdScoreboard
        invoke  FindFirstFile, Settings.strFileFilter, Settings.fileData
        xchg    eax, ebx
        test    ebx, ebx
        jz      @F
        mov     ecx, 0
.Loop_Find:
        push    ecx
        ; write got str
        mov     esi, Settings.fileData.cFileName
        mov     edi, ecx
        shl     edi, 4
        add     edi, Settings.LeaderBoardArr
        mov     ecx, LB_NAME_STR_LEN
        rep     movsb
        ; get score
        push    eax ; save file handler
        ; read file
        ;mov     [Settings.fileHandle], -1; INVALID_FILE_HANDLE
        ;stdcall Settings.GetHigh         ; It ll kill all file logics!!!

        ; reset stack
        pop     eax
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

