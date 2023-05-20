proc SocketIO.Connect
        mov      dword [Game.BlocksArr], 0x01040401

        ; init packet headers
        stdcall Tcp.Init
        stdcall Tcp.Connect
        ;
        test    eax, eax
        jz      @F
        ; success
        mov     dword [Game.BlocksArr], 0x04040404
        ; send packet
        ; Thread-safe way to enqueue TCP packet
        ; - [in, esi] ptr to data block (from)
        mov     esi, Tcp.Websocket.Conn
        ; - [in, eax] len of data block
        mov     eax, Tcp.Websocket.Conn.Len
        stdcall Tcp.EnqueuePacket ; uses eax ecx edx esi edi ebx??
@@:

        ret
endp

proc SocketIO.On

        ; TEMP TEST
        mov     eax, 'P'
        stdcall Game.KeyEvent
        ;
        mov     dword [Game.BlocksArr + 16], 0x06070809

        ret
endp

proc SocketIO.Disconnect

        ; destroy tcp related things
        stdcall Tcp.Destroy

        ret
endp

proc SocketIO.Emit

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp

proc SocketIO.Namespace

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp

proc SocketIO.Auth

        ; init packet headers
        stdcall Tcp.Init
        ;

        ret
endp