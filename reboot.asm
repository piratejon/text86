top:
bits 16
org 0x7c00

; what to do?
; find the biggest chunk of contiguous RAM as our "base"
; identify the boot device for the purposes of saving
; copy the boot device to the base

cli ; we are getting ready don't let anyone interrupt us

; initialize the buffer for the memory spec
mov ax, 0
mov ds, ax
mov es, ax
mov bp, ax

mov edx, 'PAMS' ; SMAP in little endian
mov di, e820_buf_start

e820_loop:
  mov eax, 0xe820
  mov ecx, e820_buf_end - e820_buf_start
  int 0x15
  jc short .e820_done
  cmp eax, edx
  jne short .e820_failed
  inc bp
  ; here, a valid entry!

  ; is it useable?
  cmp [di_flags], dword 1
  jne short .next_entry

  ; who cares about the hi-dword (this is so wrong!)
  mov eax, [di_size_lo]
  cmp eax, [large_window_lo]
  jl short .next_entry
  mov [large_window_lo], eax
  mov eax, [di_loc_lo]
  mov [relocate], eax

.next_entry:
  test ebx, ebx
  jz short .e820_done
  jmp short e820_loop

.e820_failed:
; TODO: print an error
  hlt

.e820_done:
  ; initialize video buffer target, b8000:xxxx
  push 0xb800
  pop es

  ; top left character of the screen
  mov di, 0x0

  mov eax, [large_window_lo]
  call hexprint_eax
  mov al, '@'
  stosb
  inc di
  mov eax, [relocate]
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

memmap: db 'memmap ', 0
failed: db 'failed ', 0
found: db 'found ', 0
prompt: db 'press any key to reboot!', 0

times 510 - ($ - $$) db 0x00 ; round out the boot sector
dw 0xaa55

relocate: dd 0
large_window_size:
large_window_lo: dd 0
large_window_hi: dd 0

e820_buf_start:
window_location: ; dq 0
di_loc_lo: dd 0
di_loc_hi: dd 0
window_size: ; dq 0
di_size_lo: dd 0
di_size_hi: dd 0
di_flags: dq 0
e820_buf_end:

