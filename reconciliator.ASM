        ; Protected strings
        Wnd.Text                    db    'Launch error :/', 0
        Wnd.class                   db    'FASMW32',0
        Wnd.title                   db    'TETRIS WIN ASM by Artiom Drankevich',0
        Client.QuaryValue           db    'SOFTWARE\Microsoft\Cryptography', 0
        Client.QuaryKey             db    'MachineGuid', 0
        WndCreationCheck            db    'ACCEPT', 0


proc Reconciliator.Init

        ; set current time
        invoke  GetTickCount
        mov     [Reconciliator.ZeroTick], eax
        mov     [Reconciliator.GlobalTick], eax
        mov     [Reconciliator.GameTick], eax
        ; other values are 0, so its ok

        ret
endp


; [in, edx] - 0
; [in, eax, ecx] - len of data block
; [in, esi, edi] - ptr to data block
proc Reconciliator.Sync
        ;   TODO TEST
        mov     word [Client.State], CLIENT_STATE_ONLINE
        ; 1st write to the array of states
        mov     edi, Reconciliator.StateBuffer ; write to the array of states
        ; get server tick (ignore)
        movsd
        ; get evt num
        lodsd
        stosd
        mov     [Reconciliator.LastProcessed], eax
        inc     eax ; immediatly move to next event
        mov     [Reconciliator.EventNo], eax
        ; time (ignore, assume its 0)
        movsd
        ; get current time
        stdcall Reconciliator.Init ; Setup time
        ;
        jmp     Reconciliator.Reconcile ; esi is arrived frame, edi is last processed target frame
endp

; [in, edx] - 0
; [in, eax, ecx] - len of data block
; [in, esi, edi] - ptr to data block
proc Reconciliator.Update
        ; get server tick (ignore)
        lodsd
        ; get evt num
        lodsd
        mov     [Reconciliator.LastProcessed], eax ; set new last processed state
        mov     edx, eax ; save pos
        ; time (ignore, assume its 0)
        lodsd
        ; compare states
        ; 1) get state pos (TODO move to reconcile??)
        mov     edi, Reconciliator.StateBuffer
        mov     eax, sizeof.GameState ; can be filled up to the power of 2??
        and     edx, RECONCILIATOR_BUFFER_SIZE - 1
        mul     edx
        add     edi, eax
        add     edi, GameState.state ; move ptr directly to state buffer
        ; 2) compare
        ; esi is ptr to arrived frame
        push    esi edi; save it  and ptr to cur state
        mov     ecx, sizeof.TetrisFrame
        rep cmpsb ; edi is state, esi is arrived
        pop     edi esi
        jnz     Reconciliator.Reconcile
        ret
endp

; All direct writes to Game must be done through this method
;############### KEY EVENT ############
; - processes a key code, stored in eax
; - Special control codes:
;   - Game update               - 7  (undefined in VK table)
;   - Shift key up              - 15 (undefined in VK table)
;   - Ignore downward collision - 0 (only for actual figure, not preview)
proc Reconciliator.ProcessEvent
        ;  guarantee 7th event when time from last 7th event is expired
        ; if game running
        ;xor     ax, ax
        ;cmp     [Game.Playing], ax
        ;je      .noForce7
        ;cmp     [Game.Pause], ax
        ;jne     .noForce7
        ; cmp time
        ;stdcall  Reconciliator.OnTimer
;.noForce7:
        ; get input buffer index  (DUPLICATED)
        mov     edx, dword [Reconciliator.EventNo]
        mov     ecx, edx ; save pos
        and     edx, RECONCILIATOR_BUFFER_SIZE - 1
        shl     edx, 5 ; size of GameInput
        mov     edi, Reconciliator.InputBuffer
        add     edi, edx
        ; save pos
        push    edi
        ; save input key
        push    eax
        ; add new Input event
        ; tick (ignore)
        xor     eax, eax
        stosd
        ; EventNo
        mov     eax, ecx
        stosd
        ; time delta
        mov     eax, dword [Reconciliator.GlobalTick]
        sub     eax, dword [Reconciliator.ZeroTick]
        stosd
        ; input no
        pop     eax
        stosd
        ; saves (ecx is eventNo, stack is input buffer pos)
        push    ecx
        ; process event normally
        stdcall Game.KeyEvent
        ; restore
        pop     edx
        ; get state buffer pos
        mov     edi, Reconciliator.StateBuffer
        mov     eax, sizeof.GameState ; can be filled up to the power of 2??
        and     edx, RECONCILIATOR_BUFFER_SIZE - 1
        mul     edx
        add     edi, eax
        ; restore input buf pos
        mov     esi, dword [esp]
        ;
        mov     ecx, 4 * 3 ; size of input preambule
        rep movsb
        ; write cur state
        mov     esi, TetrisFrame
        mov     ecx, sizeof.TetrisFrame
        rep movsb
        ; inc num of processed events
        inc     dword [Reconciliator.EventNo]
        ;
        ; NEXT send input to the server
        ; Send preambule
        ; - [in, dx] websocket packet type (ignore CONTINUE TYPE, so TEXT is 0, BINARY is 1)
        xor     edx, edx
        ; - [in, esi] ptr to data block (from)
        mov     esi, Tcp.Websocket.Event
        ; - [in, eax] len of data block
        mov     eax, Tcp.Websocket.Event.Len
        stdcall SocketIO.Emit
        ;
        ; Send data
        ; - [in, dx] websocket packet type (ignore CONTINUE TYPE, so TEXT is 0, BINARY is 1)
        xor     edx, edx
        inc     edx
        ; - [in, esi] ptr to data block (from)
        pop     esi
        ; - [in, eax] len of data block
        mov     eax, sizeof.GameInput
        jmp     SocketIO.Emit
endp

; must be called from timer as fast as possible
; [in, stack] - current tick count (from GetTickCount). You must save it in the stack!
proc Reconciliator.OnTimer

        ; CHECK IF GAME RUNNING
        ; if (this.game.playing && !this.game.paused)
        xor     ax, ax
        cmp     [Game.Playing], ax
        je      .finish
        cmp     [Game.Pause], ax
        jne     .finish

        ; check on snd (why here??)
        cmp     [Game.MusicOff], ax
        jne     @F
        mov     eax, dword [esp + 4]
        stdcall SoundPlayer.Update ; got eax in [esp] as param
@@:

        ; define game tick update
        mov     eax, dword [esp + 4]
        mov     dword [Reconciliator.GlobalTick], eax  ; save tick count
        sub     eax,  [Reconciliator.GameTick]
        movzx   edx,  [Game.TickSpeed]
        and     [Game.SoftDrop], 1
        jz      @F
        shr     edx, 2
@@:
        cmp     eax, edx
        jb      @F
        add     dword [Reconciliator.GameTick], eax
        add     dword [Game.TicksPlayed], eax
        ; call game update
        mov     eax, 7; key with ID 7 is undefined
        stdcall Reconciliator.ProcessEvent ; Safe call?
@@:
.finish:
        ret
endp

; [in, esi] - ptr to arrived ttr frame
; [in, edi] - ptr to last processed ttr frame
proc Reconciliator.Reconcile
        push    edi ; save State frame pos
        push    esi ; save Arrived frame pos
        ; mov Arrived frame -> TetrisFrame
        mov     ecx, sizeof.TetrisFrame
        push    ecx ; save counter
        mov     edi, TetrisFrame
        rep movsb
        ; restore
        pop     ecx esi edi
        ; mov Arrived frame -> StateBuffer
        rep movsb
        ; now edi is ptr to next statebuffer
        ; restore buffer pos
        mov     edx, dword [Reconciliator.LastProcessed]
        inc     edx ; last processed state no + 1
        mov     eax, dword [Reconciliator.EventNo]
        ; get loop ctr
        mov     ecx, eax
        sub     ecx, edx
        jz      .NothingToReconcile
        ; get input pos (DUPLICATED)
        mov     esi, Reconciliator.InputBuffer
        and     edx, RECONCILIATOR_BUFFER_SIZE - 1
        shl     edx, 5  ; size of GameInput
        add     esi, edx
        add     esi, GameInput.eventId ; move ptr directly to event id
        ; loop through all new events
.ReconcileLoop: ; (esi is pos of input no, ecx - loop ctr)
        ; get Input
        lodsd
        ; process it (SAVE REGISTERS)
        push    ecx esi edi
        stdcall Game.KeyEvent
        ; write new result - TetrisFrame -> StateBuffer[lastProcessed]
        pop     edi
        mov     ecx, sizeof.TetrisFrame
        mov     esi, TetrisFrame
        rep movsb
        ; restore data
        pop     esi
        ; go next (esi again is input, edi - output)
        add     esi, sizeof.GameInput - 4 ; because lodsd
        add     edi, sizeof.GameState - sizeof.TetrisFrame ; because rep movsb
        ;
        pop     ecx ; restore loop ctr
        ;
        loop .ReconcileLoop
        ;
.NothingToReconcile:
        ret
endp