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
pop es
pop bp

xor ebx, ebx
e820_loop:
  ; setup the interrupt parameters
  mov eax, 0xe820
  mov ecx, e820_buf_end - e820_buf_start
  mov edx, 'PAMS'
  mov edi, e820_buf_start

  ; do the interrupt
  int 0x15

  ; failure condition: carry flag set
  jc short .e820_done

  ; failure condition: eax != SMAP
  cmp eax, 'PAMS'
  jne short .e820_failed

  ; presumably a valid entry -- is it useable memory?
  cmp [di+16], dword 1
  jne short .next_entry

  ;;; check what we have with what we got!
  mov eax, [di+12] ; compare current hiword to largest-known-elt hiword
  cmp eax, [large_window_size+4]
  jl .next_entry ; the hiword is smaller than what we have

  ; here, the hiword is greater than or equal to what we have
  jg .move_hiword 

  mov eax, [di+8]
  cmp eax, [large_window_size]
  jle .next_entry

.move_hiword:
  mov eax, [di+12]
  mov [large_window_size+4], eax

.move_loword:
  mov eax, [di+8]
  mov [large_window_size], eax

  ; save the location of this entry
  mov eax, [di+4]
  mov [large_window_location+4], eax
  mov eax, [di]
  mov [large_window_location], eax

.next_entry:

  ; keep looping while ebx is not zero
  test ebx, ebx
  jnz short e820_loop

  ; we made it!
  jmp short .e820_done

.e820_failed:
  push 0xb800
  pop es
  mov di, 0
  mov si, failed
  call zprint
  hlt

.e820_done:
  ; initialize video buffer target
  push 0xb800
  pop es

  mov di, 0x0

  mov eax, [large_window_size+4]
  call hexprint_eax
  mov eax, [large_window_size]
  call hexprint_eax

  mov al, '@'
  stosb
  inc di

  mov eax, [large_window_location+4]
  call hexprint_eax
  mov eax, [large_window_location]
  call hexprint_eax

  jmp await_keypress
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
  jmp $

keyboard_handler:
  cli
.spin:
  in al, 0x64
  and al, 0x01
  jz .next
  in al, 0x60
.next:
  and al, 0x02
  jnz .spin
  
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
  mov al, ' '
  stosb
  inc di
;  pop eax
  ret 0

zprint:
  cld
  push 0xb800
  pop es
.printloop:
  cmp byte [si], 0
  je .done
  movsb
  mov byte [es:di], 0x07
  inc di
  jmp .printloop
.done:
  ret 0

hexprint_al:
  push ax
  push ax
  shr al, 4
  and al, 0x0f
  cmp al, 0x09
  jle .num
  add al, 0x07
.num:
  add al, 0x30
  stosb
  inc di
  pop ax
  and al, 0x0f
  cmp al, 0x09
  jle .num2
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

