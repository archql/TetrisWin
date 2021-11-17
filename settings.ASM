;========Game Settings==============
        Settings.strFilename      db    'settings.txt', 0
        Settings.fileHandle       dd    -1; INVALIF_FILE_HANDLE
        Settings.buffer           db    4 dup ?
        Settings.fileSize         dd    ?
        Settings.BytesProceed     dd    ?



;#############GET HIGH SCORE####################
; high score in ax
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