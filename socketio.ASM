proc SocketIO.Connect

        ; init packet headers
        stdcall Tcp.Init
        stdcall Tcp.Connect
        ;

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