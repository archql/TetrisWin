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

proc Client.RequestGame ; Can be bugged call (2 threads using same mem)
        ; reset random
        stdcall Random.Initialize
        ; send start game signal
        mov     [Client.MessageCode], MSG_CODE_START_GAME
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_START_GAME_LEN, 0, Client.Broadcast_addr, sizeof.sockaddr_in
        ; start game (IF NOT SELF ACTIVATION)
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

        ; start || thread (Recv)
        xor     eax, eax
        invoke  CreateThread, eax, eax, Client.ThRecv, eax, eax, Client.ThRecv.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect

        ; start || thread (Send)
        xor     eax, eax
        invoke  CreateThread, eax, eax, Client.ThSend, eax, eax, Client.ThSend.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect

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

; ### THERAD RECIEVER PROC
proc Client.ThSend,\
        lpParameter

        ; send register signal
        mov     [Client.MessageCode], MSG_CODE_REGISTER
        invoke  sendto, ebx, GameMessage, MESSAGE_BASE_LEN, 0, Client.Broadcast_addr, sizeof.sockaddr_in
        ; sleep some time
        invoke  Sleep, 1000
        ; check if someone rejected my message
        cmp     [Client.State], 3
        je      .EndThread ; failed to rg
        ; if no -- register success (POTENTIAL VULNERABILITY!) (disable ingame nick change)(disable rg failure when already registered (v))
        mov     [Client.State], 2
.loopThread:

        ; Send PING msg
        mov     [Client.MessageCode], MSG_CODE_PING
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_BASE_LEN, 0, Client.Broadcast_addr, sizeof.sockaddr_in
        ; Sleep
        invoke  Sleep, 1000 ; THREAD OVERLAP VULNERABILITY!!!!  -- FLAG IF OCCUPIED

        ; Check pings
        ; TEMP

        ; LOOP THREAD
        cmp     [Client.ThSend.thStop], 1
        jne     .loopThread
.EndThread:
        ret
endp

; ### THERAD RECIEVER PROC
proc Client.ThRecv,\
        lpParameter

        mov     [Client.StructLen], sizeof.sockaddr_in
.loopThread:
        ; recieve data from all members
        invoke  recvfrom, [Client.psocket], Client.recvbuff, CLIENT_RECV_BUF_LEN, 0, Client.Sender_addr, Client.StructLen;
        cmp     eax, 0
        jle     .FailedToRecieve
        ; get msgID
        movzx   eax, word [Client.recvbuff + Client.MessageCode - GameMessage]; controlMsg
        ; SWITCH msg codes  (some of them require filter selfsend msgs)
        cmp     ax, MSG_CODE_KEYCONTROL
         je      .MessageKeyControl
        cmp     ax, MSG_CODE_PING
         je      .MessagePing
        cmp     ax, MSG_CODE_START_GAME
         je      .MessageStartGame
        ; PROTECT FROM SELFSEND!
        mov     esi, Client.recvbuff + (Client.PCID - GameMessage)
        mov     edi, Client.PCID
        mov     ecx, CLIENT_PCID_LEN
        repe cmpsb
        je      .EndMessage
        ; OTHER MESSAGES
        cmp     ax, MSG_CODE_RG_REJECTED
         je      .MessageRgRejected
        cmp     ax, MSG_CODE_REQ_TTR
         je      .MessageSendUpdates
        cmp     ax, MSG_CODE_REGISTER
         je      .MessageRegister
        cmp     ax, MSG_CODE_TTR
         je      .MessageGotTTR
        ; DEFAULT BEHAVIOUR
        jmp     .EndMessage
   ;### ; ======================
.MessageKeyControl:
        ; remote control message
        xor     ebx, ebx
        movzx   eax, byte [Client.recvbuff + 2]

        invoke  SendMessage, [Wnd.hwnd], WM_KEYDOWN, eax, ebx

        jmp     .EndMessage
   ;### ; ======================
.MessagePing:
        ; first find rcd corresponding to got nickname
        mov     esi, Client.recvbuff + (Game.NickName - GameMessage)
        mov     edi, Client.ClientsDataArr
        mov     ecx, NICKNAME_LEN;CLIENT_CL_RCD_LEN ; TEMP -- RCD LEN!
        xor     ebx, ebx ; first free place

   .PingRcdLoopSet:
        ; ckeck if found
        push    esi edi ecx
        repe cmpsb
        pop     ecx edi esi
        mov     ax, word [edi + NICKNAME_LEN]; get PING
        jne     @F ; if str not equal (from repe cmpsb)
        ; rcd founded -- inc "ping" (if < MAX)
        cmp     ax, 10 ;MAX
        jge     @F
        ; inc
        inc     word [edi + NICKNAME_LEN]
        ; exit
        jmp     .EndPingMsg
   @@:
        cmp     ax, 0
        ; ckeck if ping = zero -- if yes -- founded
        je      .FoundedFree
        ; ckeck if ping < zero -- if yes -- mark as first free place
        jg      @F ; if greater than zero -- not free
        ; below zero -- freed place
        test    ebx, ebx ; if its first?
        jnz     @F
        ; yes
        mov     ebx, edi ; save first free place
   @@:
        ; go next rcd
        add     edi, CLIENT_CL_RCD_LEN
        jmp     .PingRcdLoopSet ; WARN IF OVERFLOW (MAX RCD 64)

   .FoundedFree:
        test    ebx, ebx ; if first found
        jz      @F
        ; yes
        mov     edi, ebx ; get first free place
   @@:
        ; copy str
        rep movsb
        mov     word [edi], 1
   .EndPingMsg:
        jmp     .EndMessage
   ;### ; ====================== (NEXT MESSAGES PROTECTED FROM SELFSEND)
.MessageRegister:
        ; #1. Check if same nickname -- if same -- send reject
        mov     esi, Client.recvbuff + (Game.NickName - GameMessage)
        mov     edi, Game.NickName
        mov     ecx, NICKNAME_LEN
        repe cmpsb
        jne     .RegistrationOK
        ; Send Rejection
        mov     [Client.MessageCode], MSG_CODE_RG_REJECTED
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_BASE_LEN, 0, Client.Sender_addr, sizeof.sockaddr_in

    .RegistrationOK:
        ; #2. Send request for RCDS (only to person who just registered). TODO! copy of sendto is too large!
        mov     [Client.MessageCode], MSG_CODE_REQ_TTR
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_BASE_LEN, 0, Client.Sender_addr, sizeof.sockaddr_in
         ; partial message
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
.MessageRgRejected:
        ; set state to failure
        cmp     [Client.State], 2
        je      @F ; if client isnt registered b4
        mov     [Client.State], 3
    @@:
        jmp     .EndMessage
   ;### ; ======================
.MessageGotTTR:
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
.MessageStartGame:
        ; Here set rnd gen if game stopped
        cmp     [Game.Playing], TRUE
        je      .EndMessage
        ; set rnd gen
        mov     eax, dword [Client.recvbuff + (Random.dSeed - GameMessage)]
        mov     dword [Random.dPrewNumber], eax
        mov     dword [Random.dSeed], eax
        ; start game
        stdcall Game.Initialize
        mov     [Game.Pause], 0
        ; exit
        jmp     .EndMessage
   ;### ; ======================
.EndMessage:
.FailedToRecieve:

        cmp     [Client.ThRecv.thStop], 1
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
        mov     edi, Client.Buffer
        mov     ecx, NICKNAME_LEN
        rep movsb
        ; send it
        invoke  sendto, [Client.psocket], GameMessage, MESSAGE_BASE_LEN, 0, edi, sizeof.sockaddr_in

        pop     edi esi ebx
        ret
endp


; ## Destroys all data allocated for Network
proc Client.Destroy

        ; stop
        cmp     [Client.State], FALSE
        je      @F
        ; stop thread
        mov     [Client.ThRecv.thStop], TRUE
        mov     [Client.ThSend.thStop], TRUE
        ; close if need
        invoke  closesocket, [Client.psocket]
        invoke  WSACleanup
@@:

        ret
endp
