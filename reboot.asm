top:
bits 16
org 0x7c00

cli ; we are getting ready don't let anyone interrupt us
cld ; lol

mov [boot_dev], dl ; save boot device so we don't have to write a USB driver!

  push 0xb800
  pop es

  push 0x07c0
  pop ds

  xor di, di
  xor si, si

  mov word [es:di], 0x0765

  mov cx, 0x200
  ; movsX = ds:si to es:di
.xxd_loop:

  test cx, 0x0007
  jnz .keep_going

  mov eax, ds
  shl eax, 4
  movzx ebx, si
  add eax, ebx
  call hexprint_eax
  mov al, ':'
  stosb
  inc di
  mov al, ' '
  stosb
  inc di

  push cx

  mov cx, 8
.we_loop:
  mov al, [ds:si]
  inc si
  call hexprint_al
  mov al, [ds:si]
  inc si
  call hexprint_al
  mov al, ' '
  stosb
  inc di
  loopnz .we_loop

  ; an extra space!
  mov al, ' '
  stosb
  inc di

  mov cx, 16
  sub si, cx ; go back and do it in ascii or dots
.we2:
  mov al, [ds:si]
  stosb
  inc di
  cmp al, 0x20
  jge .we3
  sub di, 2
  mov al, '.'
  stosb
  inc di
.we3:
  inc si
  loopnz .we2

  pop cx

  add di, 26

.keep_going:

  loopnz .xxd_loop

await_keypress:

  cli
  xor ax, ax
  push ax
  pop ds
  mov word[ds:(9*4)], keyboard_handler
  mov word[ds:(9*4)+2], 0

  sti
  jmp short $

keyboard_handler:
  cli
.spin:
  in al, 0x64
  and al, 0x01
  jz short .next
  in al, 0x60
.next:
  and al, 0x02
  jnz short .spin
  
  ; reboot via kbd pic
  mov al, 0xfe
  out 0x64, al

  iret

  hlt

hexprint_eax:
  push eax
  bswap eax
  call hexprint_al
  shr eax, 8
  call hexprint_al
  shr eax, 8
  call hexprint_al
  shr eax, 8
  call hexprint_al
  pop eax
  ret

zprint:
  cld
  push 0xb800
  pop es
.zprintloop:
  cmp byte [si], 0
  je short .done
  movsb
  mov byte [es:di], 0x07
  inc di
  jmp short .zprintloop
.done:
  ret

hexprint_al:
  push ax
  shr al, 4
  and al, 0x0f
  cmp al, 0x09
  jle short .num
  add al, 0x07
.num:
  add al, 0x30
  stosb
  inc di
  pop ax
  and al, 0x0f
  cmp al, 0x09
  jle short .num2
  add al, 0x07
.num2:
  add al, 0x30
  stosb
  inc di

  ret

times 510 - ($ - $$) db 0x00 ; round out the boot sector
dw 0xaa55

boot_dev: dw 0

great_buffer:

