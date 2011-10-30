top:
bits 16
org 0x7c00

; what to do?
; find the biggest chunk of contiguous RAM as our "base"
; identify the boot device for the purposes of saving
; copy the boot device to the base

cli ; we are getting ready don't let anyone interrupt us

; initialize the buffer for the memory spec
push dword 0
pop ds
pop es

mov edx, 'PAMS' ; SMAP in little endian
mov di, e820_buf_start

e820_loop:
  mov eax, 0xe820
  mov ecx, e820_buf_end - e820_buf_start
  int 0x15
  jc short .e820_done
  cmp eax, edx
  jne short .e820_failed
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
  mov si, e820_error
  call zprint
  call await_keypress

.e820_done:
  ; initialize video buffer target, b8000:xxxx
  push 0xb800
  pop es

  ; top left character of the screen
  mov di, 0x0

  ;mov eax, [large_window_lo]
  ;call hexprint_eax
  ;mov al, '@'
  ;stosb
  ;inc di
  ;mov eax, [relocate]
  ;call hexprint_eax

;  jmp short await_keypress
;  hlt

; ok sorry guys, just going to assume A20 is enableable because this is 2011
  in al, 0x92
  or al, 0x02
  and al, 0xfe
  out 0x92, al

; now it is time to scan the PCI bus
; bus is a 8-bit number, device is a 5 bit number, function is a 3 bit number
; device must exist for a function to exist
pci_enum:
  xor cx, cx
.pci_enum_loop:
  ; create the CONFIG_ADDRESS register
  movzx eax, cx
  inc cx
  shl eax, 10
  or eax, 0x80000008

  mov ebx, eax

  mov dx, 0xcf8
  out dx, eax
  mov dx, 0xcfc
  in eax, dx
  cmp ax, 0xffff
  je .next

  ; we have a valid PCI device, is it the needed type?
  ror eax, 16
  cmp ax, 0x0c03
  jne .next

;  push eax
;  mov eax, ebx
;  call hexprint_eax
;  pop eax
;  call hexprint_eax
;  add di, 160-(8*2*2)

.next:
  cmp cx, 0x2000
  jl .pci_enum_loop
 
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

memmap: db 'memmap ', 0
failed: db 'failed ', 0
found: db 'found ', 0
prompt: db 'press any key to reboot!', 0
e820_error: db 'e820 err', 0

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

pci_memory:
device_id: dw 0
vendor_id: dw 0
status: dw 0
command: dw 0
class_id: db 0
subclass: db 0
prog_if: db 0
revision_id: db 0
bist: db 0
header_type: db 0
latency_timer: db 0
cache_line_size: db 0
bar0: dd 0
bar1: dd 0
bar2: dd 0
bar3: dd 0
bar4: dd 0
bar5: dd 0
cardbus_cis_p: dd 0
subsystem_id: dw 0
subsystem_vendor_id: dw 0
expansion_rom: dd 0
reserved1: db 0,0,0
capabilites: db 0
reserved2: dd 0
max_latency: db 0
min_grant: db 0
interrupt_pin: db 0
interrupt_line: db 0
 
