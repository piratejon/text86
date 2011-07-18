; DIRECTLY TRANSCRIBED FROM http://wiki.osdev.org/PS2_Keyboard !!!
; YES, LITERALLY TRANSCRIBED, I TYPED IT BY HAND
top:
use16
org 0x7C00

cli

xor ax, ax
push ax
pop ds

mov word[ds:(9*4)], keyboard_handler
mov word[ds:(9*4)+2], 0

; set mode 2 thanks http://www.computer-engineering.org/ps2keyboard/ for the explanation!
.wait_buffer_write: ; dizzyloop til we can write to the keyboard buffer
in al, 0x64
and al, 0x01
jz .wait_buffer_write

; inform_pic_of_desire_to_change_modes:
mov al, 0xf0
out 0x60, al

.wait_ack:
in al, 0x60
cmp al, 0xfa
jne .wait_ack

.wait_buffer_write_mode:
in al, 0x64
and al, 0x01
jz .wait_buffer_write_mode

; inform_pic_of_desired_mode_change:
mov al, 0x02
out 0x60, al

.await_ack_mode_change:
in al, 0x60
cmp al, 0xfa
jne .await_ack_mode_change

; presumably the datasegment will not change during all the interrupting?
;push 0xb800
;pop ds
;xor cx,cx

sti

jmp $ ; this is an infinite loop since we're handling kbd by interrupt!

keyboard_handler:
  pusha ; push all flags!

.spin: ; interrupt indicates key pressed; dizzyloop til read-ok
  in al, 0x64
  and al, 0x01
  jz .spin

  in al, 0x60

  ; now al has the char(mander)
  ; 'in' is how we BASICally say peek(achu)
  ; 'out' used to be called poke(emon)

  call write_byte_as_hex
  mov al, '|'
  call bios.write_char

  ;call scancode_to_ascii
  ;jz nonprintable
  ;mov byte[cx], al
  ;add cx, 2

nonprintable:
  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  popa

iret

; al is a scancode and shall become a great ascii
scancode_to_ascii:

ret

bios.write_char:
  pusha
  mov ah, 0x0E
  int 0x10
  popa
ret

hex_chars: db '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'

write_byte_as_hex:
  pusha
  and ax, 0xFF
  push ax
  mov bx, ax
  shr bx, 4
  mov al, [hex_chars+bx]
  call bios.write_char
  pop bx
  and bx, 0xF
  mov al, [hex_chars+bx]
  call bios.write_char
  popa
ret

times 510-($-$$) db 0
dw 0xAA55

times 1474560 - ($ - $$) db 0 ; our "filesystem"

