;.animation_ok:
        invoke  glClear, GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

        invoke  glLoadIdentity
   if VIEW_3D
        invoke  glTranslatef, -20.5, -12.0, -45.0;  // Move right and into the screen
   else
        invoke  glTranslatef, 0.0, 0.0, -40.0;
   end if
        movzx   eax, [View.MenuChosen]
        test    eax, eax
        je      .ViewMenu_1
        dec     eax
        test    eax, eax
        je      .ViewMenu_2
        dec     eax
        test    eax, eax
        je      .ViewMenu_3

        ; #####################
        ; #     -MENU #4-     #
        ; # draw help         #
        ; #####################
        HELP_DEFINED = TRUE; FALSE
        if (HELP_DEFINED)

   .ViewMenu_4:
        ; set font
        invoke  glListBase, [Wnd.nFontBase]
        ; draw text
        mov     ecx, Help.LEN
        mov     esi, Help.LPos
        mov     edi, Help.Str.LEN
   .DrawHelp:
        push    ecx
        sub     esi, edi
        stdcall View.DrawText, FIELD_W + 8 + 3, ecx, edi, eax, esi  ;X, Y, strlen, ANY, strptr
        pop     ecx
        loop    .DrawHelp
        jmp     .ViewMenu_End

        end if
        ; #####################
        ; #     -MENU #3-     #
        ; # draw chat         #
        ; #####################
   .ViewMenu_3:
        ; if font is not created -- create
        mov     esi, chat_font; ptr to font struct
        mov     eax, dword [esi]
        test    eax, eax
        jnz     @F
        mov     dword [esi + 4], 20; TIMED (SCREEN FONT DIV 2)
        stdcall View.CreateFont
    @@:
        invoke  glListBase, dword [esi]
        ; draw chat
        call    View.DrawChat

        ; Return text draw
        invoke  glListBase, [Wnd.nFontBase]

        jmp     .ViewMenu_End
        ; #####################
        ; #     -MENU #2-     #
        ; # draw other fields #
        ; #####################
   .ViewMenu_2:
        ; get scale factor
        xor     eax, eax ; pow
        xor     ebx, ebx ; scale f
        inc     ebx
        xor     ecx, ecx ; loop ctr
        mov     esi, Client.ClientsDataArr ;+ CLIENT_CL_RCD_LEN ; 2nd rcd (check if correspond to cur user?)
  .ClientsDataArrLoop:
        mov     dx, word [esi + NICKNAME_LEN] ; get ping
        test    dx, dx
        jz      .ClientsDataArrLoopEnd
        js      .ClientsDataArrLoopNext
        ; get rcd info
        ; skip if cur user rcd
        ; inc counter
        inc     ecx
        ; if ctr > pow
        cmp     ecx, eax
        jle     @F
        ; yes -- set new pow
        inc     ebx ; ??
        mov     eax, ebx
        mul     eax ; edx is corrypted here
@@:
   .ClientsDataArrLoopNext:
        add     esi, CLIENT_CL_RCD_LEN
        jmp     .ClientsDataArrLoop
   .ClientsDataArrLoopEnd:
        ; SET OFFSET
        mov     edi, sub_
        ; now scale factor is in ebx (int)
        cmp     dword [edi + (sub_scale - sub_)], ebx
        je      .PrevScaleIsOk
        mov     dword [edi + (sub_scale - sub_)], ebx  ; its buf (temp)
        fild    dword [edi + (sub_scale - sub_)]
        ; get rect sz here
        fld     dword [rect_size]
        fdiv    st0, st1
        fst     dword [edi + (sub_rect_size - sub_)]
        ; get font sz
        fchs
        fistp   dword [edi + (sub_font_sz - sub_)]
        ; get inverted scale
        fld1
        fdiv    st0, st1
        fstp    dword [edi + (sub_inv_scale_f - sub_)]
        fstp    dword [edi + (sub_scale_f - sub_)]
        ;fst     dword [sub_inv_scale_f]
        ;fstp    dword [sub_scale_f]
        ;mov     eax, 7F000000H
        ;sub     eax, dword [sub_inv_scale_f]
        ;mov     dword [sub_inv_scale_f], eax
        push    edi ; save sub_ offset
        ; create font DUPLICATED TEST!!!
        mov     esi, sub_font; ptr to font struct
        stdcall View.CreateFont

        ; restore sub_ offset
        pop     edi ; restore sub_ offset

        ; we're ready!
.PrevScaleIsOk:
        ; set font
        invoke  glListBase, [edi + (sub_font_base - sub_)]
        ; translate draw point
        invoke  glTranslatef, 22.0, 0.0, 0.0  ; DFIELD_W + 3 - 1 + 8 = 23
        ; scale
        invoke  glScalef, [edi + (sub_inv_scale_f - sub_)], [edi + (sub_inv_scale_f - sub_)], 1.0
        ; set draw
        invoke  glPointSize, [edi + (sub_rect_size - sub_)] ; pixels!!!!
        ; Now loop through ClientsDataArr again!
        xor     ebx, ebx ; loop ctr
        mov     esi, Client.ClientsDataArr ;+ CLIENT_CL_RCD_LEN ; 2nd rcd (check if correspond to cur user?)
  .ClientsDataArrLoop2:
        mov     dx, word [esi + NICKNAME_LEN] ; get ping
        test    dx, dx
        jz      .ClientsDataArrLoopEnd2
        js      .ClientsDataArrLoopNext2
        ; get rcd info
        ; skip if cur user rcd
        ; draw user
        stdcall View.DrawGame ; loop ctr in ebx, pos in esi+2 (save it)
        ; inc counter
        inc     ebx
@@:
   .ClientsDataArrLoopNext2:
        add     esi, CLIENT_CL_RCD_LEN
        jmp     .ClientsDataArrLoop2
   .ClientsDataArrLoopEnd2:
        ; restore sub_ offset
        mov     edi, sub_
        ; Scale Back
        invoke  glScalef, [edi + (sub_scale_f - sub_)], [edi + (sub_scale_f - sub_)], 1.0
        ; translate draw point back
        invoke  glTranslatef, -22.0, 0.0, 0.0  ; DFIELD_W + 3 - 1 + 8 = 23
        ; set rect sz back
        invoke  glPointSize, [rect_size] ; pixels!!!!
        ; Return text draw
        invoke  glListBase, [Wnd.nFontBase]

        jmp     .ViewMenu_End
        ; #####################
        ; #     -MENU #1-     #
        ; # draw leaderboard  #
        ; #####################
  .ViewMenu_1:
        ; set rect sz
        invoke  glPointSize, [rect_size] ; pixels!!!!
        ; text draw set
        invoke  glListBase, [Wnd.nFontBase]
        ; DRAW text SCOREBOARD
        stdcall View.DrawText, FIELD_W + 3 - 1 + 8, 2        , LB_ISTR_RCD_LEN  , eax, Str.Scoreboard
        ; DRAW Scoreboard
        stdcall View.DrawLeaderboard
        ; DRAW connections
        ;if (SERVER_DEFINED)
        stdcall View.DrawConnections
        ;end if
   .ViewMenu_End:
        ;#######################
        ;if (SERVER_DEFINED)
        ; check connection
        mov     ebx, Reconciliator.StrError
        mov     dx,  RECONCILIATOR_STR_LEN
        movzx   eax, word [Reconciliator.State]
        mul     dx
        add     ebx, eax
        ; DRAW text connection
        stdcall View.DrawText, FIELD_W + 3, FIELD_H, RECONCILIATOR_STR_LEN, eax, ebx
        ;end if

        ; draw background texture
        ;mov     ax, [Game.Pause]
        ;xor     ax, 1
        ;and     ax, [Game.Playing]
        cmp     [Game.Playing], 1
        je      @F

        invoke  glDisable, GL_LIGHTING
        xor     edi, edi
        xor     esi, esi
        inc     esi
        mov     ebx, 7.0
        invoke  glPushMatrix
        invoke  glTranslatef, ebx, ebx, edi
        invoke  glRotatef, [Glow.AnimAngle], edi, edi, ebx; esi
        invoke  glEnable, GL_TEXTURE_2D
        invoke  glBegin, GL_QUADS
                invoke  glTexCoord2i, esi, edi;edi, edi
                invoke  glVertex2i,  (FIELD_W - 2) / 2,  (FIELD_W - 2) / 2
                invoke  glTexCoord2i, edi, edi;edi, esi
                invoke  glVertex2i, -(FIELD_W - 2) / 2,  (FIELD_W - 2) / 2
                invoke  glTexCoord2i, edi, esi;esi, esi
                invoke  glVertex2i, -(FIELD_W - 2) / 2, -(FIELD_W - 2) / 2
                invoke  glTexCoord2i, esi, esi;esi, edi
                invoke  glVertex2i,  (FIELD_W - 2) / 2, -(FIELD_W - 2) / 2
        invoke  glEnd
        invoke  glDisable, GL_TEXTURE_2D
        invoke  glPopMatrix
        invoke  glEnable, GL_LIGHTING
   @@:
        ; draw
        ;invoke  glBegin, GL_POINTS

        ; draw next figure
        mov     bx,  word [Game.NextFig]
        mov     esi, FIELD_W + 3; X
        mov     edi, 2  ; Y
        stdcall View.DrawFigure, 3;//????
        ; draw holded figure
        mov     bx,  word [Game.HeldFig]
        mov     esi, FIELD_W + 3; X
        mov     edi, 2  +  4  +  2 ; Y
        stdcall View.DrawFigure, 3;//????

        ; apply rotation
        xor     ebx, ebx
        invoke  glPushMatrix
        invoke  glTranslatef, 6.5, 12.0, ebx      ; -20.5, -12.0, -45.0
        invoke  glRotatef, [View.FieldAngleDraw], ebx, 1.0, ebx
        invoke  glRotatef, [View.HFieldAngleDraw], 1.0, ebx, ebx
        invoke  glTranslatef, -6.5, -12.0, ebx

        ; draw preview figure
        mov     bx,  word [Game.CurFig]; figure
        movzx   esi, word [Game.FigX]  ; X
        push    ebx esi ; save
        movzx   edi, word [Game.FigPreviewY]  ; Y
        stdcall View.DrawFigure, 2
        ; draw figure
        pop     esi ebx
        movzx   edi, word [Game.FigY]  ; Y
        movzx   eax, byte [Game.CurFigColor]; movzx
        stdcall View.DrawFigure, eax


        ; end draw points
        ;invoke  glEnd

        ; draw field
        mov     eax, Game.BlocksArr
        stdcall View.DrawField
        ; draw glow
        stdcall View.DrawGlow

        invoke  glPopMatrix

        ; draw text NEXT FIG
        mov     esi, View.DrawText ; 24 bytes won
        stdcall esi, FIELD_W + 3 - 1, 2            , Str.NextFig.Len  , eax, Str.NextFig
        ; draw text HOLDED FIG
        stdcall esi, FIELD_W + 3 - 1, 2 + 6        , Str.HoldedFig.Len, eax, Str.HoldedFig
        ; DRAW text SCORE
        stdcall esi, FIELD_W + 3    , 2 + 4 + 6 + 2, SCORE_LEN_CONST  , eax, Str.Score
        ; DRAW text SCORE HIGH
        stdcall esi, FIELD_W + 3    , 2 + 4 + 6 + 3, SCORE_LEN_CONST  , eax, Str.HighScore

        ; Draw CurNickName
        stdcall esi, FIELD_W + 3 - 1 + 1, FIELD_H - 3, 8, eax, Game.NickName
        ; Draw TmpNickName
        mov     ebx, Settings.strTempNickNameBlocked
        ; If setup mode activated
        test    [Settings.SetupNickNameActive], TRUE
        jz      @F
        ; set str
        mov     ebx, Settings.strTempNickName
        ; set Special color
        mov     eax, 1.0
        invoke  glColor3f, eax, ebx, ebx
        ; Draw HighLight
        invoke  glRasterPos2f, 15.0 , 21.7 ;FIELD_W + 3 - 1 , FIELD_H - 1 + 1;
        invoke  glCallLists, 8, GL_UNSIGNED_BYTE, Settings.strTempNickNameHighlight
        ; set Special color
        stdcall View.FastWhiteColor
@@:
        ; Draw Main Str
        stdcall esi, FIELD_W + 3 - 1 + 1, FIELD_H - 2, 8, eax, ebx

        cmp     [Game.Playing], 1
        je      @F
        ; DRAW text GAME OVER
        stdcall esi, FIELD_W / 2 - 2, 2, 9, eax, Str.Loose
        jmp     .end_draw
@@:
        cmp     [Game.Pause], 1
        jne     @F
        ; DRAW text PAUSE
        stdcall esi, FIELD_W / 2 - 1, 2, 6, eax, Str.Pause
@@:
        ; end draw;
.end_draw: