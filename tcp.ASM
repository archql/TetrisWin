INVALID_SOCKET              = 0xFF'FF'FF'FF
SOCKET_ERROR                = 0xFF'FF'FF'FF
INFINITE                    = 0xFF'FF'FF'FF ; Infinite timeout

IPPROTO_TCP                 = 6

SERVER_IP                   = 0x01'00'00'7F ; 127.0.0.1 in reversed order
SERVER_PORT                 = 5000

; Message code which is used to notify main thread about new tcp packet
WM_PACKET_ARRIVED           = WM_USER + 0x222

; U must set Tcp.DecodePacket ->
;Tcp.DecodePacket            = ....
; Calling convention
; [in, esi] - pos to buffer
; [in, eax] - allowed len of buffer
; [out, eax] - new allowed len of buffer (= old if no packet)
; [out, esi] - packet pos (= start if no packet)
; [out, edx] - extracted packet len
; [out, ecx] - extracted full len  (unimportant)
; [out, eflags] - does je if no packet left
proc Tcp.DecodePacket ; uses edi ecx
        ; save start pos
        mov     edi, esi
        ; save len
        xchg    eax, edx
        ; check if has at least 2 bytes
        cmp     edx, 2
        jl      .NoMorePackets ; diff is < 0
        ;
        lodsb
        ; now al is opcode (ignore)
        lodsb
        ; now al is len (with mask bit, but assume it is 0)
        cmp     al, 126
        jl      .case_A
        je      .case_B
.case_C:
        lodsd
        bswap
        jmp     .case_A
.case_B:
        lodsw
        xchg    ah, al
.case_A:
        ; now eax stores length of packet (of course if it is valid)
        mov     ecx, esi
        sub     ecx, edi
        cmp     ecx, edx ; edx is allowed len
        js      .NoMorePackets ; diff is < 0
        ; were assuming that masking key is not present
        ; => ensure payload is here
        add     ecx, eax ; length is valid - so check it
        cmp     ecx, edx ; edx is allowed len
        jns     .Exit

        ;
 .NoMorePackets:
        ; rollback (now eax is undefined, edx is allowed len, )
        mov     esi, edi
        xor     eax, eax
        xor     ecx, ecx
.Exit:
        ;
        xchg    edx, eax ; was eax is xtracted len, edx is allowed len
        ; ecx stores full length of xtracted
        sub     eax, ecx  ; calc amount of left bytes
        ;
        test    ecx, ecx
        ret
endp

; Interface
; - Tcp.Init    (MUST be called from window thread)
; - Tcp.Destroy (MUST be called from window thread)
; - Tcp.Connect (Start connection and threads)
;       [out, eax] - if success
; - Tcp.EnqueuePacket
;       [in, esi] ptr to data block
;       [in, eax] len of data block

; # Initializes all TCP module related resources
; [out, eflags] - if je -> auth read credentials ok
proc Tcp.Init

        ; init
        stdcall InitializeConditionVariable, Tcp.CondVar
        stdcall InitializeCriticalSection, Tcp.CritSection

        ; get main thread ID
        stdcall GetCurrentThreadId
        mov     eax, [Tcp.thMain.pThId]

        ; generate 22 random BASE64 symbols
        mov     esi, Tcp.Websocket.Conn.2
        mov     edi, Tcp.Base64Symbols
        mov     ecx, 22
.Base64Loop:
        push    esi
        ; get random offset
        stdcall Random.Get, 0, 63
        ; move on random ofset
        add     esi, eax
        ; mov char
        movsb
        ; restore base offset
        pop     esi
        loop    .Base64Loop

        ; ## copy nickname
        mov     esi, Tcp.Websocket.Auth.1
        mov     edi, Game.NickName
        mov     ecx, NICKNAME_LEN
        rep movsb

        ; Load password hash
        ; [in, stack] ptr to filename
        ; [in, stack] ptr to buf
        ; [in, stack] file sz to read
        ; [out, eax] amount of bytes read
        ; -1 if invalid handle
        mov     esi, 64
        stdcall Settings.ReadFile, Tcp.Websocket.Auth.File, Tcp.Websocket.Auth.2, esi
        cmp     eax, esi
        ;je      .Ok
        ; TODO not ok auth
;.Ok:

        ret
endp

; # Destroys all TCP module related resources
proc Tcp.Destroy

        ; destroy all
        stdcall WakeAllConditionVariable, Tcp.CondVar
        ; join threads
        inc     word [Tcp.ThSend.thStop]
        inc     word [Tcp.ThSend.Running]
        ;
        stdcall WaitForSingleObject, [Tcp.ThSend.hThread], INFINITE
        stdcall WaitForSingleObject, [Tcp.ThRecv.hThread], INFINITE
        ;
        invoke  DeleteCriticalSection, Client.CritSection

        ret
endp

; # connect to the tcp server
; - [out, eax] - is connection succeed
proc Tcp.Connect

        ; init WSA
        invoke  WSAStartup, 0x0202, Client.wsaData ; init winsock
        test    eax, eax
        jnz     .ErrorStart

        ; params
        invoke  socket, AF_INET, SOCK_STREAM, IPPROTO_TCP  ;create socket;
        cmp     eax, INVALID_SOCKET
        je      .ErrorStart

        ; Socket opened!
        mov     [Tcp.hsocket], eax ;save socket handle in ebx
        xchg    eax, ebx ; save handle in ebx
        ; Setup sockaddr_in's
        ; set port
        mov     ax, SERVER_PORT
        xchg    ah, al
        ; #Recv_addr
        ; memset zero (dont need, already zero!)
        mov     [Tcp.Addr.sin_family], AF_INET
        mov     [Tcp.Addr.sin_port], ax
        mov     [Tcp.Addr.sin_addr], SERVER_IP ; already zero!
        ; Open tcp connection
        invoke  connect, ebx, Tcp.Addr, sizeof.sockaddr_in
        cmp     eax, SOCKET_ERROR
        je      .ErrorConnect
        ; If connections are opened -> launch threads
        ; start || thread (Recv)
        xor     eax, eax
        invoke  CreateThread, eax, eax, Tcp.ThRecv.Callback, ebx, eax, Tcp.ThRecv.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect
        mov     [Tcp.ThRecv.thStop], 0

        ; start || thread (Send)
        xor     eax, eax
        invoke  CreateThread, eax, eax, Tcp.ThSend.Callback, ebx, eax, Tcp.ThSend.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect
        mov     [Tcp.ThSend.thStop], 0

        ; set result
        mov     eax, TRUE
        jmp     .Exit

.ErrorConnect:
        ; invalidate socket
        mov     dword [Tcp.hsocket], INVALID_SOCKET
        invoke  closesocket, ebx
        invoke  WSACleanup
        ;
.ErrorStart:
        ; set result
        xor     eax, eax
.Exit:
        ;mov     [Tcp.State], ax
        ret
endp

; # Writes data from block with addr esi and sz eax to managed buffer (start of which is edi)
; THREAD UNSAFE
; (but Enqueue <-> Dequeue are both safe)
; - [in, edi] ptr to managed buffer (to)
; - [in, esi] ptr to data block (from)
; - [in, eax] len of data block
; - [out, esi] initial esi + eax
proc Tcp.Buffer.Enqueue uses ebx ; changes edi esi eax ecx edx
        ; save initial len
        push      eax
        inc       eax  ; add length dw size
        inc       eax
        ; get end pos
        movzx     ecx, word [edi + (Tcp.Buffer.recv.end - Tcp.Buffer.recv)] ; end relative pos
        ; get new end pos
        mov       edx, ecx
        add       edx, eax
        ; check on overflow
        cmp       edx, TCP_BUFFER_SIZE
        jle       .no_overflow
        ; mark overflow
        mov       word [edi + ecx], 0 ; 0 is overflow mark
        ; overflow
        xor       ecx, ecx
        mov       edx, eax
.no_overflow:
        ; store pos where to store new buffer end
        lea       ebx, [edi + (Tcp.Buffer.recv.end - Tcp.Buffer.recv)]
        ;mov       word [edi + (Tcp.Buffer.recv.end - Tcp.Buffer.recv)], dx
        ; get first symbol pos of new allocated block
        add       edi, ecx
        ; write block len
        pop       eax
        stosw     ;  -> edi
        ; write block
        mov       ecx, eax ; set length
        rep movsb ; esi -> edi
        ; set new buffer end (IN THE END - multithreading)
        mov       word [ebx], dx
        ;
        ret
endp

; # Receives data from block by setting addr esi and sz eax from managed buffer (start of which is edi)
; note that block is not copied from buffer, but it is marked as free
; THREAD UNSAFE
; - [in, esi] ptr to managed buffer (to)
; - [out, eflags] flags are set corresponding to start == end comparison
proc Tcp.Buffer.HasData   ; uses ecx
        ; get start pos
        movzx     ecx, word [esi + (Tcp.Buffer.recv.begin - Tcp.Buffer.recv)] ; begin relative pos
        cmp       cx, word [esi + (Tcp.Buffer.recv.end - Tcp.Buffer.recv)] ; end relative pos
        ret
endp

; # Receives data from block by setting addr esi and sz eax from managed buffer (start of which is edi)
; note that block is not copied from buffer, but it is marked as free
; THREAD UNSAFE
; - [in, esi] ptr to managed buffer (to)
; - [out, edi] ptr to data block
; - [out, eax] len of data block ; 0 if empty
proc Tcp.Buffer.Dequeue
        ; get start pos
        push      esi
        ;movzx     ecx, word [esi + (Tcp.Buffer.recv.start - Tcp.Buffer.recv)] ; start relative pos
        ;cmp       cx, word [esi + (Tcp.Buffer.recv.end - Tcp.Buffer.recv)] ; end relative pos
        stdcall   Tcp.Buffer.HasData
        je        .exit ; if start = end
        ; get data ptr
        add       esi, ecx
        ; xtract length
        lodsw     ; esi ->
        ; check if overflow
        test      eax, eax
        jnz       .return
        ; empty buffer ?
        ;test      ecx, ecx
        ;jz        .exit
        ; it is overflow case
        xor       ecx, ecx ; set start to 0
        mov       esi, dword [esp] ; reset buf pos
        ; xtract length. again.
        lodsw     ; esi ->
        ; assume that length is normal (because
.return:
        ; set new start
        add       ecx, eax
        inc       ecx
        inc       ecx
        ;
.exit:
        pop       edi
        mov       word [edi + (Tcp.Buffer.recv.begin - Tcp.Buffer.recv)], cx
        ; return in edi; preserve esi
        xchg      esi, edi
        ret
endp

; ### THERAD RECIEVER PROC
proc Tcp.ThRecv.Callback,\
        lpParameter ; PSOCKET

        xor     eax, eax
        mov     esi, Tcp.BufferIn

.LoopThread:
        ;  count new buf sz
        mov     edx, Tcp.BufferIn.Size
        sub     edx, eax
        ;
        mov     edi, eax ; save old pos
        invoke  recv, [lpParameter], esi, edx, 0
        xchg    edi, eax
        add     eax, edi ; get new buf len
        test    edi, edi ; if read corresponds to socket error
        js      .EndThread; if -1
        jz      .EndLoop
.CheckForNextPacket:
        ; Lets Parse data
        ; [in, esi] - pos to buffer
        ; [in, eax] - allowed len of buffer
        ; [out, eax] - new allowed len of buffer (= old if no packet)
        ; [out, esi] - packet pos (= start if no packet)
        ; [out, edx] - extracted packet len
        ; [out, ecx] - extracted full len  (unimportant)
        ; [out, eflags] - does je if no packet left
        stdcall Tcp.DecodePacket ; uses ecx edi
        je      .AllPacketsParsed
        ; check if zero packet -> IGNORE IT
        test    edx, edx
        jz      .CheckForNextPacket
        ; save results
        push    eax ; new allowed len ??

        ; if valid data arrived
        ; 1) lock queue ???
        ; 2) -> copy data into queue
        ; - [in, edi] ptr to managed buffer (to)
        mov     edi, Tcp.Buffer.recv
        ; - [in, esi] ptr to data block (from)
        ; - [in, eax] len of data block
        xchg    edx, eax
        ; changes edi esi eax ecx edx (return esi = esi + eax)
        stdcall Tcp.Buffer.Enqueue ; IM the only one equeuing something here -> safe
        ; 3) notify ??
        invoke  PostThreadMessageA, [Tcp.ThMain.pThId], WM_PACKET_ARRIVED, eax, esi
        ; now esi is new buffer pos & eax is allowed len (on stack)
        pop     eax
        ;
        jmp     .CheckForNextPacket
        ;
.AllPacketsParsed:
        ; Check if still has data
        test    eax, eax
        jz      .EndLoop
        ; Mov data back
        mov     edi, Tcp.BufferIn
        push    edi
        mov     ecx, eax
        rep movsb; esi -> edi
        pop     esi
        ; Check end condition
.EndLoop:
        cmp     word [Tcp.ThRecv.thStop], 0
        je      .LoopThread
        ;
.EndThread:
        inc     word [Tcp.ThRecv.thStop]

        ret
endp


; ### THERAD SENDER PROC
proc Tcp.ThSend.Callback,\
        lpParameter ; PSOCKET

.LoopThread:
        ; Lock critical section
        stdcall EnterCriticalSection, Tcp.CritSection
        ; wait until buffer is not null
        stdcall Tcp.Buffer.HasData
        jne     @F ; has data
        cmp     word [Tcp.ThSend.thStop], 0
        jne     .EndThread ; exit requested
        stdcall SleepConditionVariableCS, Tcp.CondVar, Tcp.CritSection, INFINITE
        ;
@@:
        ; Fetch message
        ; - [in, esi] ptr to managed buffer (to)
        mov     esi, Tcp.Buffer.send
        ; - [out, edi] ptr to data block
        ; - [out, eax] len of data block ; 0 if empty
        stdcall Tcp.Buffer.Dequeue
        ; save full length
        mov     ebx, eax
.RepeatSend:
        ; send packet over tcp
        invoke  send, [lpParameter], edi, ebx, 0
        ;
        test    eax, eax
        js      .EndThread; if -1
        ;
        add     edi, eax
        sub     ebx, eax
        jnz     .RepeatSend ; (if not fully sended)
        ; Check end condition
.EndLoop:
        cmp     word [Tcp.ThSend.thStop], 0
        je      .LoopThread
        ;
.EndThread:
        ; Unlock critical section
        stdcall LeaveCriticalSection, Tcp.CritSection
        ; Set flag to false (if manual exit)
        inc     word [Tcp.ThSend.thStop]
        ;

        ret
endp

; Thread-safe way to enqueue TCP packet
; - [in, esi] ptr to data block (from)
; - [in, eax] len of data block
proc Tcp.EnqueuePacket ; uses eax ecx edx esi edi ebx??
        ; save eax
        push    eax
        ; Lock critical section
        stdcall EnterCriticalSection, Tcp.CritSection
        ; emplace packet
        ; - [in, edi] ptr to managed buffer (to)
        mov     edi, Tcp.Buffer.send
        ; - [in, esi] ptr to data block (from)
        ; - [in, eax] len of data block
        pop     eax
        stdcall Tcp.Buffer.Enqueue

        ; Unlock critical section
        stdcall LeaveCriticalSection, Tcp.CritSection
        ; Wake the waiting sender
        stdcall WakeConditionVariable, Tcp.CondVar

        ret
endp






; #
; - []
proc Tcp.Recv
        invoke  recv, [Tcp.hsocket], buffer, sizeof(buffer), 0
        ;test    eax, eax
        ;j

        ret
endp




