top:
bits 16
org 0x7c00

; what to do?
; find the biggest chunk of contiguous RAM as our "base"
; identify the boot device for the purposes of saving
; copy the boot device to the base

cli ; we are getting ready don't let anyone interrupt us

; initialize the buffer for the memory spec
push word 0
push word 0
push word 0
pop ds
pop es
pop bp

mov ax, 0xe820
mov cx, e820_buf_end - e820_buf_start
mov edx, 'PAMS' ; SMAP in little endian
mov di, e820_buf_start

e820_loop:
  int 0x15
  jc short .e820_done
  cmp eax, edx
  jne short .e820_failed
  mov eax, 0xe820
  inc bp
  mov [entry_size], cx
  add di, cx
  test ebx, ebx
  jz .e820_done
  jmp e820_loop

.e820_failed:
  hlt

.e820_done:
  ; initialize video buffer target
  push 0xb800
  pop es

  mov di, 0x0

  mov cx, bp

  movzx eax, cx
  call hexprint_eax

  mov al, ' '
  stosb
  inc di

  mov eax, [entry_size]
  call hexprint_eax

  mov di, 160
  mov si, e820_buf_start

.e820_done_loop:
  ; print the high dword followed by the low dword of the location

  movzx eax, si
  call hexprint_eax
  mov al, ':'
  stosb
  inc di

  movzx eax, word [entry_size]
  call hexprint_eax
  mov al, ' '
  stosb
  inc di

  mov eax, [si+4]
  call hexprint_eax
  mov eax, [si]
  call hexprint_eax

  mov al, ' '
  stosb
  inc di

  ; high dword, low dword of the size
  mov eax, [si+12]
  call hexprint_eax
  mov eax, [si+8]
  call hexprint_eax

  mov al, ' '
  stosb
  inc di

  ; type: a value of 1 indicates free/available memory
  mov eax, [si+16]
  call hexprint_eax

  mov al, ' '
  stosb
  inc di

  ; special ACPI 3.0 dword -- who the hell knows what this should be!
  mov eax, [si+20]
  call hexprint_eax

  add di, 22
  add si, [entry_size]

  loopnz .e820_done_loop

  mov eax, [entry_size]
  call hexprint_eax

  jmp short await_keypress
  hlt

; await a keypress, then reboot
await_keypress:
  mov si, prompt
  call zprint

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
  mov al, 0xFE
  out 0x64, al

  iret

  hlt

hexprint_eax:
;  push eax
  bswap eax
  call hexprint_al
  shr eax, 8
  call hexprint_al
  shr eax, 8
  call hexprint_al
  shr eax, 8
  call hexprint_al
;  pop eax
  ret 0

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
  ret 0

hexprint_al:
  push ax
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
  pop ax

  ret 0

large_window_index: db 0x0
large_window_size: dq 0x0000000000000000
large_window_location: dq 0x0000000000000000

;large_window_size: dq 0xffffffffffffffff
;large_window_location: dq 0xffffffffffffffff

memmap: db 'memmap ', 0
failed: db 'failed ', 0
found: db 'found ', 0
prompt: db 'press any key to reboot!', 0

times 510 - ($ - $$) db 0x00 ; round out the boot sector
dw 0xaa55

entry_size: dw 0

e820_buf_start:
window_index: dq 0
window_location: dq 0
window_flags: dq 0
e820_buf_end:

