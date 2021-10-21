midihandle                      dd      ?
SoundPlayer.CurTick             dw      ?
SoundPlayer.DeltaTick           dw      180;?

;SoundPlayer.CurEventTick        dw      ?
SoundPlayer.EndGameTick         dw      ?
;SoundPlayer.LineGameTick        dw      ?

NOTES_PACK_BYTES        = 4; 9

proc SoundPlayer.Ini

        xor     ebx, ebx
        invoke  midiOutOpen, midihandle, ebx, ebx, ebx, ebx; last CALLBACK_NULL

        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments]
        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments + 4]
        invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments + 8]
        ;invoke   midiOutShortMsg, [midihandle], dword [SoundPlayer.Instruments + 12]
        ;invoke  midiOutLongMsg, [midihandle], SoundPlayer.Instruments, 16

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

proc SoundPlayer.Update

        ; in eax is cur tick
        ; define sound tick update
        sub     ax, [SoundPlayer.CurTick]
        cmp     ax, [SoundPlayer.DeltaTick]; temp//180
        jb      @F
        add     [SoundPlayer.CurTick], ax
        ; play single snd tmp
        stdcall SoundPlayer.PlayNext
@@:

        ret
endp


proc SoundPlayer.PlayNext uses ebx

        ; sound here
        movzx    ebx, word [SoundPlayer.NextSound]

        mov      ecx, 4; num of players
.PlayPackOfNotes:
        push     ecx
        ; get midi message
        mov      edi, dword [SoundPlayer.Notes + ebx]
        ;mov      eax, edi ; TMPPP
        ;and      eax, $00'FF'FF'FF; rm elder byte
        ; play midi message
        invoke   midiOutShortMsg, [midihandle],  edi;0x007F1090;
        add      ebx, NOTES_PACK_BYTES
        pop      ecx
        loop     .PlayPackOfNotes
        ; read byte of wait time??
        ; get delta tick
        mov      eax, edi
        shr      eax, 24 - 1
        mov      [SoundPlayer.DeltaTick], ax

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

SoundPlayer.Notes         file    'tetris.amid'
SoundPlayer.NotesNum:     ; this pos - 2 bytes

SoundPlayer.Instruments   db    1100'0000b or 0, 32, 0, 0,\
                                1100'0000b or 1, 25, 0, 0,\; formatt 1100'nnnn n - channel no, instr no, 0, 0
                                1100'0000b or 2, 25, 0, 0



