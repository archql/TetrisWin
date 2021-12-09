        TOP_LINE                = 1
        FIG_START_Y             = -2

;========Game model==============
        Game.CurFig             dw      ?
        Game.CurFigColor        dw      ?
        Game.CurFigRotation     dw      ?
        Game.CurFigNumber       dw      ?
        Game.NextFig            dw      ?
        Game.NextFigNumber      dw      ?
        Game.FigX               dw      ?
        Game.FigY               dw      ?
        Game.FigPreviewY        dw      ?
        Game.TickSpeed          dw      ?
        Game.CurTick            dw      ?
        Game.Score              dw      ?
        Game.HighScore          dw      ?
        Game.Playing            dw      ?
        Game.Pause              dw      ?
        Game.FigsPlaced         dw      ?
        Game.SpeedMul           dq      0.96;96
        Game.Holded             dw      ?
        Game.HoldedFigNum       dw      ?
        Game.HoldedFig          dw      ?

        figArr          dw      0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b, 0000'0110_0110'0000b,\
                        0100'0100_0100'0100b, 0000'1111_0000'0000b, 0100'0100_0100'0100b, 0000'1111_0000'0000b,\
                        0100'0100_0110'0000b, 0010'1110_0000'0000b, 1100'0100_0100'0000b, 0000'1110_1000'0000b,\
                        0100'0100_1100'0000b, 0000'1110_0010'0000b, 0110'0100_0100'0000b, 1000'1110_0000'0000b,\
                        0100'1110_0000'0000b, 0100'0110_0100'0000b, 0000'1110_0100'0000b, 0100'1100_0100'0000b,\
                        1000'1100_0100'0000b, 0000'0110_1100'0000b, 1000'1100_0100'0000b, 0000'0110_1100'0000b,\
                        0100'1100_1000'0000b, 0000'1100_0110'0000b, 0100'1100_1000'0000b, 0000'1100_0110'0000b;,\
                        ;0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b, 0100'1110_0100'0000b,\
                        ;0000'1110_1010'0000b, 0110'0100_0110'0000b, 1010'1110_0000'0000b, 1100'0100_1100'0000b;,\;
        figNum          dw      ($ - figArr)/8 - 1




;#############GAME INITIALIZATION####################
proc Game.Initialize

        call    Random.Initialize

        ; clear screen
        mov     edx, FIELD_W - 2
        xor     al, al
        mov     ecx, FIELD_H - 1
        mov     edi, blocksArr + 1
.Clearloop:
        push    ecx
        mov     ecx, edx
        rep stosb
        pop     ecx

        inc     edi
        inc     edi
        loop    .Clearloop


        ; write score
        mov     word [Game.Score], 0; set score to 0
        stdcall Settings.GetHigh

        ; write high score
        movzx   eax, word [Game.HighScore]
        cinvoke wsprintfA, Str.HighScore, Str.Score.Format, eax
        ;write score
        movzx   eax, word [Game.Score]
        cinvoke wsprintfA, Str.Score, Str.Score.Format, eax

        ; TESTTESTTEST!!!!
        stdcall Settings.LdScoreboard
        ; ========================

        ; gen new fig
        stdcall Game.GenNewFig

        ; setup timer
        mov     [Game.TickSpeed], START_TICK_SPEED
        mov     [Game.Pause], TRUE;
        mov     [Game.Playing], TRUE;temp!!FALSE

        ; set music pos to start
        mov      [SoundPlayer.NextSound], 0

        mov     [Game.FigsPlaced], 0

        ; setup holded
        and     word [Game.Holded], FALSE;MY_FALSE; set ifhold to true
        mov     word [Game.HoldedFigNum], -1
        mov     word [Game.HoldedFig], 0

        ret
endp

;#############GEN NEW FIGURE####################
proc Game.GenNewFig

        ; setup start place
        mov     [Game.FigX], FIELD_W/2-2
        mov     [Game.FigY], FIG_START_Y ; -2
        mov     [Game.CurFigRotation], 0
        mov     [Game.FigPreviewY], 0

        ; setup new color
        movzx   eax, [colorsNum]
        stdcall Random.Get, 3, eax
        mov     [Game.CurFigColor], ax

        ; setup cur fig
        mov     ax, [Game.NextFigNumber]
        mov     [Game.CurFigNumber], ax
        mov     ax, [Game.NextFig]
        mov     [Game.CurFig], ax

        ; setup next fig
        movzx   eax, [figNum]
        stdcall Random.Get, 0, eax
        mov     [Game.NextFigNumber], ax
        movzx   ebx, ax
        shl     ebx, 3
        mov     ax, [figArr + ebx]
        mov     [Game.NextFig], ax

        ; update screen
        xor      eax, eax
        stdcall  Game.KeyEvent

        ret
endp

;############### KEY EVENT ############
; - processes a key code, stored in eax
proc Game.KeyEvent uses eax

        ; playsound
        cmp     eax, 7
        je      @F
        invoke  midiOutShortMsg, [midihandle], 0x006F2B99
        mov     eax, [esp]
@@:
        ; LD figure data and save initial fig state
        movzx   ecx, [Game.CurFigNumber]
        ; check if holded fig used
        cmp     eax, 'H'
        jne     .skipHold
        cmp     [Game.Holded], TRUE
        je      .skipHold
        ; hold
        or      word [Game.Holded], TRUE; set ifhold to true (1 hold per fig)
        movzx   ebx, cx; save cur fig num
        shl     bx, 3
        mov     bx, word [figArr + ebx]
        mov     word [Game.HoldedFig], bx

        ; swap cur and buffered
        xchg    word [Game.HoldedFigNum], cx
        cmp     cx, -1 ; if holded fig isnt set yet
        jne     @F
        push    eax
        stdcall Game.GenNewFig;; REGISTERS!!!!
        pop     eax
        movzx   ecx, word [Game.CurFigNumber]
@@:
        mov     word [Game.FigX], FIELD_W/2-2
        mov     word [Game.FigY], FIG_START_Y
        mov     word [Game.CurFigNumber], cx
.skipHold:
        xor     ebx, ebx
        ; get cords
        movzx   esi, word [Game.FigX] ; initial X
        movzx   edi, word [Game.FigY] ; initial Y

        ; get figure place at fig array
        shl     cx, 2; bc figs are stored as 2 bytes * 4 states
        mov     bx, cx; save cx
        mov     dx, [Game.CurFigRotation]

        ; game logics here
        ;push    eax
        ;mov     al, byte [Keyboard.Pressed]
        ; move left-right-rotate
        cmp     eax, VK_LEFT;'a'
        ;test    al, 0000'0100b
        jne     @F
        dec     si
@@:
        cmp     eax, VK_RIGHT ;'d'
        ;test    al, 0000'0001b
        jne     @F
        inc     si
@@:
        ;pop     eax
        ; decode key and apply rotation
        cmp     eax, VK_UP  ; rotation
        ;test    al, 0000'0010b
        jne     @F
        inc     dx
@@:
        cmp     eax, VK_DOWN ; rotation
        ;test    al, 0000'1000b
        jne     @F
        dec     dx
@@:
        and     dx, 0000'0000'0000'0011b ; masked rotation
        ; get figure (duplicated!)
        add     bx, dx ; apply rotation
        shl     bx, 1  ; each fig is 2 bytes long

        mov     bx, [figArr + ebx] ; is cur figure

        ; check collisions
        push    ebx esi edi edx eax ecx
        stdcall Game.CollideFigure
        test    ax, ax
        pop     ecx eax edx edi esi ebx

        jz      @F
        ; restore changes if collided
        mov     dx, [Game.CurFigRotation]
        add     cx, dx  ; apply rotation
        shl     cx, 1  ; each fig is 2 bytes long
        mov     bx, [figArr + ecx] ; is cur figure
        ; restore x cord
        mov     si, [Game.FigX] ; initial X


@@:
        ; check timer update
        cmp     eax, 7; reserved for timer update
        jne     @F
        inc     di
@@:
        ; save old di
        mov     word [Game.FigY], di
        dec     di
        ; go down loop
.GoDownLoop:
        inc     di
        ; check on collision
        push    eax ebx esi edx di
        stdcall Game.CollideFigure; esi - X edi - Y bx - FIG
        ;pop     edi ; reset Y to new
        ;inc     edi
        test    ax, ax
        pop     di edx esi ebx eax
        jz      .GoDownLoop
        ; collided
        dec     di
        ; speed up on space
        cmp     eax, ' '
        je      .Collided
        cmp     di, [Game.FigY]
        jl      .Collided
        ;jge     @F  ;  (were jb -- but error with neg nmbs)
        ; collided at initial cord
        ;cmp     eax, 7
        ;je      .Collided
        ; restore x cord
        ;mov     si, [Game.FigX] ; initial X
@@:
        ; save new di as preview Y
        mov     [Game.FigPreviewY], di


        ; noncollided
        ; EVERYTHING IS GOOD
        mov     [Game.FigX], si
        mov     [Game.CurFig], bx
        mov     [Game.CurFigRotation], dx
        jmp     .End_key_event

.Collided:
        ; 1st place figure
        mov     cl, byte [Game.CurFigColor]
        push    ebx esi edi edx
        stdcall Game.PlaceFigure
        ; temp playsnd
        push    eax
        invoke  midiOutShortMsg, [midihandle], 0x004F4399
        pop     eax

        pop     edx edi esi ebx
        ; score?
        ;sub     di, [Game.FigY]
        ;add     [Game.Score], di
        ; print res
        ;movzx   eax, word [Game.Score]
        ;cinvoke wsprintfA, Str.Score, Str.Score.Format, eax

        ; check on loose
        stdcall Game.CheckOnEnd
        xor     ax, 1
        test    ax, ax ; temp snd off
        jnz     @F
        ; play end snd temp
        mov     [SoundPlayer.EndGameTick], 4
        ;;;;;;;;;;;
        stdcall Game.End
        jmp     .End_key_event
@@:
        ; unblock hold usage
        and     word [Game.Holded], FALSE;MY_FALSE; set ifhold to true

        ; speed up
        ; inc counts of figure
        inc     [Game.FigsPlaced]
        ; encount new speed
        test    [Game.FigsPlaced], INC_EVERY_FIGS; 111; every 16 figs
        jnz     @F
        fild    [Game.TickSpeed]
        fld     [Game.SpeedMul]
        fmulp   st1, st0
        fistp   [Game.TickSpeed]
@@:
        ; check on scrore
        stdcall Game.CheckOnLine
        ; gen new fig (temp)
        stdcall Game.GenNewFig
        ;mov     [Game.FigY], 0

.End_key_event:
        ret
endp

;#############CHECK ON END OF GAME ####################
; - rets TRUE in ax if game ends
proc Game.CheckOnEnd uses ebx ecx

        xor     eax, eax

        mov     ecx, FIELD_W - 2
        mov     ebx, FIELD_W * TOP_LINE + 1; from TOP_LINE line
.CheckLoop:
        cmp     byte [ebx + blocksArr], 0
        je      @F
        mov     eax, TRUE
        jmp     .EndProc
@@:
        inc     ebx
        loop    .CheckLoop
.EndProc:
        ret
endp

;#############CHECK ON FULL LINES AND COUNT SCORE ####################
proc Game.CheckOnLine uses dx ebx ecx

        xor     ax, ax; score
        mov     ebx, 1           ; full w
        mov     ecx, FIELD_H - 1 ; full hei - 1
.CheckLoop:
        push    ecx
        push    ebx

        mov     ecx, FIELD_W - 2
.InnerCheckLoop:
        cmp     byte [ebx + blocksArr], 0
        je      .skipLine

        inc     ebx
        loop    .InnerCheckLoop
        ; if non skipped -- do changes
        ; make line glow (line mecanics)
        mov     edx, FIELD_H
        sub     edx, [esp + 4]; get ecx
        mov     byte [edx + glowArr], GLOW_TIME_TICKS
        ; rm line
        sub     ebx, FIELD_W
        mov     ecx, ebx
.RmLineLoop:
        mov     dl, byte [ebx + blocksArr]
        cmp     dl, $01; check if it is border block
        je      @F
        mov     [ebx + blocksArr + FIELD_W], dl
@@:
        dec     ebx
        loop    .RmLineLoop
        ; rm line end
        inc     ax; add score

.skipLine:
        pop     ebx
        add     ebx, FIELD_W

        pop     ecx
        loop    .CheckLoop
 ; END LOOP
        test    ax, ax  ; add score
        jz      .EndProc

        ;push    ax
        ;add     ax, 2
        ;mov     word [SoundPlayer.LineGameTick], ax
        ;pop     ax
        ; sound eff
        push    eax ecx edx
        mov     ecx, 0x007F0093
        mov     ch, al
        shl     ch, 2
        add     ch, 40
        ;mov     word [SoundPlayer.LineGameTick], ax
        invoke   midiOutShortMsg, [midihandle],  ecx ;
        pop     edx ecx eax
        ;  == == =

        mov     cx, 2;50   ; count
        xchg    ax, cx
        shl     ax, cl
        dec     ax
        shl     ax, 2
        ;mov     cx, [Game.Level]
        ;mul     CX

        add     [Game.Score], ax ; add

        ; play snd
        ;invoke  mciSendString, _wav_play, 0, 0, 0

        ;write score
        movzx   eax, word [Game.Score]
        cinvoke wsprintfA, Str.Score, Str.Score.Format, eax

.EndProc:
        ret
endp


;#############MOVES FIGURE TO FIELD ARRAY ####################
; - fig   -- 2 bytes figure
; - x     -- x cord
; - y     -- y cord
; - color -- fig color
;Game.PlaceFigure.Fig            bx
;Game.PlaceFigure.X              esi
;Game.PlaceFigure.Y              edi
;Game.PlaceFigure.Color          cl
;Game.PlaceFigure.Field          ???

proc Game.PlaceFigure ;uses eax ecx esi edi ebx

        ; prep cords
        mov     eax, FIELD_W
        mul     di ; WIDTH*Y
        add     si, ax; esi is cord in block matrix


        xchg    al, cl ; mov color to al
        mov     ecx, 16; setup loop

        ; inner loop -- line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        test    si, 0x80'00 ; check if Y cord < 0
        jnz     @F
        ; paste figure
        mov     byte [esi + blocksArr], al
@@:
        inc     si ; setup cords
        dec     ecx
        test    ecx, 0000'0000'0000'0000_0000'0000'0000'0011b; if % 4 => move to next line
        jnz     @F
        add     si, FIELD_W - 4
@@:
        inc     ecx
        loop    .DrawLoop

        ret
endp

;#############CHECK ON COLLISION####################
; - fig   -- 2 bytes figure
; - x     -- x cord
; - y     -- y cord
;View.CollideFigure.Fig             bx
;View.CollideFigure.X               esi
;View.CollideFigure.Y               edi;dw      ?

proc Game.CollideFigure ;uses ebx ecx eax edx esi edi
        ; prep cords
        mov     eax, FIELD_W
        mul     di
        add     si, ax; esi is cord in matrix

        ; result set
        xor     eax, eax

        mov     ecx, 16

        ; inner loop -- draw line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        test    si, 0x80'00 ; check if Y cord < 0
        jnz     @F
        ; check collision
        cmp     byte [esi + blocksArr], 0
        jne     .Collided
@@:
        inc     si; setup cords
        dec     ecx
        test    ecx, 0000'0000'0000'0000_0000'0000'0000'0011b
        jnz     @F
        add     si, FIELD_W - 4
@@:
        inc     ecx
        loop    .DrawLoop

        jmp     .EndProc
.Collided:
        mov     eax, TRUE
.EndProc:
        ret
endp




;#############GAME END ##############################
proc Game.End
        ; set playing false
        mov     [Game.Playing], FALSE
        ; temp CHEAT inc figy
        ;dec     [Game.FigY]
        ; stop music
        stdcall SoundPlayer.Pause
        ; check score if new high
        mov     cx, [Game.HighScore]
        mov     ax, word [Game.Score]
        cmp     ax, cx
        jle     @F
        ; save high scrore
        mov    [Game.HighScore], ax
        stdcall Settings.SetHigh
        ; write high score
        movzx   eax, word [Game.HighScore]
        cinvoke wsprintfA, Str.HighScore, Str.Score.Format, eax
@@:
        ret

endp
