; THIS IS FOR LOCAL NETWORK BROADCAST

INVALID_SOCKET              = 0xFF'FF'FF'FF
SOCKET_ERROR                = 0xFF'FF'FF'FF
MYPORT                      = 7000
IPPROTO_UDP                 = 17

SOL_SOCKET                  = 0xFFFF
SO_BROADCAST                = 0x0020
SO_REUSEADDR                = 0x0004

; # CLIENT
        ;Client.wsaData          WSADATA         ?
        ;Client.psocket          dd              ?
        ;Client.flag             dd              ?
        ;Client.Recv_addr        sockaddr_in     ?
        ;Client.Sender_addr      sockaddr_in     ?
        ;Client.Broadcast_addr   sockaddr_in     ?


proc Client.Init

        ; init WSA
        invoke  WSAStartup, 0x0202, Client.wsaData ; init winsock
        test    eax, eax
        jnz     .ErrorConnect

        ; params
        invoke  socket, AF_INET, SOCK_DGRAM, IPPROTO_UDP  ;create socket;
        cmp     eax, INVALID_SOCKET
        je      .ErrorConnect
        ; Socket opened!
        mov     [Client.psocket], eax ;save socket handle in ebx
        xchg    eax, ebx ; save handle in ebx
        ; Setup sockaddr_in's
        ; set port
        mov     ax, MYPORT
        xchg    ah, al
        ; #Recv_addr
        ; memset zero (dont need, already zero!)
        mov     [Client.Recv_addr.sin_family], AF_INET
        mov     [Client.Recv_addr.sin_port], ax
        ;mov     [Recv_addr.sin_addr], 0; ; already zero!
        ; #Broadcast_addr
        ; memset zero (dont need, already zero!)
        mov     [Client.Broadcast_addr.sin_family], AF_INET
        mov     [Client.Broadcast_addr.sin_port], ax
        mov     dword [Client.Broadcast_addr.sin_addr], not 0
        ; Bind socket
        invoke  bind, ebx, Client.Recv_addr, sizeof.sockaddr_in
        cmp     eax, SOCKET_ERROR
        je      .ErrorConnect
        ; set flag
        mov     [Client.flag], TRUE
        ; Set socket options
        invoke  setsockopt, ebx, SOL_SOCKET, SO_BROADCAST, Client.flag, 4; = sizeof.Client.flag
        test    eax, eax; CHECK THIS!!!!
        js      .ErrorConnect ;( < 0)
        invoke  setsockopt, ebx, SOL_SOCKET, SO_REUSEADDR, Client.flag, 4; = sizeof.Client.flag
        test    eax, eax; CHECK THIS!!!!
        js      .ErrorConnect ;( < 0)
        ; Yess, connection Ready!

        ; start || thread
        xor     eax, eax
        invoke  CreateThread, eax, eax, Client.ThreadUpdate, eax, eax, Client.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect

        ; send register signal


        ; set result
        mov     eax, TRUE
        jmp     .Exit

.ErrorConnect:
        invoke  closesocket, ebx
        invoke  WSACleanup
        ; set result
        xor     eax, eax
.Exit:
        mov     [Client.State], ax
        ret
endp

proc Client.ThreadUpdate,\
        lpParameter

        mov     [Client.StructLen], sizeof.sockaddr_in

.loopThread:

        ; recieve data from all members
        invoke  recvfrom, [Client.psocket], Client.recvbuff, CLIENT_RECV_BUF_LEN, 0, Client.Sender_addr, Client.StructLen;
        cmp     eax, 0
        jle     .FailedToRecieve
        mov     [Client.State], 2
        ; TEST  TEST TEST TEST TEST TEST TEST TEST TEST TEST
        xor     ebx, ebx
        movzx   al, byte [Client.recvbuff]

        invoke  SendMessage, [Wnd.hwnd], WM_KEYDOWN, eax, ebx

.FailedToRecieve:
        ;mov     eax, 1000
        ;invoke  Sleep, eax

        cmp     [Client.thStop], 1
        jne     .loopThread

        ret
endp

proc Client.Destroy

        cmp     [Client.State], FALSE
        je      @F
        ; stop thread
        mov     [Client.thStop], TRUE
        ; close if need
        invoke  closesocket, [Client.psocket]
        invoke  WSACleanup
@@:

        ret
endp