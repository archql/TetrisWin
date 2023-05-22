; [in, edx] - 0
; [in, eax, ecx] - len of data block
; [in, esi, edi] - ptr to data block
proc Reconciliator.Sync

        lodsd ; tick (ignore)
        lodsd ; evt num
        mov     [Reconciliator.Event], eax
        lodsd ; time
        mov     [Reconciliator.LastProcessed], eax
        ; Copy all content (were assuming that packet is in our designed format)
        mov     edi, Game.NickName ; table of rcds   (got msg pos)
        mov     ecx, FILE_SZ_TO_WRITE - 4
        rep movsb
        ;
        mov     word [Client.State], CLIENT_STATE_ONLINE
        ; get current time
        invoke  GetTickCount
        mov     [Reconciliator.ZeroTime], eax
        mov     [Reconciliator.GlobalTime], eax
        mov     [Reconciliator.GameTime], eax

        ret
endp

; All direct writes to Game must be done through this method
;############### KEY EVENT ############
; - processes a key code, stored in eax
; - Special control codes:
;   - Game update               - 7  (undefined in VK table)
;   - Shift key up              - 15 (undefined in VK table)
;   - Ignore downward collision - 0 (only for actual figure, not preview)
Reconciliator.ProcessEvent

        ;  guarantee 7th event when time from last 7th event is expired
        if (this.game.playing && !this.game.paused && event !== 7
            && ((this.globalTime - this.gameTime) > this.game.tickSpeed)) {
            console.log("RECONCILIATION FORCE 7");
            // force process 7 event and ignore next one
            this.onTimer();
        }
        // add input to input buffer
        let bufferIndex = this.currentEvent % BUFFER_SIZE;
        // add new Input event
        this.inputBuffer[bufferIndex] = new GameInput(this.currentTick, this.currentEvent,
            this.globalTime - this.timeStarted, {id: event});
        // process event
        this.game.processEvent(event);
        // add game state to state buffer
        this.stateBuffer[bufferIndex] = new GameState(this.currentTick, this.currentEvent,
            this.globalTime - this.timeStarted, this.game.deepCopy());
        // increase number of processed events
        this.currentEvent++;
        // send input to server
        this.socket.emit('input', this.inputBuffer[bufferIndex]);
        ;

        ret
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
        mov     eax, dword [esp]
        stdcall SoundPlayer.Update ; got eax in [esp] as param
@@:

        ; define game tick update
        mov     eax, dword [esp]
        mov     dword [Reconciliator.GlobalTime], eax  ; save tick count
        sub     eax,  [Reconciliator.CurTick]
        movzx   edx,  [Game.TickSpeed]
        and     [Game.SoftDrop], 1
        jz      @F
        shr     edx, 2
@@:
        cmp     eax, edx
        jb      @F
        add     dword [Reconciliator.CurTick], eax
        add     dword [Game.TicksPlayed], eax
        ; call game update
        mov     eax, 7; key with ID 7 is undefined
        stdcall Game.KeyEvent ; Safe call?
@@:
.finish:
        ret
endp

proc Reconciliator.Reconcile
        ; get last processes server state
        this.lastProcessedState = this.lastServerProcessedState;
        const serverBufferIndex = this.lastServerProcessedState.event % BUFFER_SIZE;
        // reset problematic point
        this.stateBuffer[serverBufferIndex] = this.lastServerProcessedState;
        this.game.constructFromPrototype(this.lastServerProcessedState.state);
        // simulate all ticks up to the current
        let eventToProcess = this.lastServerProcessedState.event + 1;
        while (eventToProcess < this.currentEvent) {
            const bufIndex = eventToProcess % BUFFER_SIZE;
            const input = this.inputBuffer[bufIndex];
            // reprocess input
            this.game.processEventSilent(input.input.id);
            this.stateBuffer[bufIndex] = new GameState(input.tick, input.event, input.time, this.game.deepCopy());
            //
            eventToProcess++;
        }

        ret
endp