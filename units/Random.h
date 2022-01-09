;------------------------------------------------
; initialize random using cur time
Random.Initialize:
        ;mov     ah, 2Ch; get sys time
        ;int     21h    ; got seed in dx  (s and ms*10)   ???
        invoke GetTickCount ; tick time in rax

        mov     [Random.dSeed], eax
        mov     [Random.dPrewNumber], eax

        ret

proc Random.Get uses ecx edx,\; not nessesary to save cx dx
        dMin, dMax; dBounds - wMax'wMin

        ; pseudo random generator (A*x + B) mod N
        mov     eax, [Random.dPrewNumber]

        mov     ecx, 29;; A
        mul     ecx
        add     eax, 47;; B
        ;xor     edx, edx clear after mul

        mov     [Random.dPrewNumber], eax

        mov     ecx, [dMax]
        mov     edx, [dMin]
        sub     ecx, edx
        inc     ecx
        xor     edx, edx
        div     ecx

        mov     eax, edx
        mov     edx, [dMin]; wMin
        add     eax, edx

        ret
endp


;============other data=============
;Random.dPrewNumber      dd      ?