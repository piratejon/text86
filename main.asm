use16
org 0x7C00

jmp Start

greet: db "Welcome to WriteOrDie OS. Write or be unwritten!"
end_greet:

wc_prompt: db "Enter your word count goal for this session:"
end_wc_prompt:

qwerty_lc:
db 0, "~", "1234567890-=", 0x08, 0x09
db "qwertyuiop[]", 0x0D, "."
db "asdfghjkl", 0x3B, "'..." ; 0x3B is semicolon, starts a comment here
db "zxcvbnm,./... "
qwerty_lc_end:

qwerty_uc:
db 0, "`", "!@#$%^&*()_+", 0x08, 0x09
db "QWERTYUIOP:", 0x24, 0x0A, "."
db "ASDFGHJKL", 0x3A, "'..." ; 0x3A is colon, parallels above
db "ZXCVBNM<>?... "
qwerty_uc_end:

shift_state: db 0,0

keyboard_handler:
nop
xor ax,ax ; necessary?
kh_spin:
in al, 0x64
and al, 0x01
jz kh_spin
in al,0x60
push ax
mov al,0x20
out 0x20,al
pop ax
; ax now has scancode
; scancode > keymap > ASCII
test al, 0x2A ; is this a shift?
jnz .nonshift
and ax, 0x0080 ; press or release?
push ax
pop word [shift_state]
iret
.nonshift:
test al, 0x80
jnz kh_return_none

cmp al, (qwerty_lc_end - qwerty_lc)
jg kh_return_none
;mov bx, [shift_state]
;test bx, 0xFF7F
mov bx, qwerty_lc
;jz .translate
;mov bx, qwerty_uc
;.translate:
and ax, 0x00FF
add bx, ax
mov al, [bx]
jmp kh_return

kh_return_none:
xor ax,ax ; return zero has no effect
kh_return:
iret

Start:

;mov ah,2
;mov al,3
;int 0x10 ; set video mode

push 0xB800 ; video memory
pop es

; clear screen
mov cx, 2000 ; 80x25x2 bytes video memory
mov ax, 0x7720 ; ah=77=gray-on-gray, al=0x20 ASCII space
xor di,di
cls:
stosw
loop cls

; write greeting
print_greet:
mov cx, end_greet
sub cx, greet
mov si, greet
mov di, 0x20
mov ah, 0x1e ; color
cld
.print:
lodsb
stosw
loop .print 

; write prompt
print_wc_prompt:
mov cx, end_wc_prompt
sub cx, wc_prompt
mov si, wc_prompt
mov di, 828
mov ah, 0x1e ; color
.print:
lodsb
stosw
loop .print

add di, 2 ; space between prompt and box

; write input box
print_input_box:
mov ax, 0x4f20 ; white-on-red, space
mov cx, 6 ; 4 spaces with a margin of 1 on either side
rep stosw

sub di, 0xa ; cursor to box pos 1
mov dx, di ; save start of box

; install keyboard handler
cli
push 0
pop ds
mov word [ds:(9*4)], keyboard_handler
mov word [ds:(9*4)+2], 0
sti

; getting WC digits
mov cx, 50 ; max # digits
get_wc_loop_r:
xor ax, ax
get_wc_loop:
cmp al, 0
jz get_wc_loop
; we got one, is it a control character or printable?
cmp al, 0x20
jge .printable
; it's a control character
cmp al, 0x1B
je .escape
cmp al, 0x08
sub di, 0x04
cmp di, dx
jl get_wc_loop
mov ax, 0x4f20
mov word [di], ax
.printable:
cmp al, 0x7E
jg .nonprintable ; wtf :-/
; here we actually print, need to bump the cursor
mov ah, 0x4f
stosw
.nonprintable:
xor ax, ax
loop get_wc_loop

.escape:
hlt

; finish 'er off
times 0200h - 2 - ($ - $$) db 0x90
dw 0AA55h ; boot sector signature

times 1474560 - ($ - $$) db 0 ; our "filesystem"

