;------------------------------------------------
; initialize random using cur time
Random.Initialize:
        ;mov     ah, 2Ch; get sys time
        ;int     21h    ; got seed in dx  (s and ms*10)   ???
        invoke GetTickCount ; tick time in rax

        mov     [Random.dSeed], eax
        mov     [Random.dPrewNumber], eax

        ret

; ###################################################
; [in, stack], min double value - minimum of random value diapason
; [in, stack], max double value - maximum of random value diapason (included)
proc Random.Get uses ecx edx,\; not necessary to save cx dx
        dMin, dMax; dBounds - wMax'wMin

        stdcall Random.GetMax

        mov     ecx, [dMax]
        mov     edx, [dMin]
        sub     ecx, edx
        inc     ecx ; to do "included" range
        xor     edx, edx
        div     ecx

        mov     eax, edx
        mov     edx, [dMin]; wMin
        add     eax, edx

        ret
endp

proc Random.GetMax uses ecx edx ; uses eax, edx, ecx

        ; pseudo random generator (A*x + B) mod N
        mov     eax, [Random.dPrewNumber]

        mov     ecx, 29;; A
        mul     ecx
        add     eax, 47;; B
        ;xor     edx, edx clear after mul

        mov     [Random.dPrewNumber], eax

        ret
endp