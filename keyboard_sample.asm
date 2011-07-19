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

; presumably the datasegment will not change during all the interrupting?
push 0xb800
pop es
xor di,di
mov cx, 2000
mov ax, 0x7820
repnz stosw
xor di, di

sti

jmp $ ; this is an infinite loop since we're handling kbd by interrupt!

keyboard_handler:
  pushf ; push all flags!

.spin: ; interrupt indicates key pressed; dizzyloop til read-ok
  in al, 0x64
  and al, 0x01
  jz .spin

  in al, 0x60

  ; is this a control character?
  cmp al, 0x0e
  jne .ctl2
  cmp di, 2
  jl .done
  sub di, 2
  mov byte [ds:di], 0x20
  jmp .done

.ctl2:

  ; now al has the char(mander)
  ; 'in' is how we BASICally say peek(achu)
  ; 'out' used to be called poke(emon)


  ; here the scan code is translated to ascii and drawn
  push ds
  push word 0x00
  pop ds
  mov bx, qwerty_ascii_lower
  xlatb
  pop ds
  cmp al, 0
  je .done

.draw:
  push 0xb800
  pop ds
  mov [ds:di], al
  add di, 2

.done:
  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  popf

iret

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '

times 510-($-$$) db 0
dw 0xAA55

times 1474560 - ($ - $$) db 0 ; our "filesystem"

