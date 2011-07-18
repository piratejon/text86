; DIRECTLY TRANSCRIBED FROM http://wiki.osdev.org/PS2_Keyboard !!!
; YES, LITERALLY TRANSCRIBED, I TYPED IT BY HAND
use16
org 0x7C00

cli

xor ax, ax
push ax
pop ds

mov word[ds:(9*4)], keyboard_handler
mov word[ds:(9*4)+2], 0

sti

jmp $ ; this is an infinite loop since we're handling kbd by interrupt!

keyboard_handler:
  pusha ; push all flags!

.spin:
  in al, 0x64
  and al, 0x01
  jz .spin

  in al, 0x60

  call write_byte_as_hex
  mov al, '|'
  call bios.write_char

  mov al, 0x20
  out 0x20, al

  popa

iret

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

