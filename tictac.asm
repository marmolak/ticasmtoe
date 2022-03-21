bits 16
org 0x100

%define VIDEO_MEM 0xb800

%define next_screen (80 * 25 * 2)

%macro set_text_mode 0
    mov al, 0x03
    int 0x10
%endmacro

; we are on second screen
%macro set_playground_parts 5
    render_sprite next_screen, (%1), 18, (%2), (%3), (%4), (%5)
%endmacro

%macro render_sprite 7
    ;       skips first part ;rows           ; columns
    mov di, ((%1) + (80 * (%2) * 2) + ((%3) * 2))
    mov dx, %4
    mov ah, %5
    mov si, %6
    mov cx, %7
    call fill_with_pattern
%endmacro


section .data
delay_val: db 0

logo    db "          _                _    _           ", 0
        db "         | |              | |  ( )          ", 0
        db "     _ __| |__   __ _  ___| | _|/ ___       ", 0
        db "    | '__| '_ \ / _` |/ __| |/ / / __|      ", 0
        db "    | |  | | | | (_| | (__|   <  \__ \      ", 0
        db "    |_|  |_| |_|\__,_|\___|_|\_\ |___/      ", 0
        db " _   _        _               _             ", 0
        db "| | (_)      | |             | |            ", 0
        db "| |_ _  ___  | |_ __ _  ___  | |_ ___   ___ ", 0
        db "| __| |/ __| | __/ _' |/ __| | __/ _ \ / _ \", 0
        db "| |_| | (__  | || (_| | (__  | || (_) |  __/", 0
        db " \__|_|\___|  \__\__,_|\___|  \__\___/ \___|", 0        
logo_len equ     $ - logo

line_full       db "+--------------------------------------------+"
line_columns    db "|              |              |              |"

cross db    "XX  XX", 0
      db    "  XX  ", 0
      db    "XX  XX", 0
cc_sprite_len equ     $ - cross

circle db   " OOOO ", 0
       db   "OO  OO", 0
       db   " OOOO ", 0

player db 'Player:  '
splay  db 0
state  dw 0

board   dw 0
        dw 0
        dw 0
        dw 0
        dw 0

          
positions dw (23 * 2)
          dw (38 * 2)
          dw (53 * 2)
          dw (23 * 2)
          dw (38 * 2)
          dw (53 * 2)
          dw (23 * 2)
          dw (38 * 2)
          dw (53 * 2)
          dw (23 * 2)

section .text

start:

    ; set 0x1c interrup vector
    push ds
    push 0
    pop ds
    ds mov word [0x1c * 4], interrupt  ; offset
    ds mov word [0x1c * 4 + 2], cs     ; segment
    pop ds

    ; switch to text mode
    set_text_mode

    ; show logo
    ;       move rows    move columns
    render_sprite 0, 5, 18, 44, 0x0e, logo, logo_len

    ; render playfield and init game
    call reset

; show logo for some time
    mov cl, 0xa0
    call delay

; scroll to playfield
    mov di, 80
    xor si, si
.loop:
    mov ax, si
    inc si
    mul di
    mov cx, ax
    call hw_scroll

    mov cl, 0x01
    call delay

    cmp si, 26
    jnz .loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gameloop:

    call read_key
    ; ESC for exit
    cmp al, 0x1b
    jz end
    ; X key for reset
    cmp al, 0x78
    jz call_reset

    ; position of X or O
    mov bx, [state]
    shl bx, 1
    ; positions are multiplied by 2 - column part
    mov di, next_screen
    add di, [positions + bx]
    ; row (line) part
    mov bx, 6
    mov ax, 160
    mul bx
    add di, ax

    cmp byte [splay], 0x58
    mov si, circle
    mov byte [splay], 0x58
    jnz .render
    mov si, cross
    mov byte [splay], 0x4f

; render sprite of X or O
.render:
    ;original: mov di, (next_screen + (80 * (6) * 2) + ((23) * 2))
    mov dx, 6
    mov ah, 0x0e
    mov cx, cc_sprite_len
    call fill_with_pattern

    mov bx, [state]
    cmp bx, 9
    jz call_reset

; update num of moves
    inc bx
    mov [state], bx

; render who is on move
    mov ah, 0x0e
    mov al, byte [splay]
    mov di, next_screen + (80 * 4 * 2) + (26 * 2)
    call put_char

    jmp gameloop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

call_reset:
    call reset
    jmp gameloop

reset:
    call render_playfield
    set_playground_parts 4, 18, 0x0e, player, 9

    ; X
    mov ax, 0x0e58
    mov byte [splay], 0x58
    mov di, next_screen + (80 * 4 * 2) + (26 * 2)
    call put_char

    mov word [state], 0x0000

    call init_playfield
    ret
    
end:
    ; reset viewport
    xor cx, cx
    call hw_scroll

    ; reset text mode
    set_text_mode


    ; exit
    int 0x20
; end of gameloop


render_playfield:
    ; render playfield
    set_playground_parts 5, 46, 0x0e, line_full, 46

    set_playground_parts 6, 46, 0x0e, line_columns, 46
    set_playground_parts 7, 46, 0x0e, line_columns, 46
    set_playground_parts 8, 46, 0x0e, line_columns, 46
    set_playground_parts 9, 46, 0x0e, line_columns, 46

    set_playground_parts 10, 46, 0x0e, line_full, 46

    set_playground_parts 11, 46, 0x0e, line_columns, 46
    set_playground_parts 12, 46, 0x0e, line_columns, 46
    set_playground_parts 13, 46, 0x0e, line_columns, 46
    set_playground_parts 14, 46, 0x0e, line_columns, 46

    set_playground_parts 15, 46, 0x0e, line_full, 46

    set_playground_parts 16, 46, 0x0e, line_columns, 46
    set_playground_parts 17, 46, 0x0e, line_columns, 46
    set_playground_parts 18, 46, 0x0e, line_columns, 46
    set_playground_parts 19, 46, 0x0e, line_columns, 46

    set_playground_parts 20, 46, 0x0e, line_full, 46
    ret

; clear 10 bytes
init_playfield:
    mov dword [board], 0
    mov dword [board + 4], 0
    mov word [board + 8], 0
    ret

interrupt:
    pusha

    mov ax, [delay_val]
    dec ax
    mov [delay_val], ax

    popa
    iret

; cl - ticks - 1 is ok
delay:
    push ax
    push cx

    mov byte [delay_val], cl
.delay:
    mov al, [delay_val]
    cmp al, 0
    jnz .delay

    pop cx
    pop ax
    ret

; ax - color
; di - from
fill_with_color:
    mov bx, VIDEO_MEM
	mov es, bx
    mov cx, 80 * 25
	rep stosw
    ret

; ah - color
; cx - len
; dx - linelen
; si - what
; di - from
; destroys: bx
fill_with_pattern:
    mov bx, VIDEO_MEM
    mov es, bx
    shl dx, 1

.loop:
    mov al, byte [si]
    cmp al, 0
    jnz .next

    ;add di, 80 * 2 - dx * 2
    add di, 80 * 2
    sub di, dx
    
    jmp .skipwrite

.next:
    stosw
    
.skipwrite:
    inc si
    loop .loop

    ret

; ax - color + char 
; di - where
put_char:
    mov bx, VIDEO_MEM
    mov es, bx
    stosw
    ret

; output: al - keycode
read_key:
    xor ax, ax
    int 0x16
    ret



; cx - new addr
hw_scroll:
    mov dx,0x3da
.1: in  al,dx
    and al,8
    jz  .1
.2: in  al,dx
    and al,8
    jnz .2
   
    mov dx,0x03d4
    mov al,0x0c
    mov ah,ch
    out dx,ax
    inc al
    mov ah,cl
    out dx,ax
    ret