;========Game Settings==============
        ;Settings.strFilename      db    '_ARCHQL_.ttr', 0
        ;Settings.strTempFilename  db    '________'
        ;Settings.strTempLen       dw    0

        ;Settings.buffer           db    4 dup ?
        ;Settings.BytesProceed     dd    ?
        ;FILE_SZ_TO_READ           = 2
        IS_GITHUB_VERSION       = FALSE

; got score in eax, control in bx
proc Settings.DecodeWord ; ret score in eax, TRUE|FALSE in bx, uses cx

        ;mov     bx, word [Settings.buffer + 2]
        ;movzx   eax, word [Settings.buffer]
        ; decode control byte in buffer
        mov     cl, 0x45
        xor     cl, al
        rol     bx, cl
        xor     bx, 0x4CB3

        xor     bx, ax

        ret
endp

proc Settings.EncodeWord; got in ax (doestn change!), res in bx, uses cx

        ; encode control byte
        mov     bx, ax
        xor     bx, 0x4CB3
        mov     cl, 0x45
        xor     cl, al
        ror     bx, cl

        ret
endp

if (IS_GITHUB_VERSION)
        SPECIAL_CTR = 0
        proc Settings.CountControlSum
             ; Doing actually nothing here
             ret
        endp
else
        include 'super_secret_settings.asm'
end if

;#############READ FILE#########################
; params inorder
; [in, stack] ptr to filename
; [in, stack] ptr to buf
; [in, stack] file sz to read
; [out, eax] amount of bytes read
; -1 if invalid handle
proc Settings.ReadFile ; uses eax ecx edx ebx
        ; temp set pos!!!!!
        xor     ebx, ebx
        ; createfile
        invoke  CreateFileA, dword[esp + 4 + 6*4] , GENERIC_READ, FILE_SHARE_READ, ebx, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, ebx
        cmp     eax, INVALID_HANDLE_VALUE
        je      .Exit
        xchg    eax, ebx ; save handle in ebx (eax is zero)
        ; read high
        invoke  ReadFile, ebx, dword[esp + 8 + 3*4], dword[esp + 12 + 2*4], Settings.BytesProceed, eax
        ; close file
        invoke  CloseHandle, ebx
        ; ret
        mov     eax, [Settings.BytesProceed]
.Exit:
        ret 12
endp
;#############WRITE FILE########################
; [in, stack] ptr to filename
; [in, stack] ptr to buf
; [in, stack] file sz to write
; [out, eax] amount of bytes writen
; -1 if invalid handle
proc Settings.WriteFile ; uses eax ecx edx ebx
        ; temp set pos!!!!!
        xor     ebx, ebx
        ; createfile
        invoke  CreateFileA, dword [esp + 4 + 6*4], GENERIC_WRITE, FILE_SHARE_READ, ebx, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, ebx
        cmp     eax, INVALID_HANDLE_VALUE
        je      .Exit
        xchg    eax, ebx ; save handle in ebx (eax is zero)
        ; write high
        invoke  WriteFile, ebx, dword [esp + 8 + 3*4], dword [esp + 12 + 2*4], Settings.BytesProceed, eax ; [esp + 16] is num of bytes
        ; close file
        invoke  CloseHandle, ebx
        ; ret
        mov     eax, [Settings.BytesProceed]
.Exit:
        ret 12
endp
;#############GET LAST NICKNAME#################
; no params
proc Settings.GetLastNick
        ; set base values
        mov     esi, NICKNAME_LEN
        mov     edi, Game.NickName
        ; try to read
        stdcall Settings.ReadFile, Settings.File.Name, edi, esi
        cmp     eax, NICKNAME_LEN
        je      .EndProc ; eok
        ; failed -- use base nick
        mov     ecx, Str.BaseNickName
        xchg    esi, ecx
        rep     movsb
.EndProc:
        ret
endp
;#############SET LAST NICKNAME#################
; [in, stack] ptr to filename
; [in, stack] ptr to nick
; [in, stack] file sz to nicklen
proc Settings.SetLastNick  ; uses ebx esi
        pop     esi  ; save ret
        stdcall Settings.WriteFile
        push    esi
        ret
endp
;#############GET HIGH SCORE####################
; [in]  ptr to nickname str (eax)
; [out] high score in eax
proc Settings.GetHigh ; uses eax ebx ecx edx
        ; get player nickname filename
        cinvoke wsprintfA, Settings.strFilenameBuf, Settings.Format.File, eax
        ; read high
        stdcall Settings.ReadFile, Settings.strFilenameBuf, Settings.buffer, FILE_SZ_TO_READ
        ; check if smth readed
        cmp     eax, FILE_SZ_TO_READ
        jne     .EndProc ; failed
        ; decode high score
        mov     bx, word [Settings.buffer + 2]
        movzx   eax, word [Settings.buffer]
        stdcall Settings.DecodeWord
        test    bx, bx
        jnz     .EndProc
        ; set high
        ;mov     ax, word [Settings.buffer]
        jmp     @F ; skip reset score
.EndProc:
        xor     eax, eax
@@:
        ret
endp

;#############SET HIGH SCORE####################
; [in]  num of bytes to write (stack, [esp + 4], bc of ret ptr in stack!)
; [in]  ptr to nickname str (edx)
; [in]  high score in ax
; [out] high score in ax
proc Settings.SetHigh ; uses eax ebx ecx edx
        push    eax; save high score
        ; mov high to buffer
        mov     [GameBuffer.Score], ax
        stdcall Settings.EncodeWord
        mov     [GameBuffer.ControlWord], bx
        ; get player nickname filename
        cinvoke wsprintfA, Settings.strFilenameBuf, Settings.Format.File, edx
        ; count cur state control sum
        call    Settings.CountControlSum
        ; write high
        stdcall Settings.WriteFile, Settings.strFilenameBuf, GameBuffer, dword [esp + 8] ; [esp + 8] is num of bytes
        ; check res
        cmp     eax, dword [esp + 8]
        jne     .EndProc
        ; count control sum
        call    Settings.CountControlSum + SPECIAL_CTR
        ; client broadcast
        if (SERVER_DEFINED)
        cmp     [Client.State], CLIENT_STATE_OFFLINE
        je      @F
        mov     esi, Settings.strFilenameBuf
        mov     edi, Client.Broadcast
        stdcall Client.ListAllTTRFiles.SendFile
  @@:
        end if
.EndProc:
        pop     eax
        ret     4
endp

;#############LIST ALL FILES (and call PROC param)####################
; [in] PROC: requires pointer to proc as param in stack
; [in, optional] esi, edi as params for PROC
proc Settings.ListAllTTRFiles; uses eax ebx ecx edx

        invoke  FindFirstFile, Settings.strFileFilter, Settings.fileData
        xchg    eax, ebx; ebx is file lookup handle
        test    ebx, ebx
        jz      .EndProc
        mov     ecx, 0
.Loop_Find: ; (REQUIRED EBX)
        ; Save loop ctr
        push    ecx; loop ctr (As param to proc)
        ; Do action here
        stdcall dword [esp + 8] ; param in stack
        ; reset stack
        ; find next
        invoke  FindNextFile, ebx, Settings.fileData
        ; loop
        pop     ecx
        inc     ecx
        test    eax, eax; find next file result in eax
        jnz     .Loop_Find
.EndProc:
        ret     4
endp

; data to do it!
proc Settings.ListAllTTRFiles.LBline; write got str to rcd
        ; check if filename str == current nickname (if yes -- mark it somehow)
        ; parameters!
        mov     esi, Settings.fileData.cFileName; ptr to filename str
        mov     edi, ecx ; loop ctr
        shl     edi, LB_ISTR_RCD_LEN_POW ; get cur pos in rcds (dep on LB_ISTR_RCD_LEN)
        add     edi, Settings.LeaderBoardArr;Settings.LeaderBoardArr + 3
        push    edi  ; save pos of the start of rcd
        ; clear mem
        mov     ecx, 2 shl LB_ISTR_RCD_LEN_POW
        xor     eax, eax
        rep     stosb
        ; return to start
        mov     edi, [esp]
        add     edi, 3 ; 3 reserved symbols
        mov     ecx, LB_NAME_STR_LEN
        rep     movsb ; mov nick text
        ; read file (alt)
        push    ebx ; save handle
        mov     eax, Settings.fileData.cFileName
        stdcall Settings.GetHigh ; ret high in eax
        pop     ebx ; ld handle
        ;test    eax, eax     ; BEFORE -- IGNORED CORRYPTED DATA; NOW -- TRY TO ENCOUNT IT
        ;jz      .EndTryLdFile; corrypted (or zero)
        ; set high
        inc     edi
        push    eax ; save score as num
        ; write score
        cinvoke wsprintfA, edi, Str.Score.Format, eax
        ; save score and rcd nmb
        pop     eax
        mov     edi, [esp + 8]; get loop counter -- as param
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

        ret
endp

