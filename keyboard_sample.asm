; DIRECTLY TRANSCRIBED FROM http://wiki.osdev.org/PS2_Keyboard !!!
; YES, LITERALLY TRANSCRIBED, I TYPED IT BY HAND
top:
use16
org 0x7C00

; initialize the keyboard interrupt handler
  cli
  xor ax, ax
  push ax
  pop ds
  mov word[ds:(9*4)], keyboard_handler
  mov word[ds:(9*4)+2], 0

; reset the screen
  push 0xb800
  pop es
  xor di,di
  mov cx, 2000
  mov ax, 0x7820
  repnz stosw

; clear the shift flag
  xor cl, cl

; initialize the buffer and index
  push buffer
  pop es
  xor di, di

; ds is scancode-to-ascii LUT offset
  xor ds, ds

; start the "main" loop by turning on interrupts
  sti   
  jmp $

keyboard_handler:
  ; pushf ; push all flags!

.spin: ; interrupt indicates key pressed; dizzyloop til read-ok
  in al, 0x64
  and al, 0x01
  jz .spin

  in al, 0x60
  ; now al has the char(mander)
  ; 'in' is how we BASICally say peek(achu)
  ; 'out' used to be called poke(emon)

  ; is this a control character?
  cmp al, 0x0e ; backspace
  je .backspace
  cmp al, 0x2a
  je .shift_down
  cmp al, 0x36
  je .shift_down
  cmp al, 0xaa
  je .shift_up
  cmp al, 0xb6
  je .shift_up

  jmp .translate

.backspace:
  cmp di, 1
  jl .done ; are we already at the beginning?
  sub di, 1
  mov byte [es:di], 0x20
  jmp .blit

.shift_down:
  or cl, 1
  jmp .done

.shift_up:
  and cl, 0
  jmp .done

.crlf:
  jmp .done

  ; here the scan code is translated to ascii and drawn
.translate:
  mov bx, qwerty_ascii_upper
  test cl, 1
  jnz .upper
  mov bx, qwerty_ascii_lower
.upper:
  xlatb
  cmp al, 0
  je .done

.draw:
  mov [es:di], al
  add di, 1

.blit:
  push 0xb800
  pop ds
  mov al, [es:di]
  shl di, 1
  mov [ds:di], al
  shr di, 1

.done:

  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  ; popf

iret

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '

times 510-($-$$) db 0
dw 0xAA55

buffer:

times 1474560 - ($ - $$) db 0x20 ; our "filesystem"

