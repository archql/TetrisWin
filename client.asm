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

; protected strings
        Wnd.Text                    db    'Launch error :/', 0
        Wnd.class                   db    'FASMW32',0
        Wnd.title                   db    'TETRIS WIN ASM by Artiom Drankevich',0
        Client.QuaryValue           db    'SOFTWARE\Microsoft\Cryptography', 0
        Client.QuaryKey             db    'MachineGuid', 0
        WndCreationCheck            db    'ACCEPT', 0


; # send Chat msg
proc Client.SendChatMsg ; Can be bugged call (2 threads using same mem)

        cmp     [Client.State], CLIENT_STATE_REGISTERED
        jne      @F ; failed to rg
        ; move msg to buf
        mov     esi, Chat.Buf
        mov     edi, Client.Buffer
        mov     ecx, CHAT_MSG_LEN ; 32 == buf.len
        rep movsb
        ; send chat msg
        mov     edi, MESSAGE_BASE_LEN
        mov     ebx, MSG_CODE_BASE_CHAT ; msg len
        stdcall Client.ThSafeCall, Client.Broadcast
        ; clear buf
        mov     edi, Chat.Buf
        mov     al,  ' '
        mov     ecx, CHAT_MSG_LEN ; 32 == buf.len
        rep stosb
        ; set ptr to zero
        mov     [Chat.InpPos], 0
@@:
        ret
endp

; # send RequestGame msg
proc Client.RequestGame ; Can be bugged call (2 threads using same mem)

        cmp     [Client.State], CLIENT_STATE_REGISTERED
        jne      @F ; failed to rg
        ; reset random
        stdcall Random.Initialize
        ; send start game signal
        mov     edi, MESSAGE_START_GAME_LEN
        mov     ebx, MSG_CODE_START_GAME ; msg len
        stdcall Client.ThSafeCall, Client.Broadcast
        ; start game (IF NOT SELF ACTIVATION)
        ;stdcall Game.Initialize
        ;mov     [Game.Pause], 0
@@:
        ret
endp

; # send registration msg
proc Client.SendRegistration   ; Can be bugged call (2 threads using same mem)

        ; send register signal
        mov     edi, MESSAGE_BASE_LEN
        mov     ebx, MSG_CODE_REGISTER ; msg len
        stdcall Client.ThSafeCall, Client.Broadcast
        ;invoke  sendto, ebx, GameMessage, MESSAGE_BASE_LEN, 0, Client.Broadcast_addr, sizeof.sockaddr_in
        ; sleep some time
        invoke  Sleep, 500
        ; check if someone rejected my message
        cmp     [Client.State], CLIENT_STATE_REJECTED
        je      @F ; failed to rg
        ; if no -- register success
        mov     [Client.State], CLIENT_STATE_REGISTERED
    @@:
        ret
endp

; # send message to all network adapters
; - [in, ebx] msgId
; - [in, edi] msgSz
proc Client.Broadcast

        mov     ecx, dword [Client.IPAddrTableBuf + MIB_IPADDRTABLE.dwNumEntries]
        xor     esi, esi ; table offset
.LoopBroadcast:
        ; do
        ; save loop ctr
        push    ecx
        ; Get broadcast ips (TEST)
        mov     eax, dword [Client.IPAddrTableBuf + MIB_IPADDRTABLE.table + esi + MIB_IPADDRROW.dwAddr]
        mov     edx, dword [Client.IPAddrTableBuf + MIB_IPADDRTABLE.table + esi + MIB_IPADDRROW.dwMask]
        not     edx
        or      eax, edx ; got IP in eax

        ; enter critical section
        ;push    eax
        ;invoke  EnterCriticalSection, Client.CritSection
        ;pop     eax
        ; set MSGID
        mov     word [Client.MessageCode], bx
        ; set IP
        mov     [Client.Broadcast_addr + sockaddr_in.sin_addr], eax
        ; send (message code already at its place and thread change is already locked)
        invoke  sendto, [Client.psocket], GameMessage, edi, 0, Client.Broadcast_addr, sizeof.sockaddr_in
        ; leave critical section
        ;invoke  LeaveCriticalSection, Client.CritSection

        ; go next
        add     esi, sizeof.MIB_IPADDRROW
        ; restore ctr
        pop     ecx
        ; cont loop
        loop    .LoopBroadcast

        ret
endp

; # MySendTo
; - [in, ebx] msgId
; - [in, edi] msgSz
proc Client.Send ; requires msgId & msgSz

        mov     word [Client.MessageCode], bx
        mov     ax, MYPORT
        xchg    ah, al
        mov     [Client.Sender_addr.sin_port], ax
        invoke  sendto, [Client.psocket], GameMessage, edi, 0, Client.Sender_addr, sizeof.sockaddr_in

        ret
endp

; # Safe function
; - [in, stack] ptr to function
proc Client.ThSafeCall ; uses as params ebx esi edi
        ; save all base rgs
        push    eax ecx edx
        ; enter critical section
        invoke  EnterCriticalSection, Client.CritSection
        ; restore rgs
        pop     edx ecx eax
        ; call
        stdcall dword [esp + 4]
        ; leave crit section
        invoke  LeaveCriticalSection, Client.CritSection
        ; ret
        ret 4
endp

; # initialize client to work
proc Client.Init
        ; check if registration try needed
        cmp     [Client.State], CLIENT_STATE_REJECTED
        jne     @F
        mov     [Client.State], CLIENT_STATE_ONLINE
        stdcall Client.SendRegistration
        jmp     .EndProc
@@:
        ; check if startup needed
        cmp     [Client.State], CLIENT_STATE_OFFLINE
        jne     .EndProc

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
        ; DISABLE??
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

        ;Client.pIPAddrTable
        ; Get Adapters List
        invoke  GetIpAddrTable, Client.IPAddrTableBuf, Client.dIPAddrTableSz, eax
        test    eax, eax
        jnz     .ErrorConnect ;!= NO_ERROR = 0
        ; Yess, connection Ready!

        ; start || thread (Recv)
        xor     eax, eax
        invoke  CreateThread, eax, eax, Client.ThRecv, ebx, eax, Client.ThRecv.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect
        ;mov     [Client.Recv.thStop], 0

        ; start || thread (Send)
        xor     eax, eax
        invoke  CreateThread, eax, eax, Client.ThSend, ebx, eax, Client.ThSend.pThId; last is ptr to thread id
        test    eax, eax
        jz      .ErrorConnect
        ;mov     [Client.ThSend.thStop], 0

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
.EndProc:
        ret
endp

; ### THERAD RECIEVER PROC
proc Client.ThSend,\
        lpParameter ; PSOCKET

        stdcall Client.SendRegistration

.loopThread:
        ; Sleep
        invoke  Sleep, 200;200
        ; if registered:
        cmp     [Client.State], CLIENT_STATE_REGISTERED
        jne     .EndThCycleUpdate ; just wait

        ; Send PING msg
        mov     edi, FILE_SZ_TO_RCV
        mov     ebx, MSG_CODE_PING; Senf full game frame(were MESSAGE_BASE_LEN) ; msg len
        stdcall Client.ThSafeCall, Client.Broadcast

        ; Check pings
        mov     esi, Client.ClientsDataArr + NICKNAME_LEN ; tgt ping
    .LoopCheckPings:
        cmp     word [esi], 0
        je      .CheckEnd ;if zero -> rcd empty
        jl      @F        ;if < 0  -> rcd freed
        dec     word [esi]
        jnz     @F        ;if became 0 -> rcd need to be freed
        dec     word [esi]
   @@:
        add     esi, CLIENT_CL_RCD_LEN
        jmp     .LoopCheckPings
    .CheckEnd:
        ; TEMP

        ; LOOP THREAD
    .EndThCycleUpdate:
        cmp     [Client.ThSend.thStop], 1
        jne     .loopThread
.EndThread:

        ret
endp

; ### THERAD RECIEVER PROC
proc Client.ThRecv,\
        lpParameter ; PSOCKET

        mov     [Client.StructLen], sizeof.sockaddr_in
.loopThread:
        ; recieve data from all members
        invoke  recvfrom, [lpParameter], Client.recvbuff, CLIENT_RECV_BUF_LEN, 0, Client.Sender_addr, Client.StructLen;
        cmp     eax, 0
        jle     .FailedToRecieve
        ; get msgID
        movzx   eax, word [Client.recvbuff + Client.MessageCode - GameMessage]; controlMsg
        ; SWITCH msg codes  (some of them require filter selfsend msgs)
        ;cmp     ax, MSG_CODE_BASE_CHAT

        cmp     ax, MSG_CODE_BASE_CHAT
         je      .MessageChatMsg
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
        cmp     ax, MSG_CODE_PROXY
         je      .MessageProxy
        ; DEFAULT BEHAVIOUR
        jmp     .EndMessage
   ;### ; ======================
.MessageChatMsg:
        ; ignore msg if its from me (name == & from localhost)
        mov     esi, Client.recvbuff + (Game.NickName - GameMessage)
        mov     edi, Game.NickName
        mov     ecx, NICKNAME_LEN
        repe cmpsb
        jne     .Ok_L
        cmp     [Client.Sender_addr.sin_addr], 0x0100007f  ; 127.0.0.1
        jne     .EndMessage
     .Ok_L:
        ; chat message arrived -- copy it
        mov     esi, Client.recvbuff + Client.Buffer - GameMessage
        movzx   edi, [Chat.Length]; cur rcd
        push    edi
        shl     edi, CHAT_MSG_RCD
        add     edi, Chat.Table ; table of rcds   (got msg pos)
        mov     ecx, CHAT_MSG_LEN
        rep movsb
        ; update len
        inc     [Chat.Length]
        ; update pos (MsgPos == Length)
        pop     edi
        cmp     di, [Chat.MsgPos]
        jne     @F
        inc     [Chat.MsgPos]
@@:
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
        ; first first check if registered
        cmp     [Client.State], CLIENT_STATE_REGISTERED
        jne     .EndPingMsg
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
        je      .StrFounded ;(corresponding rcd founded -- inc ping)
        ; if str not equal (from repe cmpsb)
   .StrNotEqual:
        test    ax, ax
        ; ckeck if ping = zero -- if yes -- founded
        jz      .FoundedFree
        ; ckeck if ping < zero -- if yes -- mark as first free place
        jns     @F ; if greater than zero -- not free
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
  .StrFounded:
        ; copy nick str
        rep movsb
        ; set base (MAX) ping
        mov     word [edi], 10
        ; copy message (game frame)
        mov     esi, Client.recvbuff + (GameBuffer - GameMessage)
        inc     edi
        inc     edi
        mov     ecx, FILE_SZ_TO_WRITE
        rep movsb
        ;
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
        mov     ebx, MSG_CODE_RG_REJECTED
        mov     edi, MESSAGE_BASE_LEN
        stdcall Client.ThSafeCall, Client.Send

    .RegistrationOK:
        ; #2. Send request for RCDS (only to person who just registered).
        mov     ebx, MSG_CODE_REQ_TTR
        mov     edi, MESSAGE_BASE_LEN
        stdcall Client.ThSafeCall, Client.Send
         ; partial message
.MessageSendUpdates:
        ; #3. Send updates to person.
        ; setup params
        mov     esi, Settings.fileData.cFileName
        mov     edi, Client.Send;Client.Sender_addr
        push    Client.ListAllTTRFiles.SendFile
        stdcall Settings.ListAllTTRFiles

        ; exit msg update
        jmp     .EndMessage
   ;### ; ======================
.MessageRgRejected:
        ; set state to failure
        cmp     [Client.State], CLIENT_STATE_REGISTERED
        je      @F ; if client isnt registered yet
        mov     [Client.State], CLIENT_STATE_REJECTED
    @@:
        jmp     .EndMessage
   ;### ; ======================
.MessageGotTTR:
        ; got ttrs msg
        ; check if in msg score is valid
        ; TEMP!!!!!!!!!!!!!!!!!!!!!!
        ;mov     dword [Game.BlocksArr+40], 0x01010101
        ; TEMP COPY
        movzx   eax, word [Client.recvbuff + (GameBuffer.Score       - GameMessage)]
        mov     bx,  word [Client.recvbuff + (GameBuffer.ControlWord - GameMessage)]
        ;mov     esi, dword [Client.recvbuff + (GameBuffer.Score - GameMessage)]
        ;mov     dword [Settings.buffer], esi
        stdcall Settings.DecodeWord ; ret score in eax, TRUE|FALSE in bx, uses cx
        test    bx, bx
        jnz     .EndMessageTTR ; failed to decode
        push    eax ; save got highscore

        ; TEMP!!!!!!!!!!!!!!!!!!!!!!
        ;mov     dword [Game.BlocksArr+40], 0x02020202
        ; get own file data
        mov     eax, Client.recvbuff + (Client.Buffer - GameMessage); nickname ptr in such msg
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
        ;add esp, 8
        pop     eax
        pop     eax
     .EndMessageTTR:
        jmp     .EndMessage
   ;### ; ======================
.MessageStartGame:
        ; Here set rnd gen if game stopped
        cmp     [Game.Playing], TRUE
        je      .EndMessage
        ; set rnd gen ; GAME MEM USAGE -- PROPERTY OF MAIN THREAD!!!
        mov     eax, dword [Client.recvbuff + (Random.dSeed - GameMessage)]
        mov     dword [Random.dPrewNumber], eax
        mov     dword [Random.dSeed], eax
        mov     [Game.Playing], TRUE ; To prevent activalion from next messages
        ; clear field
        stdcall Client.ThSafeCall, Game.IniField
        ; start game
        stdcall Client.ThSafeCall, Game.Initialize ; USES GAME MEM -- PROPERTY OF MAIN THREAD!!! CONFLICT!!!
        mov     [Game.Pause], 0
        ; exit
        jmp     .EndMessage
   ;### ; ======================
.MessageProxy:
        ; Here if acting as proxy packet arrived
        ; -- safe copy it; GAME MEM USAGE -- PROPERTY OF MAIN THREAD!!!
        mov     esi, Client.recvbuff + GameBuffer - GameMessage
        mov     edi, GameBuffer ; table of rcds   (got msg pos)
        mov     ecx, FILE_SZ_TO_WRITE
        rep movsb

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
proc Client.ListAllTTRFiles.SendFile ; esi -- ptr to name str, edi -- ptr to send function (TODO -- create sendbuf)
        push    ebx esi edi; required to save it!

        ; enter critical section
        invoke  EnterCriticalSection, Client.CritSection

        ; get score
        mov     eax, esi
        stdcall Settings.GetHigh  ; SETTINGS BUF MEM USAGE -- PROPERTY OF MAIN THREAD!!!
        ; mov high to buffer
        mov     [GameBuffer.Score], ax
        stdcall Settings.EncodeWord
        mov     [GameBuffer.ControlWord], bx
        ; mov str to buffer
        ;mov     esi, Settings.fileData.cFileName
        mov     edi, Client.Buffer
        mov     ecx, NICKNAME_LEN
        rep movsb
        ; restore ptr to function
        mov     eax, dword [esp]
        ; send it
        ; required:
        ; - ebx - msgId
        mov     ebx, MSG_CODE_TTR
        ; - edi - msgSz
        mov     edi, MESSAGE_BASE_LEN
        stdcall eax
        ;invoke  sendto, [Client.psocket], GameMessage, MESSAGE_BASE_LEN, 0, edi, sizeof.sockaddr_in
        ; leave critical section
        invoke  LeaveCriticalSection, Client.CritSection

        ; ret
        pop     edi esi ebx
        ret
endp


; ## Destroys all data allocated for Network
proc Client.Destroy

        ; stop
        cmp     [Client.State], CLIENT_STATE_OFFLINE
        je      @F
        ; set
        mov     [Client.State], CLIENT_STATE_OFFLINE
        ; stop thread
        mov     [Client.ThRecv.thStop], TRUE
        mov     [Client.ThSend.thStop], TRUE
        ; close if need
        invoke  closesocket, [Client.psocket]
        invoke  WSACleanup
@@:

        ret
endp
