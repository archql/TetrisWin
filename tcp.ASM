INVALID_SOCKET              = 0xFF'FF'FF'FF
SOCKET_ERROR                = 0xFF'FF'FF'FF
INFINITE                    = 0xFF'FF'FF'FF ; Infinite timeout
SOL_SOCKET                  = 0xFFFF
SO_RCVTIMEO                 = 0x1006
WSAETIMEDOUT                = 10060

IPPROTO_TCP                 = 6

SERVER_IP                   = 0x01'00'00'7F ; 127.0.0.1 in reversed order
SERVER_PORT                 = 80 ; 5555 ; 0x153B

; Message codes which are used to notify main thread about new tcp packet
WM_APP                      = 0x8000
WM_TCP_CONNECTED            = WM_APP + 1
WM_TCP_PACKET_ARRIVED       = WM_APP + 2

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
        mov     ebx, esi
        ; CHECK ON HTTP header
        mov     ecx, Tcp.Websocket.Conn.HTTP.Len
        mov     edi, Tcp.Websocket.Conn.HTTP
        repe cmpsb
        jz      .HTTP
        ; save len
        xchg    eax, edx
        ; check if has at least 2 bytes
        cmp     edx, 2
        jl      .NoMorePackets ; diff is < 0
        ;
        mov     esi, ebx ; restore esi
        xor     eax, eax ; clear eax
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
        bswap   eax
        jmp     .case_A
.case_B:
        lodsw
        xchg    ah, al
.case_A:
        ; now eax stores length of packet (of course if it is valid)
        mov     ecx, esi
        sub     ecx, ebx
        cmp     ecx, edx ; edx is allowed len
        jg      .NoMorePackets ; diff is < 0
        ; were assuming that masking key is not present
        ; => ensure payload is here
        add     ecx, eax ; length is valid - so check it
        cmp     ecx, edx ; edx is allowed len
        jle     .Exit

        ;
 .NoMorePackets:
        ; rollback (now eax is undefined, edx is allowed len, )
        mov     esi, ebx
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
.HTTP:
        ; FIND place with \r\n\r\n !!!! (end) (assume there is no content)
@@:
        ; check if end of buffer reached
        mov     edx, esi
        sub     edx, ebx
        cmp     edx, eax
        jg      .NoMoreData
        ; find sequence
        mov     ecx, Tcp.Websocket.Conn.End.Len
        mov     edi, Tcp.Websocket.Conn.End
        repe cmpsb
        jnz     @B
        ; check if end of buffer reached (DUPLICATED)
        mov     edx, esi
        sub     edx, ebx
        cmp     edx, eax
        jle     .HttpReady;.NoMoreData
        ; here were are if payload were founded, esi is place where it is
        ;jmp     .HttpReady

.NoMoreData:
        xor     edx, edx ; full extracted len = 0
        ;
.HttpReady:
        ; copy full http packet
        mov     esi, ebx
        ; amount of bytes in the buffer
        sub     eax, edx  ; calc amount of left bytes
        ;
        test    edx, edx
        ret
endp

; Interface
; - Tcp.Init    (MUST be called from main thread, ONCE)
; - Tcp.Destroy (MUST be called from main thread, ONCE)
; - Tcp.Connect (Start connection and threads, MUST be called from main thread)
;       [out, eax] - if success
; - Tcp.EnqueuePacket (Can be called from any thread)
;       [in, esi] ptr to data block
;       [in, eax] len of data block

; # Initializes all TCP module related resources
; # opens a socket
; [out, eax] - is connection suceeded (true/false)
proc Tcp.Init

        ; init
        invoke  InitializeConditionVariable, Tcp.CondVar
        invoke  InitializeCriticalSection, Tcp.CritSection
        ; init WSA
        invoke  WSAStartup, 0x0202, Client.wsaData ; init winsock
        test    eax, eax
        jnz     .ErrorStart

        ; save main thread ID
        invoke  GetCurrentThreadId
        mov     [Tcp.ThMain.pThId], eax

        ; params
        invoke  socket, AF_INET, SOCK_STREAM, IPPROTO_TCP  ;create socket;
        xor     ecx, ecx ; get invalid socket value
        not     ecx
        cmp     eax, ecx
        mov     [Tcp.hsocket], eax ;save socket handle
        je      .ErrorStart

        ; Setup sockaddr_in's
        ; set port
        mov     ax, SERVER_PORT
        xchg    ah, al
        ; #Recv_addr
        ; memset zero (dont need, already zero!)
        mov     [Tcp.Addr.sin_family], AF_INET
        mov     [Tcp.Addr.sin_port], ax
        mov     [Tcp.Addr.sin_addr], SERVER_IP
        ; other fields are already zero!

        ; set result
        xor     eax, eax
        inc     eax
        jmp     .Exit

.ErrorConnect:
        ; invalidate socket
        ;xor     eax, eax
        ;neg     eax ; get invalid socket
        ;mov     dword [Tcp.hsocket], eax ; TODO ERROR???
        invoke  closesocket, ebx
        invoke  WSACleanup
        ;
.ErrorStart:
        ; set state (TODO IT IS NOT TCP RELATED FEATURE)
        mov     word [Reconciliator.State], RECONCILIATOR_STATE_INITERROR
        ; set result
        xor     eax, eax
.Exit:
        ret
endp

; # Destroys all TCP module related resources
proc Tcp.Destroy
        ; kill socket (WARNING DANGER TODO)
        ; invalidate socket
        mov     eax, [Tcp.hsocket]
        ;test    ebx, ebx  (ignore invalid sockets)
        ;jz      @F
        invoke  closesocket, eax
        invoke  WSACleanup
;@@:
        ; join threads
        inc     word [Tcp.ThSend.thStop]
        inc     word [Tcp.ThSend.thStop]
        ; destroy all
        invoke  WakeAllConditionVariable, Tcp.CondVar
        ;
        mov     eax, [Tcp.ThSend.hThread]
        test    eax, eax
        jz      @F
        invoke  WaitForSingleObject, eax, INFINITE
@@:
        mov     eax, [Tcp.ThRecv.hThread]
        test    eax, eax
        jz      @F
        invoke  WaitForSingleObject, eax, INFINITE
@@:
        ;
        invoke  DeleteCriticalSection, Tcp.CritSection

        ret
endp

; # connect to the tcp server
; must be called once
; - [out, eax] - is connection succeed
proc Tcp.Connect
        ;
        cmp     [Tcp.Connected], 0
        jne     .Exit
        ; set state (TODO IT IS NOT TCP RELATED FEATURE)
        mov     word [Reconciliator.State], RECONCILIATOR_STATE_CONNECTING
        ;
        mov     ebx, [Tcp.hsocket]
        ; Check if socket opened
        xor     ecx, ecx
        not     ecx ; set to invalid socket
        cmp     ebx, ecx
        je      .ErrorStart
        ; start || thread (Recv)
        xor     eax, eax
        mov     esi, Tcp.ThSend
        mov     edi, Tcp.ThSend.Callback
        stdcall Tcp.CreateThread
        jz      .ErrorStart
        ; start || thread (Send)
        xor     eax, eax
        mov     esi, Tcp.ThRecv
        mov     edi, Tcp.ThRecv.Callback
        stdcall Tcp.CreateThread
        setz    al ; we know that eax is tested on zero - so set it to 1
        movzx   eax, al
        jnz     .Exit ; exit on sucess
        ;
.ErrorStart:
        ; set state (TODO)
        mov     word [Reconciliator.State], RECONCILIATOR_STATE_INITERROR
        ; set result
        xor     eax, eax
.Exit:
        ret
endp

; [in, eax] - 0
; [in, esi] - ptr to thread struct
; [in, edi] - ptr to callback
; [out, eflags] - ZF = 0 if error
proc Tcp.CreateThread ; uses edi
        ; get th handle
        mov     ecx, [esi + THREAD_INFO.hThread]
        test    ecx, ecx
        jz      @F ; thread has been never initialized
        ; check if thread is running
        cmp     dword [esi + THREAD_INFO.thStop], 0
        je      .Exit
        ; check if thread is dead
        xor     eax, eax
        invoke  WaitForSingleObject, ecx, eax
        jnz     .Exit ; thread is alive
@@:
        ; Launch thread
        xor     eax, eax
        invoke  CreateThread, eax, eax, edi, ebx, eax, esi; last is ptr to thread id (omitted)
        test    eax, eax
        jz      .Exit
        mov     [esi + THREAD_INFO.thStop], 0
        mov     [esi + THREAD_INFO.hThread], eax
.Exit:
        ret
endp

; ### THERAD RECIEVER PROC
proc Tcp.ThRecv.Callback,\
        lpParameter ; PSOCKET

        ; Open tcp connection first (USES Tcp.Addr - so it must be readonly)
        invoke  connect, [lpParameter], Tcp.Addr, sizeof.sockaddr_in
        cmp     eax, SOCKET_ERROR
        je      .EndThread
        ; Set state that were ready to send data
        lock    inc [Tcp.Connected]
        ; TEMP
        mov     word [Reconciliator.State], RECONCILIATOR_STATE_ONLINE
        ; Notify send thread
        invoke  WakeConditionVariable, Tcp.CondVar
        ; Notify main thread that init were done successfully (TODO what about unsuccess?)
        invoke  PostThreadMessageA, [Tcp.ThMain.pThId], WM_TCP_CONNECTED, eax, eax
        ;
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
        jng     .EndThread
        ; back
        xchg    edi, eax
        ; back to start pos to decode packets from the start
        mov     esi, Tcp.BufferIn
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
        ; changes edi esi ecx edx (return esi = esi + eax)
        stdcall Tcp.Buffer.Enqueue ; IM the only one equeuing something here -> safe
        ; 3) notify ??
        invoke  PostThreadMessageA, [Tcp.ThMain.pThId], WM_TCP_PACKET_ARRIVED, eax, esi
        ; now esi is new buffer pos & eax is allowed len (on stack)
        pop     eax
        ;
        jmp     .CheckForNextPacket
.AllPacketsParsed:
        ; save esi pos
        mov     edi, esi
        ; return esi to start pos
        mov     esi, Tcp.BufferIn
        ; Check if still has data
        test    eax, eax
        jz      .EndLoop
        ; Mov data back
        xchg    esi, edi ; now edi is start pos, esi is data pos
        push    esi
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
        mov     [Tcp.Connected], 0
        ; set state (TODO it is not tcp related)
        mov     word [Reconciliator.State], RECONCILIATOR_STATE_CONLOST

        ret
endp


; ### THERAD SENDER PROC
proc Tcp.ThSend.Callback,\
        lpParameter ; PSOCKET

        ; Lock critical section
        invoke  EnterCriticalSection, Tcp.CritSection

.LoopThread:
        cmp     word [Tcp.ThSend.thStop], 0
        jne     .EndThread ; exit requested
        ; wait until buffer is not null
        ; - [in, esi] ptr to managed buffer (to)
        mov     esi, Tcp.Buffer.send
        stdcall Tcp.Buffer.HasData
        jne     @F ; has data
        invoke  SleepConditionVariableCS, Tcp.CondVar, Tcp.CritSection, INFINITE
        jmp     .LoopThread ; extract data
@@:
        ; Fetch message
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
        invoke  LeaveCriticalSection, Tcp.CritSection
        ; Set flag to false (if manual exit)
        inc     word [Tcp.ThSend.thStop]
        mov     [Tcp.Connected], 0
        ; set state (TODO)
        mov     word [Reconciliator.State], RECONCILIATOR_STATE_CONLOST

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

; Thread-safe way to enqueue TCP packet
; drops the packet if TCP module is not ready to send
; - [in, esi] ptr to data block (from)
; - [in, eax] len of data block
proc Tcp.EnqueuePacket ; uses eax ecx edx esi edi
        ; check if connected and ready to send
        cmp     [Tcp.Connected], 0
        je      .Exit
        ; save eax
        push    eax
        ; Lock critical section
        invoke  EnterCriticalSection, Tcp.CritSection
        ; emplace packet
        ; - [in, edi] ptr to managed buffer (to)
        mov     edi, Tcp.Buffer.send
        ; - [in, esi] ptr to data block (from)
        ; - [in, eax] len of data block
        pop     eax
        stdcall Tcp.Buffer.Enqueue

        ; Unlock critical section
        invoke  LeaveCriticalSection, Tcp.CritSection
        ; Wake the waiting sender
        invoke  WakeConditionVariable, Tcp.CondVar
.Exit:
        ret
endp




