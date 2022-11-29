        TOP_LINE                = 0;1
        FIG_START_Y             = -1;-2

        SPECIAL_PRICE           = 100

;#############GAME FIELD CLR ########################
proc Game.IniField

        ; clear screen
        mov     edi, Game.BlocksArr
        xor     eax, eax; set edx to 0
        inc     eax     ; set eax to 1
        mov     ecx, FIELD_H - 1
.Clearloop:
        stosb
        add     edi, FIELD_W - 2
        stosb

        loop    .Clearloop

        mov     ecx, FIELD_W
        rep stosb

        ret
endp


;#############GAME FIELD CLR ########################
proc Game.ClearField

        ; clear screen
        mov     ecx, FIELD_H - 1
        mov     edx, GLOW_TIME_TICKS
.Clearloop:
        ; make line glow (line mecanics)
        ; set glow time
        mov     ebx, FIELD_H
        sub     ebx, ecx
        ; count glow time
        push    edx
        ;shl     ebx, 1
        add     edx, ebx
        ;shr     ebx, 1
        mov     byte [ebx + Glow.Arr], dl
        pop     edx

        loop    .Clearloop

        ret
endp

;#############GAME INITIALIZATION####################
proc Game.Initialize

        stdcall Game.ClearField

        ; reset time
        mov     [Game.TicksPlayed], 0

        ; write score
        mov     word [Game.Score], 0; set score to 0
        mov     eax, Game.NickName
        stdcall Settings.GetHigh ; ret in eax
        mov     word [Game.HighScore], ax

        ; write high score
        cinvoke wsprintfA, Str.HighScore, Str.Score.Format, eax
        ;write score
        movzx   eax, word [Game.Score]
        cinvoke wsprintfA, Str.Score, Str.Score.Format, eax

        ; TESTTESTTEST!!!!
        ;stdcall Settings.LdScoreboard
        push    Settings.ListAllTTRFiles.LBline
        stdcall Settings.ListAllTTRFiles
        ; ========================

        ; gen new fig
        mov     [Game.NextFigCtr], 0 ; set fig buf to 0 -- major bug fix!
        stdcall Game.GenNewFig ; its for ini new fig -> cur fig
        stdcall Game.GenNewFig
        ; set preview Y to max (prevent bugs)
        mov     [Game.FigPreviewY], FIG_START_Y

        ; setup timer
        mov     [Game.TickSpeed], START_TICK_SPEED
        mov     [Game.Pause], TRUE;
        mov     [Game.Playing], TRUE;temp!!FALSE

        ; set music pos to start
        mov     [SoundPlayer.NextSound], 0

        mov     [Game.FigsPlaced], 0

        ; setup holded
        and     word [Game.Holded], FALSE;MY_FALSE; set ifhold to true
        mov     word [Game.HoldedFigNum], -1
        mov     word [Game.HoldedFig], 0

        ret
endp

;#############GEN FIG SEQUENCE #################
proc Game.GenSequence

        mov     esi, Game.NextFigNumber

        mov     ecx, figNum + 1 ; i
.gen_loop:
        ; set loop ctr
        dec     ecx
        ; get j
        stdcall Random.Get, ecx, figNum; got j
        ; arr[i] = arr[j];
        shl     eax, 1
        shl     ecx, 1
        mov     dx, word [esi + eax]
        mov     word [esi + ecx], dx
        ; arr[j] = i;
        shr     ecx, 1
        mov     [esi + eax], cx
        ; reset loop ctr
        inc     ecx
        loop    .gen_loop

        ; reset ctr
        mov     [Game.NextFigCtr], figNum

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
        mov     eax, colorsNum
        stdcall Random.Get, 3, eax
        mov     [Game.CurFigColor], ax

        ; setup cur fig
        mov     ax, [Game.NextFigNumber]
        mov     [Game.CurFigNumber], ax
        mov     ax, [Game.NextFig]
        mov     [Game.CurFig], ax

        ; setup next fig
        cmp     [Game.NextFigCtr], 0
        jnz     .hasNextFig
.hasNotNextFig:
        stdcall Game.GenSequence
        jmp     .endnext
.hasNextFig:
        dec     [Game.NextFigCtr]
        ; move sequence of figs
        mov     ecx, figNum
        mov     esi, Game.NextFigNumber + 2
        mov     edi, Game.NextFigNumber
        rep movsw
.endnext:
        ; get fig bits
        movzx   ebx, word [Game.NextFigNumber]
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
; - Special control codes:
;   - Game update               - 7
;   - Ignore downward collision - 0 (only for actual figure, not preview)
proc Game.KeyEvent uses eax

        ; playsound
        cmp     eax, 7
        je      @F
        cmp     eax, VK_SHIFT
        je      @F
        invoke  midiOutShortMsg, [midihandle], 0x006F2B99
        mov     eax, [esp]
@@:
        ; Check if special used
        cmp     eax, VK_RETURN
        jne     .skipSpecial
        cmp     [Game.Score], SPECIAL_PRICE
        jl      .skipSpecial
        ; Special effect
        ; block buffer
        ;or      word [Game.Holded], TRUE
        ; rm some score
        sub     [Game.Score], SPECIAL_PRICE
        ;write score
        movzx   eax, word [Game.Score]
        cinvoke wsprintfA, Str.Score, Str.Score.Format, eax

        ; Do special
        invoke  midiOutShortMsg, [midihandle], 0x007F2594

        ; rm lines
        stdcall Game.ClearField
        ; rm N random lines
        ;mov     edx, FIELD_W
        ;mov     ecx, SPECIAL_NUM_LINES_RM; N
;.rmRandomLinesLoop:
        ;push    ecx ; save loop ctr
        ;stdcall Random.Get, TOP_LINE + 1, FIELD_H - 1 ; line num in eax
        ;push    eax ; save line num (specific stack depth required)
        ;neg     dword [esp]
        ;add     dword [esp], FIELD_H
        ;push    eax
        ;mov     eax, [esp]
        ; mul by FIELD_W
        ;mov     edx, FIELD_W
        ;mul     edx
        ;xchg    ebx, eax

        ;stdcall Game.RmLine ;req eax -- line num & ebx -- pos in field arr
        ;pop     eax eax
        ;pop     ecx
        ;loop    .rmRandomLinesLoop

.skipSpecial:

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
        test    cx, cx ; if holded fig isnt set yet
        jns     @F     ; works if figs < 127
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
        dec     dx ; inc
@@:
        cmp     eax, VK_DOWN ; rotation
        ;test    al, 0000'1000b
        jne     @F
        inc     dx ; dec
@@:
        and     dx, 0000'0000'0000'0011b ; masked rotation

Game.KeyEvent.NonKeyPositionChange: ; bx is fig, esi edi - cords
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
        test    eax, eax ; if start update
        jz      @F ; skip collision
        cmp     eax, ' '
        je      .Collided
        cmp     di, [Game.FigY]
        jl      .Collided ; collided at initial cord
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
        test    eax, eax ; temp snd off
        pop     eax
        jz      @F
        ; play end snd temp
        mov     [SoundPlayer.EndGameTick], 4
        jmp     Game.End
@@:
        push    eax
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
        or      al, byte [ebx + Game.BlocksArr];, 0
        inc     ebx
        loop    .CheckLoop
.EndProc:
        ret
endp

;#############REMOVES SINGLE LINE  ###################################
; - line num         -- as param in stack
; - pos in field arr -- ebx
proc Game.RmLine

        ; make line glow (line mecanics)
        mov     edx, FIELD_H
        sub     edx, [esp + 4 + 4]; get ecx (line num) (secondary '+' is for stack frame)
        mov     byte [edx + Glow.Arr], GLOW_TIME_TICKS
        ; rm line
        sub     ebx, FIELD_W
        mov     ecx, ebx
.RmLineLoop:
        mov     dl, byte [ebx + Game.BlocksArr]
        cmp     dl, $01; check if it is border block
        je      @F
        mov     [ebx + Game.BlocksArr + FIELD_W], dl
@@:
        dec     ebx
        loop    .RmLineLoop

        ret
endp

;#############CHECK ON FULL LINES AND COUNT SCORE ####################
proc Game.CheckOnLine uses dx ebx ecx

        xor     eax, eax; score
        mov     ebx, 1           ; full w
        mov     ecx, FIELD_H - 1 ; full hei - 1
.CheckLoop:
        push    ecx
        push    ebx

        mov     ecx, FIELD_W - 2
.InnerCheckLoop:
        cmp     byte [ebx + Game.BlocksArr], 0
        je      .skipLine

        inc     ebx
        loop    .InnerCheckLoop
        ; if non skipped -- do changes
        stdcall Game.RmLine

        ; rm line end
        inc     eax; add score

.skipLine:
        pop     ebx
        add     ebx, FIELD_W

        pop     ecx
        loop    .CheckLoop
 ; END LOOP
        test    eax, eax  ; add score
        jz      .EndProc

        ;push    ax
        ;add     ax, 2
        ;mov     word [SoundPlayer.LineGameTick], ax
        ;pop     ax
        ; sound eff
        push    eax ecx edx
        ; BANG EFFECT
        cmp     al, 4
        jl      @F
        push    eax
        mov     ecx, 0x007F2594
        stdcall Settings.Music.Play
        ;invoke  midiOutShortMsg, [midihandle], 0x007F2594
        pop     eax
@@:
        mov     ecx, 0x007F0093
        mov     ch, al
        shl     ch, 2
        add     ch, 40
        ;mov     word [SoundPlayer.LineGameTick], ax
        ;invoke   midiOutShortMsg, [midihandle],  ecx ;
        stdcall Settings.Music.Play
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
;Game.PlaceFigure.X              esi, hi word is zero!
;Game.PlaceFigure.Y              edi, hi word is zero!
;Game.PlaceFigure.Color          cl
;Game.PlaceFigure.Field          ???

proc Game.PlaceFigure ;uses eax ecx esi edi ebx

        ; prep cords
        mov     eax, FIELD_W
        mul     di ; WIDTH*Y
        add     si, ax; esi is cord in block matrix


        xchg    al, cl ; mov color to al
        xor     ecx, ecx
        mov     cl, 16; setup loop

        ; inner loop -- line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        test    si, si ; check if cord < 0
        js      @F
        ; paste figure
        mov     byte [esi + Game.BlocksArr], al
@@:
        inc     esi ; setup cords
        dec     ecx
        test    cl, 0000'0011b; if % 4 => move to next line
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
;View.CollideFigure.X               esi, hi word is zero!
;View.CollideFigure.Y               edi, hi word is zero!

proc Game.CollideFigure ;uses ebx ecx eax edx esi edi
        ; prep cords
        mov     eax, FIELD_W
        mul     di
        add     si, ax; esi is cord in matrix

        ; result set
        xor     eax, eax
        ; loop cnt
        xor     ecx, ecx
        mov     cl, 16; setup loop

        ; inner loop -- draw line of matrix
.DrawLoop:
        shl     bx, 1
        jae     @F ; CF = 0 => exit
        test    si, si ; check if cord < 0
        js      @F
        ; check collision
        cmp     byte [esi + Game.BlocksArr], 0
        jne     .Collided
@@:
        inc     si; setup cords
        dec     ecx
        test    cl, 0000'0011b
        jnz     @F
        add     si, FIELD_W - 4
@@:
        inc     ecx
        loop    .DrawLoop

        jmp     .EndProc
.Collided:
        ;mov     eax, TRUE
        inc     eax
.EndProc:
        ret
endp




;#############GAME END ##############################
proc Game.End
        xor     eax, eax
        ; set playing false
        cmp     [Game.Playing], ax
        je      @F
        mov     [Game.Playing], ax
        ; set rotation to initial pos
        mov     [Glow.AnimAngle], eax
        ; stop music
        stdcall SoundPlayer.Pause
        ; set random end effect
        stdcall Random.Get, 1, 4
        mov     [Game.randomEndSpecialId], ax
        ; call here effect ???

        ; === game cost
        ; check score if new high
        mov     cx, [Game.HighScore]
        movzx   eax, word [Game.Score]
        cmp     ax, cx
        jle     @F
        ; save high scrore
        mov     [Game.HighScore], ax
        mov     edx, Game.NickName
        push    FILE_SZ_TO_WRITE
        ; count cur state control sum
        stdcall Settings.SetHigh ; returns score in eax
        ; print new high score
        cinvoke wsprintfA, Str.HighScore, Str.Score.Format, eax
@@:
        ret

endp
