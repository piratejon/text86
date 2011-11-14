top:
bits 16
org 0x7c00

boot_code:

cli ; we are getting ready don't let anyone interrupt us

xor di, di
mov ds, di
mov es, di

mov [boot_dev], dl ; save boot device so we don't have to write a USB driver!

mov ax, [0x463] ; get video port address from bios data area
mov [video_port], ax ; save video port address for later amusement

; first let's reset the disk subsystem just for fun
mov ah, 0
; dl is still cool
int 0x13
jc int13_error

; now disk subsystem is reset
; now we can read info about the drive!
mov ah, 8
mov dl, [boot_dev]
; es:di should already be 0:0
int 0x13
jc int13_error

; now we have good drive info!
mov [max_head], dh
mov dx, cx
and dl, 0x3f
mov [max_sector], dl
and cl, 0xc0 ; preserve the high two bits
; now ch is the low 8 bits of max cyl and cl high bits are the high bits
mov dh, cl
shr dh, 6
mov dl, ch
mov [max_cylinder], dx

; now let us read a great sector
;mov ah, 2 ; function= read to memory
;mov al, 1 ; number of sectors to read
;mov ch, 0 ; low 8 bits of cyl#, can be zero
;mov cl, 0x02 ; skip sector 1 since it should already be loaded
;mov dh, 0 ; head #, can be zero
;mov dl, [boot_dev]

; the following two lines are two bytes less than mov eax, 1
xor eax, eax
inc ax ; sector zero is loaded at 0x7c00 already
call lba_to_chs
mov ah, 2 ; int13 function= read to memory
mov al, 1 ; number of sectors to read
; cl, ch, and dh should be set by lba_to_chs
mov dl, [boot_dev]
push 0x0
pop es
mov bx, sector_2
int 0x13
jc int13_error

push 0xb800
pop es
xor di, di

; now we should have a good keymap!

jmp await_keypress

lba_to_chs: ; converts zero-indexed LBA sector eax to int13 CHS
  cdq ; extend eax sign through edx so we can divide reasonably
  movsx ebx, byte [max_sector]
  idiv ebx
  ; now eax contains cylhead and edx contains sector
  ; TODO: assert edx bits 7-31 are zero since sector is a six-bit positive #
  mov cl, dl ; got the sector number into its right place
  inc cl ; complete the formula
  cdq ; extend cylhead sign through edx so it can be divided by max_head+1
  movsx ebx, byte [max_head]
  inc ebx ; since we are dividing by max_head+1
  idiv ebx
  ; now eax contains cylinder # and edx contains head #
  ; TODO: assert eax bits 11-31 are zero since cyl is a 10-bit positive #
  ; TODO: assert edx bits 8-31 are zero since head is a 8-bit positive #
  mov dh, dl ; get head # out of edx into proper register
  mov ch, al ; an easy one
  shl ah, 6 ; get the bits into the proper position
  ; and ah, 0xc0 ; not necessary because SHL clears the LSB
  or cl, ah

  ret

chs_to_lba: ; converts a int13 CHS to linear LBA in eax
  ret

int13_error:
  push word 0xb800
  pop es
  xor di, di
  call hexprint_al
  mov al, 'e'
  stosb
  hlt

hexprint_eax:
  push eax
  call hexprint_ax
  pop eax
  shr eax, 16
  call hexprint_ax
  ret

hexprint_ax:
  push ax
  call hexprint_al
  pop ax
  shr ax, 8
  call hexprint_al
  ret

hexprint_al:
  push ax
  shr al, 4
  call hexprint_low_nibble_of_al
  pop ax
  call hexprint_low_nibble_of_al
  ret

hexprint_low_nibble_of_al:
  mov ah, 0x07
  and al, 0x0f
  cmp al, 0x09
  jle short .num
  add al, ah
.num:
  add al, 0x30
  stosw

  ret

await_keypress:

  cli
  push word 0
  pop ds
  mov word[ds:(9*4)], keyboard_handler
  mov word[ds:(9*4)+2], 0

  push 0xb800
  pop es
  xor di, di

  sti
  jmp short $

keyboard_handler:
.spin: ; ahhahahahaha dizzy loop
  in al, 0x64
  and al, 0x01
  jz short .spin

  in al, 0x60
  ;               now al has the char(mander)
  ; 'in' is how we BASICally say peek(achu)
  ;      'out' used to be called poke(emon)

  ; is this a control character?
  cmp al, 0x0e
  je .backspace
  cmp al, 0x2a
  je short .shift_down
  cmp al, 0x36
  je short .shift_down
  cmp al, 0xaa
  je short .shift_up
  cmp al, 0xb6
  je short .shift_up
  cmp al, 0x1c
  je short .crlf

  cmp al, qwerty_ascii_lower_end - qwerty_ascii_lower + 1
  jae short .next

  jmp short .translate

.shift_down:
  or byte [shift_flag], 1
  jmp short .next

.shift_up:
  and byte [shift_flag], 0
  jmp short .next

.backspace:
  test di, di
  jz short .next
  sub di, 2
  mov al, 0x20
  stosb
  dec di
  jmp short .reset_cursor_to_di

.crlf:
  push word 160
  mov ax, di
  cwd
  idiv word [esp]
  add esp, 2
  sub di, dx
  add di, 160
  jmp short .reset_cursor_to_di

.translate:
  mov bx, qwerty_ascii_upper
  test byte [shift_flag], 1
  jnz short .upper
  mov bx, qwerty_ascii_lower
.upper:
  xlatb
  cmp al, 0 ; if al is zero, don't draw it
  je short .next

.not_full:
  stosb
  mov al, 0x07
  stosb

.reset_cursor_to_di:
  call reset_cursor_to_di

  ;cmp di, 0x200
  ;call write_buffer

.next:
  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  jnz short .spin
                
  iret

reset_cursor_to_di:
  ; cursor position is row+(col*80), which happens to be half of di
  mov bx, di
  shr bx, 1

  mov dx, [video_port]
  mov al, 0x0f ; selects the low word of the cursor position
  out dx, al

  inc dx
  mov ax, bx
  and ax, 0xff
  out dx, al

  mov dx, [video_port]
  mov al, 0x0e ; selects the high word of the cursor position
  out dx, al

  inc dx
  mov al, bh
  out dx, al

  ret

write_buffer:
  ; write 1 sector from es:bx to sector eax
  push bx
  ; eax is parameter
  call lba_to_chs ; retain cl, ch, dh
  mov ah, 3
  mov al, 1
  mov dl, [boot_dev]
  pop bx
  int 0x13
  ; carry flag set on error
  ret

times 510 - ($ - $$) db 0xcd ; partition table
dw 0xaa55

sector_2:

boot_dev: db 0
shift_flag: db 0
max_sector: db 0
max_head: db 0
max_cylinder: dw 0
video_port: dw 0

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_lower_end:
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '
qwerty_ascii_upper_end:

