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

proc Client.RequestGame
        ; reset random
        stdcall Random.Initialize
        ; send start game signal
        mov     [Client.MessageCode], MSG_CODE_START_GAME
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_START_GAME_LEN, 0, Client.Broadcast_addr, sizeof.sockaddr_in
        ; start game
        ;stdcall Game.Initialize
        ;mov     [Game.Pause], 0

        ret
endp

; # initialize client to work
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
        mov     [Client.MessageCode], MSG_CODE_REGISTER
        invoke  sendto, ebx, GameMessage, MESSAGE_BASE_LEN, 0, Client.Broadcast_addr, sizeof.sockaddr_in

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

; ### THERAD PROC
proc Client.ThreadUpdate,\
        lpParameter

        mov     [Client.StructLen], sizeof.sockaddr_in
.loopThread:
        ; recieve data from all members
        invoke  recvfrom, [Client.psocket], Client.recvbuff, CLIENT_RECV_BUF_LEN, 0, Client.Sender_addr, Client.StructLen;
        cmp     eax, 0
        jle     .FailedToRecieve
        ; PROTECT FROM SELFSEND!
        ;mov     esi, Client.recvbuff + (Game.NickName - GameMessage)
        ;mov     edi, Game.NickName
        ;mov     ecx, 8; Nick len
        ;repe cmpsb
        ;je      .EndMessage
        ; test change text on screen
        mov     [Client.State], 2 ; Got Message (future -- mov msgId)
        ; get msgID
        movzx   eax, word [Client.recvbuff + Client.MessageCode - GameMessage]; controlMsg
        ; switch msg codes
   ;### ; ======================
        cmp     ax, MSG_CODE_KEYCONTROL
        jne     @F
        ; remote control message
        xor     ebx, ebx
        movzx   eax, byte [Client.recvbuff + 2]

        invoke  SendMessage, [Wnd.hwnd], WM_KEYDOWN, eax, ebx

        jmp     .EndMessage
   ;### ; ======================
@@:
        cmp     ax, MSG_CODE_REQ_TTR
        je      .MessageSendUpdates
        cmp     ax, MSG_CODE_REGISTER
        jne     @F
        ; #1. Register user.

        ; #2. Send request for RCDS (only to person who just registered). TODO! copy of sendto is too large!
        mov     [Client.MessageCode], MSG_CODE_REQ_TTR
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_BASE_LEN, 0, Client.Sender_addr, sizeof.sockaddr_in
.MessageSendUpdates:
        ; #3. Send updates to person. TODO! copy of sendto is too large!
        ; setup params
        mov     [Client.MessageCode], MSG_CODE_TTR
        mov     esi, Settings.fileData.cFileName
        mov     edi, Client.Sender_addr
        push    Client.ListAllTTRFiles.SendFile
        stdcall Settings.ListAllTTRFiles

        ; exit msg update
        jmp     .EndMessage
   ;### ; ======================
@@:
        cmp     ax, MSG_CODE_TTR
        jne     @F
        ; got ttrs msg
        ; check if in msg score is valid
        ; TEMP COPY
        mov     esi, dword [Client.recvbuff + (GameBuffer.Score - GameMessage)]
        mov     dword [Settings.buffer], esi
        stdcall Settings.DecodeWord ; ret score in eax, TRUE|FALSE in bx, uses cx
        test    bx, bx
        jnz     .EndMessageTTR ; failed to decode
        push    eax ; save got highscore
        ; get own file data
        mov     eax, Client.recvbuff + MESSAGE_BASE_LEN; nickname ptr in such msg
        push    eax ; save Nick ptr
        stdcall Settings.GetHigh; req ptr to nick str in eax, ret high in eax
        ; check if own data is up to date
        cmp     dword [esp + 4], eax
        jbe     .DataIsUpToDate
        ; update own data
        pop     edx
        pop     eax
        push    FILE_SZ_TO_READ ; overwrite?
        stdcall Settings.SetHigh

        ; exit data update
        jmp     .EndMessageTTR
.DataIsUpToDate:
        ; reset stack
        add esp, 8
.EndMessageTTR:
        jmp     .EndMessage
   ;### ; ======================
@@:
        cmp     ax, MSG_CODE_START_GAME
        jne     @F
        ; Here set rnd gen if game stopped
        cmp     [Game.Playing], TRUE
        je      @F
        ; set rnd gen
        mov     eax, dword [Client.recvbuff + (Random.dPrewNumber - GameMessage)]
        mov     dword [Random.dPrewNumber], eax
        mov     eax, dword [Client.recvbuff + (Random.dSeed - GameMessage)]
        mov     dword [Random.dSeed], eax
        ; start game
        stdcall Game.Initialize
        mov     [Game.Pause], 0
        ; exit
        jmp     .EndMessage
   ;### ; ======================
@@:
.EndMessage:
.FailedToRecieve:
        ;mov     eax, 1000
        ;invoke  Sleep, eax

        cmp     [Client.thStop], 1
        jne     .loopThread

        ret
endp

; ## Its for TTR filesend
proc Client.ListAllTTRFiles.SendFile ; esi -- ptr to name str, edi -- ptr to recv sockaddr_in (TODO -- create sendbuf)
        push    ebx esi edi; required to save it!

        ; get score
        mov     eax, esi
        stdcall Settings.GetHigh
        ; fill in msg
        ; mov high to buffer (THIS IS DANGEROUS BC ITS || THREAD!)
        mov     [GameBuffer.Score], ax
        stdcall Settings.EncodeWord
        mov     [GameBuffer.ControlWord], bx
        ; mov str to buffer
        ;mov     esi, Settings.fileData.cFileName
        mov     edi, Client.recvbuff + MESSAGE_BASE_LEN
        mov     ecx, 8
        rep movsb
        ; copy buffer
        mov     esi, GameMessage
        mov     edi, Client.recvbuff
        mov     ecx, MESSAGE_BASE_LEN
        rep movsb
        ; send it
        invoke  sendto, [Client.psocket], Client.recvbuff, MESSAGE_BASE_LEN + 8, 0, edi, sizeof.sockaddr_in

        pop     edi esi ebx
        ret
endp


; ## Destroys all data allocated for Network
proc Client.Destroy

        ; send disconnect message

        ; stop
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
