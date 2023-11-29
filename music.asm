;midihandle                      dd      ?
;SoundPlayer.CurTick             dw      ?
;SoundPlayer.DeltaTick           dw      ?

;SoundPlayer.CurEventTick        dw      ?
;SoundPlayer.EndGameTick         dw      ?
;SoundPlayer.LineGameTick        dw      ?

NOTES_PACK_BYTES                = 2; 9

proc SoundPlayer.Ini

        xor     ebx, ebx
        invoke  midiOutOpen, midihandle, ebx, ebx, ebx, ebx; last CALLBACK_NULL

        mov      edi, [midihandle]
        mov      esi, SoundPlayer.Instruments
        ; inefficient but compact
        mov      ebx, SoundPlayer.Instruments.Len
.loadInstruments:
        ;xor      eax, eax ; TODO danger??
        lodsw
        invoke   midiOutShortMsg, edi, eax
        dec      ebx
        jnz     .loadInstruments

        ;/* Close the MIDI device */
        ;invoke  midiOutClose, [midihandle];
        ;mov      [SoundPlayer.CurTick], 0
        ;mov      [SoundPlayer.CurEventTick], 0
        mov      [SoundPlayer.EndGameTick], 0
        ;mov      [SoundPlayer.LineGameTick], 0
        mov      [SoundPlayer.Volume], 0x7F

        ret

endp

proc SoundPlayer.Close

        invoke  midiOutClose, [midihandle];

        ret
endp

proc SoundPlayer.EndEventUpdate; got eax in [esp] as param

        movzx   ebx, word [SoundPlayer.EndGameTick]
        test    ebx, ebx
        jz      .ExitProc

        ; define sound tick update
        sub     ax, [SoundPlayer.CurTick]
        cmp     ax, 260; temp//180
        jb      .ExitProc
        add     [SoundPlayer.CurTick], ax

        ;mov     ecx, ebx
        ;stdcall Settings.Music.Play

        ; get midi message
        mov      ecx, 0x007F2590
        mov      ch, bl
        shl      ch, 2
        add      ch, 22
        ; play midi message
        push     ecx
        invoke   midiOutShortMsg, [midihandle],  ecx;
        pop      ecx
        ; check if end game effect required
        cmp      bl, byte [Game.randomEndSpecialId]
        jne      @F
        stdcall  Settings.Music.Play
@@:

        mov      eax, 0x007F2591
        mov      ah, bl
        add      ah, 36
        invoke   midiOutShortMsg, [midihandle],  eax;


        dec     ebx
        mov     word [SoundPlayer.EndGameTick], bx
.ExitProc:
        ret
endp

proc SoundPlayer.Update

        ; in eax is cur tick
        ; define sound tick update
        sub     ax, [SoundPlayer.CurTick]
        cmp     ax, [SoundPlayer.DeltaTick]; temp//180
        jb      @F
        add     [SoundPlayer.CurTick], ax
        ; play single snd tmp
        ;stdcall SoundPlayer.Pause
        stdcall SoundPlayer.PlayNextNNEx
@@:

        ret
endp


proc SoundPlayer.Pause

        mov     edi, [midihandle]
        mov     esi, dword [midiOutShortMsg]
        mov     ecx, SoundPlayer.Instruments.Len
        mov     eax, 0x00007BB0
.PauseLoop:
        push    eax ecx
        dec     ecx
        or      eax, ecx
        stdcall esi, edi, eax
        pop     ecx eax
        loop .PauseLoop
        ;stdcall esi, edi, 0x00007BB0
        ;stdcall esi, edi, 0x00007BB1
        ;stdcall esi, edi, 0x00007BB2
        ;stdcall esi, edi, 0x00007BB9

        ret
endp


proc SoundPlayer.PlayNextEx uses ebx
        ; sound here
        movzx    ebx, word [SoundPlayer.NextSound]

        mov      ecx, 4; num of players
.PlayPackOfNotes:
        push     ecx
        movzx    ecx, word [SoundPlayer.Notes + ebx]
        or       ecx, [SoundPlayer.VolumeMask]
        invoke   midiOutShortMsg, [midihandle],  ecx

        ;add      ebx, NOTES_PACK_BYTES; 2 bytes per note
        inc      ebx
        inc      ebx
        pop      ecx
        loop     .PlayPackOfNotes

        ; get delta tick
        movzx    ax, byte [SoundPlayer.Notes + ebx]
        shl      ax, 1
        mov      [SoundPlayer.DeltaTick], ax
        inc      ebx

        cmp      bx, word [SoundPlayer.NotesNum - 2]
        jl       @F
        xor      ebx, ebx
@@:
        mov      [SoundPlayer.NextSound], bx

        ret
endp

proc SoundPlayer.PlayNextSEx uses ebx
        ; sound here
        movzx    ebx, word [SoundPlayer.NextSound]

        mov      ecx, 4; num of players
.PlayPackOfNotes:
        push     ecx
        dec      ecx
        neg      ecx
        test     ecx, ecx
        jnz      @F
        add      ecx, 6
@@:
        add      ecx, 3

        ;movzx    ecx, byte [SoundPlayer.Notes + ebx]
        or       ecx, [SoundPlayer.VolumeMask]
        or       cl, 0x90  ; regulat midi msg
        or       ch, byte [SoundPlayer.Notes + ebx]
        test     ch, ch ; 1000'0000b
        js       @F
        xor      cl, 0x30
@@:
        and      ch, 0111'1111b
        invoke   midiOutShortMsg, [midihandle],  ecx

        inc      ebx ;add      ebx, NOTES_PACK_BYTES / 2; 1 byte per note
        pop      ecx
        loop     .PlayPackOfNotes

        ; get delta tick
        movzx    ax, byte [SoundPlayer.Notes + ebx]
        shl      ax, 1
        mov      [SoundPlayer.DeltaTick], ax
        inc      ebx

        cmp      bx, word [SoundPlayer.NotesNum - 2]
        jl       @F
        xor      ebx, ebx
@@:
        mov      [SoundPlayer.NextSound], bx

        ret
endp

proc SoundPlayer.PlayNextNNEx uses esi edi
        ;
        ;stdcall  SoundPlayer.Pause
        ; sound here
        movzx    edx, word [SoundPlayer.NextSound]
        lea      esi, [SoundPlayer.Notes + edx]
        mov      ecx, 8 - (SOUNDPLAYER_BITS_FOR_TIME + 1) ; 1 bit set - if 16 bits used
        ; check first 2 bytes
        ;xor      eax, eax
        ;lodsw
        ;shr      eax, 1 ; if it is long
        ;
        ; check first 2 bytes
        xor      eax, eax
        lodsb
        test     al, 1
        jz       @F
        add      ecx, 8
        dec      esi ; move ptr back
        lodsw        ; load word instead of byte
@@:
        shr      eax, 1  ; skip 1 bit
        push     ecx
        ;
        mov      ecx, eax
        and      ecx, (1 shl SOUNDPLAYER_BITS_FOR_TIME) - 1
        shr      eax, SOUNDPLAYER_BITS_FOR_TIME
        ;
        mov      edx, SOUNDPLAYER_MIN_DTIME ; max delta tick  encoded
        shl      edx, cl ; shr???
        mov      [SoundPlayer.DeltaTick], dx ; set delay
        ;
        pop      ecx
        mov      edx, eax
        ;
.PlayLoop:
        shr      edx, 1
        jnc      .ToNextChannel ; CF = 0 => next
        ;
        ; save ctrs
        push     ecx edx
        dec      ecx  ; bc channels are numerated from 0
        ;
        xor      eax, eax
        lodsb    ; load note num
        ; 1) check if it is a pack of notes
        test     al ,al
        jns      .NotAPAck
        ;
        not      al
        inc      dword [esp + 4] ; ecx
        shl      dword [esp], 1  ; set bit of edx again
        inc      dword [esp]
        ;
.NotAPAck:
        ; 2) check if pause
        test     al, 0x40
        jz       .ItsAPAuse
        ;
        and      al, 0x3F
        or       eax, [SoundPlayer.VolumeMask] ; TODO duplicated
.ItsAPAuse:
        ;
;if (SOUNDPLAYER_CHANNEL_BASED)
        add      al, [SoundPlayer.ChannelBaseNotes + ecx]
;end if
        ;
        shl      eax, 8
        or       eax, 0x00'00'00'90
        ;
if (SOUNDPLAYER_SPECIAL_CHANNEL <> 9)
        cmp      ecx, SOUNDPLAYER_SPECIAL_CHANNEL ; TOGGLE THIS OPTIMIZATION IF NEEDED (3 is encoded channal of special 9 channal - 1 byte less data)
        jne      .NotSpecialChannelA
        mov      cl, 9
.NotSpecialChannelA:
if (SOUNDPLAYER_IGNORE_SPECIAL = 1)
        cmp      ecx, 9 ; TOGGLE THIS OPTIMIZATION IF NEEDED (3 is encoded channal of special 9 channal - 1 byte less data)
        jne      .NotSpecialChannelB
        mov      cl, SOUNDPLAYER_SPECIAL_CHANNEL
.NotSpecialChannelB:
end if
end if
        or       eax, ecx
        ;
if (SOUNDPLAYER_FORCE_PAUSE = 1)
        mov      edx, 0x00007BB0
        or       edx, ecx
        push     eax
        invoke   midiOutShortMsg, [midihandle], edx    ; force pause
        pop      eax
end if
        invoke   midiOutShortMsg, [midihandle], eax
        pop      edx ecx
.ToNextChannel:
        loop     .PlayLoop

        ; get next pos
        sub      esi, SoundPlayer.Notes
        cmp      esi, Soundplayer.Len
        jl       @F
        xor      esi, esi
@@:
        mov      [SoundPlayer.NextSound], si

        ret
endp


proc SoundPlayer.PlayNextNEx uses esi edi
        ;
        stdcall  SoundPlayer.Pause
        ; sound here
        movzx    edx, word [SoundPlayer.NextSound]
        lea      esi, [SoundPlayer.Notes + edx]
        mov      ecx, 8 - 3
        ; check first 2 bytes
        ;xor      eax, eax
        ;lodsw
        ;shr      eax, 1 ; if it is long
        ;
        ; check first 2 bytes
        xor      eax, eax
        lodsb
        test     al, 1
        jz       @F
        add      ecx, 8
        xchg     ah, al
        lodsb
        xchg     ah, al
@@:
        shr      eax, 1
        ;jc       @F
       ; dec      esi
        ;sub      ecx, 8
        ;shr      eax, 8
;@@:
        push     ecx
        ;
        xor      ecx, ecx
        shrd     ecx, eax, 2 ; its a tick multiplier
        rol      ecx, 2
        shr      eax, 2
        ;
        mov      edx, 100 ; min delta tick
        shl      edx, cl
        mov      [SoundPlayer.DeltaTick], dx ; set delay
        ;
        pop      ecx
        mov      edx, eax
        ;
.PlayLoop:
        shr      edx, 1
        jnc      @F ; CF = 0 => next
        ;
        xor      eax, eax
        lodsb    ; load note num
        shl      eax, 8
        or       eax, [SoundPlayer.VolumeMask]
        or       eax, 0x00'00'00'90
        ;
        push     ecx edx
        ;
        dec      ecx
        cmp      ecx, 3 ; channel of 9
        jne      .NotSpecialChannel
        mov      cl, 9
.NotSpecialChannel:
        or       eax, ecx
        ;
        invoke   midiOutShortMsg, [midihandle], eax
        pop      edx ecx
@@:
        loop     .PlayLoop
        ; get next pos
        sub      esi, SoundPlayer.Notes
        cmp      esi, Soundplayer.Len
        jl       @F
        xor      esi, esi
@@:
        mov      [SoundPlayer.NextSound], si
        ret
endp



