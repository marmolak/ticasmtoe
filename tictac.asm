bits 16
org 0x100

%define VIDEO_MEM 0xb800

%macro set_text_mode 0
    mov al, 0x03
    int 0x10
%endmacro

; we are on second screen
%macro set_playground_parts 5
    ;       skips first part ;rows           ; columns
    mov di, ((80 * 25 * 2) + (80 * (%1) * 2) + (18 * 2))
    mov dx, %2
    mov ah, %3
    mov si, %4
    mov cx, %5
    call fill_with_pattern
%endmacro

%macro render_sprite 6
    ;       skips first part ;rows           ; columns
    mov di, ((80 * 25 * 2) + (80 * (%1) * 2) + ((%2) * 2))
    mov dx, %3
    mov ah, %4
    mov si, %5
    mov cx, %6
    call fill_with_pattern
%endmacro


section .data
val: db 0

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


board: equ 0x300

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
    mov di, 80 * 5 * 2 + (18 * 2)
    mov dx, 44
    mov ah, 0x0e
    mov si, logo
    mov cx, logo_len
    call fill_with_pattern


    call render_playfield
    ;call init_playfield

; show logo for some time
    mov cl, 0xa0
    call delay

; scroll to gameboard
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

; gameloop
    ;xor cx, cx
gameloop:

    call read_key
    ; ESC for exit
    cmp al, 0x1b
    jz end
    ; X key for reset
    cmp al, 0x78
    jz reset

    ; X
    render_sprite 6, 23, 6, 0x0e, cross, cc_sprite_len
    call read_key

    ; O
    render_sprite 6, 38, 6, 0x0e, circle, cc_sprite_len
    call read_key

    render_sprite 6, 23 + 7 + 8 + 15, 6, 0x0e, circle, cc_sprite_len
    call read_key

    jmp gameloop

reset:
    call render_playfield
    ;call init_playfield
    jmp gameloop
    
end:

    mov cl, 0x12
    call delay

    ; reset viewport
    mov cx, 0
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

; clear 12 bytes
init_playfield:
    mov dword [board], 0
    mov dword [board + 4], 0
    mov dword [board + 8], 0
    ret

interrupt:
    pusha

    mov ax, [val]
    dec ax
    mov [val], ax

    popa
    iret

; cl - ticks - 1 is ok
delay:
    push ax
    push dx
    push cx

    mov byte [val], cl
.delay:
    mov al, [val]
    cmp al, 0
    jnz .delay

    pop cx
    pop dx
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
    add dx, dx

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