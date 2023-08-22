        TCP_BUFFER_SIZE                 = 16384 ; 16kbytes ; 8192 ; 8kbytes
        TCP_SIZES_BUFFER_SIZE           = 256 ; max stored at once
        TCP_SIZES_BUFFER_SIZE_MASK      = 0xFF ; mask for TCP_SIZES_BUFFER_SIZE
        SHA_256_LEN                     = 64

        ;Tcp.SocketTimeout               dd      500 ; ms
        ;Tcp.SocketTimeout.Size          = 4


        Reconciliator.StrError          db    '@OFFLINE'
        RECONCILIATOR_STR_LEN           = $ - Reconciliator.StrError
        Reconciliator.StrConnected      db    '@ON-LINE' ; valid net state
        Reconciliator.StrRegistered     db    '@REGSTRD' ; valid net state
        Reconciliator.StrRgRejected     db    '@REJCTED' ; valid net state
        Reconciliator.StrConLost        db    '@CONLOST'
        Reconciliator.StrInitError      db    '@INITERR'
        Reconciliator.StrConnecting     db    '@JOINING'

        RECONCILIATOR_STATE_OFFLINE     = 0
        RECONCILIATOR_STATE_ONLINE      = 1
        RECONCILIATOR_STATE_REGISTERED  = 2
        RECONCILIATOR_STATE_REJECTED    = 3
        RECONCILIATOR_STATE_CONLOST     = 4
        RECONCILIATOR_STATE_INITERROR   = 5
        RECONCILIATOR_STATE_CONNECTING  = 6

        Tcp.Base64Symbols       db      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

        Tcp.Websocket.Auth.File db      'passw.txt', 0'

        Tcp.Websocket.Conn      db      'GET /socket-io/?EIO=4&transport=websocket '
        Tcp.Websocket.Conn.HTTP db      'HTTP/1.1',\
                                        13, 10, 'Connection: Upgrade', 13, 10,\
                                        'Upgrade: websocket', 13, 10,\
                                        'Host: localhost', 13, 10,\
                                        'Sec-WebSocket-Version: 13', 13, 10,\
                                        'Sec-WebSocket-Key: '
        Tcp.Websocket.Conn.2    db      22 dup ?, '=='
        Tcp.Websocket.Conn.End  db      13, 10, 13, 10
        Tcp.Websocket.Conn.Len  = $ - Tcp.Websocket.Conn
        Tcp.Websocket.Conn.HTTP.Len     = 8
        Tcp.Websocket.Conn.End.Len      = 4

        Tcp.Websocket.Pong      db      '3'

        Tcp.Websocket.Join      db      '40/game,{"nickname":"'
        Tcp.Websocket.Join.1    db      NICKNAME_LEN dup ?, '","password_hash":"'
        Tcp.Websocket.Join.2    db      SHA_256_LEN  dup ?, '"}'
        Tcp.Websocket.Join.Len  = $ - Tcp.Websocket.Join
        Tcp.Websocket.Join.BaseLen      = 7 ; '40/game'

        Tcp.Websocket.Event     db      '451-/game,["'
        Tcp.Websocket.Event.ID  db      'inpX'
        Tcp.Websocket.Event.1   db      '",{"_placeholder":true,"num":0}]'
        Tcp.Websocket.Event.Len = $ - Tcp.Websocket.Event

        Tcp.Websocket.Ready     db      '42/game,["r rd"]'
        Tcp.Websocket.Ready.Len = $ - Tcp.Websocket.Ready

        Tcp.hsocket             dd              not (0)

        ; UNITIALIZED DATA

        ; This is private data of TCP module
        Tcp.wsaData             WSADATA         ?
        Tcp.Addr                sockaddr_in     ?

        Tcp.Connected           dd              ?

        ; # BUFFER TO SCORE WRITE & GAME RESTORE
        Tcp.CritSection         RTL_CRITICAL_SECTION    ?
        Tcp.CondVar             RTL_CONDITION_VARIABLE  ?

struct THREAD_INFO
        hThread                 dd      ?
        pThId                   dd      ?
        thStop                  dw      ?
ends

        Tcp.ThSend              THREAD_INFO     ?
        Tcp.ThRecv              THREAD_INFO     ?
        Tcp.ThMain.pThId        dd              ?

        Tcp.Buffer.recv.begin   dw      ?
        Tcp.Buffer.recv.end     dw      ?
        Tcp.Buffer.recv         db      (TCP_BUFFER_SIZE + 2) dup ? ; + 2 is for overflow len mark @see Tcp.Buffer.Enqueue

        Tcp.Buffer.send.begin   dw      ?
        Tcp.Buffer.send.end     dw      ?
        Tcp.Buffer.send         db      (TCP_BUFFER_SIZE + 2) dup ?

        Tcp.BufferIn.Size       =       TCP_BUFFER_SIZE
        Tcp.BufferIn            db      Tcp.BufferIn.Size dup ?

        SocketIO.BufferOut.Size =       TCP_BUFFER_SIZE
        SocketIO.BufferOut      db      SocketIO.BufferOut.Size dup ?

; filled size = Tcp.Buffer.recv.end - Tcp.Buffer.recv.begin
; writePastEnd = Tcp.Buffer.recv.begin + write > Tcp.Buffer.recv + TCP_BUFFER_SIZE

        ; 0 is no event (ignore)
        SocketIO.NextEventId.lb         = 4
        SocketIO.NextEventId.upd        = 3
        SocketIO.NextEventId.sync       = 2
        SocketIO.NextEventId.unknown    = 1 ; unknown binary event happened
        SocketIO.NextEventId            db      ?

        ; # Random
SocketIO.Random:
        SocketIO.Random.dSeed           dd      ?
        SocketIO.Random.dPrevNumber     dd      ?


        Reconciliator.EventNo           dd      ?
        Reconciliator.LastProcessed     dd      ?

        Reconciliator.ZeroTick          dd      ?  ; point from which sync with server happened
        Reconciliator.GlobalTick        dd      ?  ; must be as fresh as possible
        Reconciliator.GameTick          dd      ?  ; for game ticks
        Reconciliator.TicksPlayed       dd      ?  ; ????

struct GameInput
        tick            dd      ?  ; ignore
        eventNo         dd      ?
        time            dd      ?
        eventId         dd      ?
ends ; has size of power of 2: 2^5

struct GameState
        tick            dd      ?  ; ignore
        eventNo         dd      ?
        time            dd      ?
        state           db      sizeof.TetrisFrame dup  ?
ends

        RECONCILIATOR_BUFFER_SIZE       = 1024 ; must be power of 2
        Reconciliator.InputBuffer       db      sizeof.GameInput*RECONCILIATOR_BUFFER_SIZE dup ?
        Reconciliator.StateBuffer       db      sizeof.GameState*RECONCILIATOR_BUFFER_SIZE dup ?



