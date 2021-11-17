midihandle                      dd      ?
SoundPlayer.CurTick             dw      ?
SoundPlayer.DeltaTick           dw      180;?

;SoundPlayer.CurEventTick        dw      ?
SoundPlayer.EndGameTick         dw      ?
;SoundPlayer.LineGameTick        dw      ?

NOTES_PACK_BYTES                = 2; 9

proc SoundPlayer.Ini

        xor     ebx, ebx
        invoke  midiOutOpen, midihandle, ebx, ebx, ebx, ebx; last CALLBACK_NULL

        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments]
        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments + 4]
        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments + 8]
        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments + 12]

        ;/* Close the MIDI device */
        ;invoke  midiOutClose, [midihandle];
        ;mov      [SoundPlayer.CurTick], 0
        ;mov      [SoundPlayer.CurEventTick], 0
        mov      [SoundPlayer.EndGameTick], 0
        ;mov      [SoundPlayer.LineGameTick], 0

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
        stdcall SoundPlayer.PlayNextEx
@@:

        ret
endp


proc SoundPlayer.Pause

        invoke  midiOutShortMsg, [midihandle], 0x00007BB0
        invoke  midiOutShortMsg, [midihandle], 0x00007BB1
        invoke  midiOutShortMsg, [midihandle], 0x00007BB2
        invoke  midiOutShortMsg, [midihandle], 0x00007BB9

        ret
endp


proc SoundPlayer.PlayNextEx uses ebx
        ; sound here
        movzx    ebx, word [SoundPlayer.NextSound]

        mov      ecx, 4; num of players
.PlayPackOfNotes:
        push     ecx
        movzx    ecx, word [SoundPlayer.Notes + ebx]
        or       ecx, 0x007F0000
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



SoundPlayer.NextSound        dw      0
                        ; 1001 -- play; 1000 - stop; kkk - note num, vvv - volume
                        ;format 1001'nnnn   kk  0vvvvvvvv

SoundPlayer.Notes         file    'tetris_ex.amid'
SoundPlayer.NotesNum:     ; this pos - 2 bytes

SoundPlayer.Instruments   db    1100'0000b or 0, 32, 0, 0,\ ; 32 25 25 10
                                1100'0000b or 1, 25, 0, 0,\; formatt 1100'nnnn n - channel no, instr no, 0, 0
                                1100'0000b or 2, 25, 0, 0,\
                                1100'0000b or 3, 10, 0, 0



