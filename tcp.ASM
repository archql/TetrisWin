INVALID_SOCKET              = 0xFF'FF'FF'FF
SOCKET_ERROR                = 0xFF'FF'FF'FF

IPPROTO_TCP                 = 6

SERVER_IP                   = 0x01'00'00'7F ; 127.0.0.1 in reversed order
SERVER_PORT                 = 5000

proc Tcp.Init

        ; init
        InitializeConditionVariable (&BufferNotEmpty);
        InitializeCriticalSection (&BufferLock);

        ; get main thread ID
        GetCurrentThreadId

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
        je      .Ok
        ; TODO not ok auth
.Ok:

        ret
endp

proc Tcp.Destroy

        ; destroy all
        WakeAllConditionVariable (&BufferNotFull);
        ; join threads
        and     word [Tcp.ThSend.Running], 0
        and     word [Tcp.ThSend.Running], 0
        ;
        WaitForSingleObject(hThread2, INFINITE)
        WaitForSingleObject(hThread2, INFINITE)
        ;
        invoke  DeleteCriticalSection, Client.CritSection

        ret
endp

proc Websockets.Connect

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp

proc Websockets.Disconnect

        ; destroy tcp related things
        stdcall Tcp.Destroy

        ret
endp

proc Websockets.Emit

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp

proc Websockets.Namespace

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp

proc Websockets.Auth

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp

; # connect to the tcp server
; - [out, eax] - is connection succeed
proc Tcp.Connect

        ; init WSA
        invoke  WSAStartup, 0x0202, Client.wsaData ; init winsock
        test    eax, eax
        jnz     .ErrorConnect

        ; params
        invoke  socket, AF_INET, SOCK_STREAM, IPPROTO_TCP  ;create socket;
        cmp     eax, INVALID_SOCKET
        je      .ErrorConnect

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

        ; set result
        mov     eax, TRUE
        jmp     .Exit

.ErrorConnect:
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
proc Tcp.Buffer.Enqueue uses ebx ; changes edi esi
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
        movzx     ecx, word [esi + (Tcp.Buffer.recv.start - Tcp.Buffer.recv)] ; start relative pos
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
        mov       word [edi + (Tcp.Buffer.recv.start - Tcp.Buffer.recv)], cx
        ; return in edi; preserve esi
        xchg      esi, edi
        ret
endp

; ### THERAD RECIEVER PROC
proc Tcp.ThRecv,\
        lpParameter ; PSOCKET

.LoopThread:
        mov     esi, Tcp.BufferIn
        ;
        invoke  recv, [lpParameter], esi, Tcp.BufferInSize, 0
        ;    TODO parse incoming data
        test    eax, eax
        js      .EndThread; if -1
        jz      .EndLoop
        ; if valid data arrived
        ; 1) lock queue ???
        ; 2) -> copy data into queue
        ; - [in, edi] ptr to managed buffer (to)
        mov     edi, Tcp.Buffer.recv
        ; - [in, esi] ptr to data block (from)
        ; - [in, eax] len of data block
        stdcall Tcp.Buffer.Enqueue ; IM the only one equeuing something here -> safe
        ; 3) notify ??
        invoke  PostThreadMessageA, [] ???, msgId??, eax, esi

        ; Check end condition
.EndLoop:
        cmp     word [Tcp.ThRecv.Running], 0
        jne     .LoopThread
        ;
.EndThread:
        mov     word [Tcp.ThRecv.Running], 0

        ret
endp


; ### THERAD SENDER PROC
proc Tcp.ThSend,\
        lpParameter ; PSOCKET

.LoopThread:
        ; Lock critical section
        EnterCriticalSection(&CritSection);
        ; wait until buffer is not null
        while (!Tcp.Buffer.HasData && Tcp.ThSend.Running)
              SleepConditionVariableCS(&ConditionVar, &CritSection, INFINITE);
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
        ; Unlock critical section
        LeaveCriticalSection(&CritSection);
        ; Check end condition
.EndLoop:
        cmp     word [Tcp.ThSend.Running], 0
        jne     .LoopThread
        ;
.EndThread:
        mov     word [Tcp.ThSend.Running], 0

        ret
endp

; Thread-safe way to enqueue TCP packet
; - [in, esi] ptr to data block (from)
; - [in, eax] len of data block
proc Tcp.EnqueuePacket
        ; Lock critical section
        EnterCriticalSection(&CritSection);
        ; emplace packet
        ; - [in, edi] ptr to managed buffer (to)
        mov     edi, Tcp.Buffer.send
        ; - [in, esi] ptr to data block (from)
        ; - [in, eax] len of data block
        stdcall Tcp.Buffer.Enqueue

        ; Unlock critical section
        LeaveCriticalSection(&CritSection);
        ; Wake the waiting sender
        WakeConditionVariable(&ConditionVar);

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




