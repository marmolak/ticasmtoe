bits 16
cpu 8086
org 0x100
align 16

%define VIDEO_MEM 0xb800

%macro set_text_mode 0
    mov al, 0x03
    int 0x10
%endmacro

%define next_screen (80 * 25 * 2)
%define row(r) (80 * (r) * 2)
%define col(c) ((c) * 2)
%define row_col(r, c) (row((r)) + col((c)))

; we are on second screen
%macro set_playground_parts 5
    render_sprite next_screen, (%1), 18, (%2), (%3), (%4), (%5)
%endmacro

; ah, dx and cx must be initialized before using this macro
%macro set_playground_parts_opti 2
    mov di, next_screen + row_col((%1), 18)
    mov si, (%2)
    call fill_with_pattern
%endmacro

%macro render_sprite 7
    ;       skips first part ;rows           ; columns
    mov di, (%1) + row_col((%2), (%3))
    mov dx, (%4)
    mov ah, (%5)
    mov si, (%6)
    mov cx, (%7)
    call fill_with_pattern
%endmacro


section .data

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

help    db "1|2|3", 0
        db "-+-+-", 0
        db "4|5|6", 0
        db "-+-+-", 0
        db "7|8|9", 0
help_len equ $ - help

player db 'Player: X won!'
splay  equ next_screen + row_col(4, 26)

interrupt_offset    dw 0
interrupt_segment   dw 0

board  db 4 dup '1'
       db 4 dup '2'
       db 2 dup '3'
          
positions dw row_col(6, 23)
          dw row_col(6, 38)
          dw row_col(6, 53)
          dw row_col(11, 23)
          dw row_col(11, 38)
          dw row_col(11, 53)
          dw row_col(16, 23)
          dw row_col(16, 38)
          dw row_col(16, 53)

section .text

start:
    delay_val: dw 0x9090

    ; disable ray
    mov dx, 0x3D8
    in al, dx

    and al, 0x0F7
    out dx, al

    ; set 0x1c interrup vector
    xor ax, ax
    mov es, ax

    ; save old interrupt handler
    cli
    es mov ax, [0x1c * 4]
    mov word [interrupt_offset], ax
    es mov ax, [0x1c * 4 + 2]
    mov word [interrupt_segment], ax

    es mov word [0x1c * 4], interrupt  ; offset
    es mov word [0x1c * 4 + 2], cs     ; segment
    sti

    ; switch to text mode
    xor ax, ax
    set_text_mode

    ; show logo
    ;       move rows    move columns
    render_sprite 0, 5, 18, 44, 0x0e, logo, logo_len

    ; render it once
    render_sprite next_screen, 20, 1, 5, 0x0e, help, help_len

    ; render playfield and init game
    call reset

    ; enable ray
    mov dx, 0x3D8
    in al, dx
    or al, 0x8
    out dx, al

; show logo for some time
    mov cx, 0x50
    call delay_can_break

; scroll to playfield
    mov di, 80
    xor si, si
.loop:
    mov ax, si
    inc si

    ;mul di
    mov bx, ax
    ; n<<3 + n<<1 = n*10
    mov cl, 3
    shl ax, cl

    shl bx, 1
    add ax, bx
    ; n * 8
    mov cl, 3
    shl ax, cl

    xchg cx, ax
    call hw_scroll

    mov cx, 0x01
    call delay

    cmp si, 26
    jnz .loop

    ; restore old interrupt handler - we don't need delay any more
    cli
    mov ax, [interrupt_offset]
    es mov word [0x1c * 4], ax
    mov ax, [interrupt_segment]
    es mov word [0x1c * 4 + 2], ax
    sti
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
gameloop:

    call read_key
    cmp al, 0x1b	; Esc key pressed?
    je end		    ; Yes, exit
    ; X key for reset
    cmp al, 0x78
    jz call_reset

    sub al, 0x31		; Subtract code for ASCII digit 1
    jc gameloop	    ; Is it less than? Wait for another key
    cmp al, 0x09		; Comparison with 9
    jnc gameloop	; Is it greater than or equal to? Wait
    cbw			; Expand AL to 16 bits using AH.
    xchg bx, ax
    mov al, [board + bx]		; Get square content
    cmp al, 0x40		; Comparison with 0x40
    jnc gameloop	; Is it greater than or equal to? Wait

    mov al, byte [splay]
    mov byte [board + bx], al

    ; don't touch al please
    ; lookup table for X or O placement
    mov di, next_screen
    shl bx, 1
    add di, [positions + bx]

    ; set player on move
    cmp al, 0x58
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

    ; check game state
    call find_line

; render who is on move
    mov ah, 0x0e
    mov al, byte [splay]
    mov di, next_screen + row_col(4, 26)
    call put_char

    jmp gameloop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

call_reset:
    call reset
    jmp gameloop

reset:

;render_playfield:
    mov cx, 46
    mov dx, cx
    mov ah, 0x0e

    set_playground_parts_opti 5, line_full

    set_playground_parts_opti 6, line_columns
    set_playground_parts_opti 7, line_columns
    set_playground_parts_opti 8, line_columns
    set_playground_parts_opti 9, line_columns

    set_playground_parts_opti 10, line_full

    set_playground_parts_opti 11, line_columns
    set_playground_parts_opti 12, line_columns
    set_playground_parts_opti 13, line_columns
    set_playground_parts_opti 14, line_columns

    set_playground_parts_opti 15, line_full

    set_playground_parts_opti 16, line_columns
    set_playground_parts_opti 17, line_columns
    set_playground_parts_opti 18, line_columns
    set_playground_parts_opti 19, line_columns

    set_playground_parts_opti 20, line_full
; render playfield end

    set_playground_parts 4, 18, 0x0e, player, 9

    ; X
    mov ax, 0x0e58
    mov byte [splay], 0x58
    mov di, next_screen + row_col(4, 26)
    call put_char

; clear 10 bytes
;init_playfield:
    mov bx, ds
    mov es, bx
; repurpose position as cleanup pattern. Values are smaller than 0x40 it's ok.
    mov si, positions + 1
    mov di, board
    mov cx, 5
    rep movsw

    ret
    
end:

    ; reset viewport
    xor cx, cx
    call hw_scroll

    ; reset text mode
    set_text_mode

    ; exit
    ; only 'ret' works on dosbox but doesn't work on real hw


    int 0x20
; end of gameloop

; game logic
find_line:
    mov al, [board]
    cmp al, [board + 1]
    jne b01
    cmp al, [board + 2]
    je won
b01:
    cmp al, [board + 3]
    jne b04
    cmp al, [board + 6]
    je won
b04:
    cmp al, [board + 4]
    jne b05
    cmp al, [board + 8]
    je won
b05:
    mov al, [board + 3]
    cmp al, [board + 4]
    jne b02
    cmp al, [board + 5]
    je won
b02:    
    mov al, [board + 6]
    cmp al, [board + 7]
    jne b03
    cmp al, [board + 8]
    je won
b03:
    mov al, [board + 1]
    cmp al, [board + 4]
    jne b06
    cmp al, [board + 7]
    je won
b06:
    mov al, [board + 2]
    cmp al, [board + 5]
    jne b07
    cmp al, [board + 8]
    je won
b07:
    cmp al, [board + 4]
    jne b08
    cmp al, [board + 6]
    je won
b08:
    ret

won:
    set_playground_parts 24, 18, 0x0e, player, 14
    mov ah, 0x0e
    mov al, byte [splay]
    cmp al, 0x58
    mov al, 0x4f
    jz .next
    mov al, 0x58
.next:
    mov di, next_screen + row_col(24, 26)
    call put_char
.nothing:
    call read_key
    ; X key for reset
    cmp al, 0x78
    jz call_reset
    ; ESC key
    cmp al, 0x1b
    je end
    jmp .nothing


interrupt:
    pushf

    cs dec word [delay_val]

    popf
    iret

; cx - ticks
delay:
    mov [delay_val], cx
.delay:
    cmp word [delay_val], 0
    jnz .delay

    ret

; this routine can be break by keyboard
; cx - ticks
delay_can_break:
    push ax
    mov [delay_val], cx
.delay:
    mov ah, 1
    int 0x16
    jnz .swallow
.delay_check:
    cmp word [delay_val], 0
    jnz .delay

.delay_end:
    pop ax
    ret

.swallow:
    xor ax, ax
    int 0x16
    jmp .delay_end

; ah - color
; cx - len
; dx - linelen
; si - what
; di - from
; destroys: bx
fill_with_pattern:
    push cx

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

    shr dx, 1
    pop cx
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
