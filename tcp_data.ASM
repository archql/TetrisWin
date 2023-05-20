        TCP_BUFFER_SIZE                 = 8192 ; 8kbytes
        TCP_SIZES_BUFFER_SIZE           = 256 ; max stored at once
        TCP_SIZES_BUFFER_SIZE_MASK      = 0xFF ; mask for TCP_SIZES_BUFFER_SIZE
        SHA_256_LEN                     = 64


        Tcp.Base64Symbols       db      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

        Tcp.Websocket.Auth.File db      'passw.txt', 0'

        Tcp.Websocket.Conn      db      'GET /socket.io/?EIO=4&transport=websocket '
        Tcp.Websocket.Conn.HTTP db      'HTTP/1.1',\
                                        13, 10, 'Connection: Upgrade', 13, 10,\
                                        'Upgrade: websocket', 13, 10,\
                                        'Sec-WebSocket-Version: 13', 13, 10,\
                                        'Sec-WebSocket-Key: '
        Tcp.Websocket.Conn.2    db      22 dup ?, '=='
        Tcp.Websocket.Conn.End  db      13, 10, 13, 10
        Tcp.Websocket.Conn.Len  = $ - Tcp.Websocket.Conn
        Tcp.Websocket.Conn.HTTP.Len     = 8
        Tcp.Websocket.Conn.End.Len      = 4

        Tcp.Websocket.Join      db      '40/game,{"nickname":"'
        Tcp.Websocket.Join.1    db      NICKNAME_LEN dup ?, '","password_hash":"'
        Tcp.Websocket.Join.2    db      SHA_256_LEN  dup ?, '"}'
        Tcp.Websocket.Join.Len  = $ - Tcp.Websocket.Join
        Tcp.Websocket.Join.BaseLen      = 7 ; '40/game'

        Tcp.Websocket.Event     db      '451-/game,["input",{"_placeholder":true,"num":0}]'
        Tcp.Websocket.Event.Len = $ - Tcp.Websocket.Event



        Tcp.wsaData             WSADATA         ?
        Tcp.hsocket             dd              ?
        Tcp.flag                dd              ?
        Tcp.Addr                sockaddr_in     ?

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

        Tcp.Buffer.send.begin   db      ?
        Tcp.Buffer.send.end     db      ?
        Tcp.Buffer.send         db      (TCP_BUFFER_SIZE + 2) dup ?

        Tcp.BufferIn.Size       =               1024
        Tcp.BufferIn            db              Tcp.BufferIn.Size dup ?

; filled size = Tcp.Buffer.recv.end - Tcp.Buffer.recv.begin
; writePastEnd = Tcp.Buffer.recv.begin + write > Tcp.Buffer.recv + TCP_BUFFER_SIZE

