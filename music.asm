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

        mov      esi, [midihandle]
        mov      edi, SoundPlayer.Instruments
        invoke   midiOutShortMsg, esi, dword [edi]
        invoke   midiOutShortMsg, esi, dword [edi + 4]
        invoke   midiOutShortMsg, esi, dword [edi + 8]
        invoke   midiOutShortMsg, esi, dword [edi + 12]
        ; gunshot
        invoke   midiOutShortMsg, esi, dword [edi + 16]

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
        jz      @F

        ; define sound tick update
        sub     ax, [SoundPlayer.CurTick]
        cmp     ax, 260; temp//180
        jb      @F
        add     [SoundPlayer.CurTick], ax

        ; get midi message
        mov      eax, 0x007F2590
        mov      ah, bl
        shl      ah, 2
        add      ah, 22
        ; play midi message
        invoke   midiOutShortMsg, [midihandle],  eax;

        mov      eax, 0x007F2591
        mov      ah, bl
        add      ah, 36
        invoke   midiOutShortMsg, [midihandle],  eax;


        dec     ebx
        mov     word [SoundPlayer.EndGameTick], bx
@@:
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
        stdcall SoundPlayer.PlayNextEx
@@:

        ret
endp


proc SoundPlayer.Pause

        mov     edi, [midihandle]
        invoke  midiOutShortMsg, edi, 0x00007BB0
        invoke  midiOutShortMsg, edi, 0x00007BB1
        invoke  midiOutShortMsg, edi, 0x00007BB2
        invoke  midiOutShortMsg, edi, 0x00007BB9

        ret
endp


proc SoundPlayer.PlayNextEx uses ebx
        ; sound here
        movzx    ebx, word [SoundPlayer.NextSound]

        mov      ecx, 4; num of players
.PlayPackOfNotes:
        push     ecx
        movzx    ecx, word [SoundPlayer.Notes + ebx]
        ;or       ecx, 0x007F0000
        or       ecx, [SoundPlayer.VolumeMask]
        invoke   midiOutShortMsg, [midihandle],  ecx

        add      ebx, NOTES_PACK_BYTES; 2 bytes per note
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
        or       ecx, 0x00000090  ; regulat midi msg
        or       ch, byte [SoundPlayer.Notes + ebx]
        test     ch, 1000'0000b
        jnz      @F
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
                        ; 1001 -- play; 1000 - stop; kkk - note num, vvv - volume
                        ;format 1001'nnnn   kk  0vvvvvvvv



