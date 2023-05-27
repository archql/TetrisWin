proc SocketIO.Init
        ; init packet headers
        jmp    Tcp.Init
endp

proc SocketIO.Connect
        ;
        stdcall SocketIO.PrepareHeaders
        ;
        stdcall Tcp.Connect
        ;
        ret
endp

proc SocketIO.TcpHandshakeDone

        ; send packet (launch websocket loop)
        ; - [in, esi] ptr to data block (from)
        mov     esi, Tcp.Websocket.Conn
        ; - [in, eax] len of data block
        mov     eax, Tcp.Websocket.Conn.Len
        jmp     Tcp.EnqueuePacket ; uses eax ecx edx esi edi ebx??
endp

proc SocketIO.On
        ; 1st - extract packet from the queue
        ; - [in, esi] ptr to managed buffer (to)
        mov     esi, Tcp.Buffer.recv
        stdcall Tcp.Buffer.Dequeue
        ; - [out, edi] ptr to data block
        ; - [out, eax] len of data block ; 0 if empty
        mov     esi, edi
        mov     ecx, eax
        ; 2nd - Check if previous dispatched event was binary
        movzx   edx, byte [SocketIO.NextEventId]
        test    edx, edx
        jz      .NotBinary
        dec     edx
        jz      .UnknownBinary
        ; drop event number
        mov     byte [SocketIO.NextEventId], 0
        ; event no 2
        dec     edx
        jz      Reconciliator.Sync
        ; event no 3
        dec     edx
        jz      Reconciliator.Update
        dec     edx
        jz      SocketIO.On.lb
        ; assume other are not possible

.NotBinary:
        ; 2nd - Check EngineIO part
        lodsb
        cmp     al, 'H' ; HTTP case - for now - just ignore
        je      .Exit
        cmp     al, '0' ; CONNECT message arrived
        jne     @F
        ; connect to namespace
        mov     esi, Tcp.Websocket.Join
        mov     eax, Tcp.Websocket.Join.Len
        cmp     byte [Tcp.Auth.Result], 0
        jne     .AuthOk
        mov     eax, Tcp.Websocket.Join.BaseLen
.AuthOk:
        xor     edx, edx ; TEXT type
        jmp     SocketIO.Emit ; uses eax ecx edx esi edi ebx??
@@:
        cmp     al, '2' ; PING message arrived - send PONG
        jne     @F
        ; send PONG
        mov     esi, Tcp.Websocket.Pong
        xor     eax, eax
        inc     eax
        xor     edx, edx ; TEXT type
        jmp     SocketIO.Emit ; uses eax ecx edx esi edi ebx??
@@:
        cmp     al, '4' ; EVENT message arrived - process it
        jne     .Exit   ; ignore other message types

        ; 3rd - Check SocketIO part
        ; were processing 5, other events were just ignoring
        lodsb
        cmp     al, '0'
        jne     @F
        ;
        inc     [SocketIO.EnteredNamespace]
        jmp     .Exit
@@:
        cmp     al, '5' ; Connected case
        jne     .Exit
        ; Binary event -
        ; get rid of namespace name & block info (assume its always ours)
        add     esi, 10 ;skip 1-/game,["
        ; extract event name (were interested in lb, sync, upd events [can be named 2, 3, 4 bytes long])
        mov     edx, 4      ; max event id
        ;
        mov     edi, esi ; ptr
        mov     eax, 'lbXX'  ; event with id 4
        scasd
        je      @F
        dec     edx
        ;
        mov     edi, esi ; ptr
        mov     eax, 'updX'; event with id 3
        scasd
        je      @F
        dec     edx
        ;
        mov     edi, esi ; ptr
        mov     eax, 'sncX'; event with id 2
        scasd
        je      @F
        dec     edx
@@:
.EndBinary:
.UnknownBinary:
        ; save dispatched event id
        mov     byte [SocketIO.NextEventId], dl
        ;
.Exit:
        ret
SocketIO.On.lb:

        ;lodsd
        ;mov     dword [Game.BlocksArr], eax
        ret
endp

proc SocketIO.Disconnect

        ; destroy tcp related things
        stdcall Tcp.Destroy

        ret
endp


;
; [out, eflags] - if je -> auth read credentials ok
; [out, eax] - if 0 -> auth read credentials ok
proc SocketIO.PrepareHeaders

        ; generate 22 random BASE64 symbols
        mov     edi, Tcp.Websocket.Conn.2
        mov     ecx, 22
.Base64Loop:
        mov     esi, Tcp.Base64Symbols
        ; get random offset
        stdcall Random.Get, 0, 63
        ; move on random ofset
        add     esi, eax
        ; mov char
        movsb   ; esi -> edi
        loop    .Base64Loop

        ; ## copy nickname
        mov     edi, Tcp.Websocket.Join.1
        mov     esi, Game.NickName
        mov     ecx, NICKNAME_LEN
        rep movsb

        ; Load password hash
        ; [in, stack] ptr to filename
        ; [in, stack] ptr to buf
        ; [in, stack] file sz to read
        ; [out, eax] amount of bytes read
        ; -1 if invalid handle
        mov     esi, 64
        stdcall Settings.ReadFile, Tcp.Websocket.Auth.File, Tcp.Websocket.Join.2, esi
        sub     eax, esi
        ; save auth res
        setz    al
        mov     byte [Tcp.Auth.Result], al
        ;je      .Ok
        ; TODO not ok auth
;.Ok:

        ret
endp

; Wrapper of Tcp.EnqueuePacket
; adds websocket related data to the packet
; - [in, dx] websocket packet type (ignore CONTINUE TYPE, so TEXT is 0, BINARY is 1)
; - [in, esi] ptr to data block (from)
; - [in, eax] len of data block
SocketIO.Emit:
        ; ignore CONTINUE TYPE
        inc     edx
        ; get temp buffer start
        mov     edi, SocketIO.BufferOut
        push    edi
        ;
        xchg    edx, eax ; save len
        ; determine websocket frame
        or      ax, 1000'0000_1000'0000b ; al is opcode, ah is length
        ; next determine length
        cmp     edx, 126
        jg      @F
        ; case A
        or      ah, dl
        stosw
        jmp     .end_case
@@:
        cmp     edx, 0xFFFF
        jg      @F
        ; case B
        or      ah, 126
        stosw
        mov     eax, edx
        xchg    ah, al
        stosw
        jmp     .end_case
@@:
        or      ah, 127
        stosw
        mov     eax, edx
        bswap   eax
        stosd
.end_case:
        ; len is in edx
        ; get mask (ecx edx is preserved)
        stdcall Random.GetMax
        ; now mask is in eax
        stosd
        mov     ecx, eax
        ; move payload
        xchg    ecx, edx
        ; loop (mask in edx, len in ecx)
.MaskingLoop:
        lodsb
        xor     al, dl
        ror     edx, 8
        stosb
        loop    .MaskingLoop

        pop     esi
        mov     eax, edi
        sub     eax, esi ; end block - start block
        jmp     Tcp.EnqueuePacket ; uses eax ecx edx esi edi ebx??