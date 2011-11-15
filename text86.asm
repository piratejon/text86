top:
bits 16
org 0x7c00

boot_code:

cli ; we are getting ready don't let anyone interrupt us

xor di, di
mov ds, di
mov es, di

mov [boot_dev], dl ; save boot device so we don't have to write a USB driver!

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

; the config sector is read, so we can now read/write it

mov ax, [0x463] ; get video port address from bios data area
mov [video_port], ax ; save video port address for later amusement

; now we should have a good keymap!
jmp initialize_keyboard

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
; is this ever needed?
;  ret

int13_error:
  push word 0xb800
  pop es
  xor di, di
  call hexprint_al
  mov al, 'e'
  stosb
  mov al, 0x40
  stosb
  hlt

;hexprint_eax:
;  push eax
;  call hexprint_ax
;  pop eax
;  shr eax, 16
;  call hexprint_ax
;  ret
;
;hexprint_ax:
;  push ax
;  call hexprint_al
;  pop ax
;  shr ax, 8
;  call hexprint_al
;  ret

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

initialize_keyboard:
  xor di, di
  mov ds, di

  mov si, [write_buffer_addr]

  push 0xb800
  pop es

  mov word[ds:(9*4)], keyboard_handler
  mov word[ds:(9*4)+2], 0

  sti
  jmp short $

keyboard_handler:
  cli
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
  cmp al, 0x1d
  je short .ctrl_down
  cmp al, 0x9d
  je short .ctrl_up

  cmp al, qwerty_ascii_lower_end - qwerty_ascii_lower + 1
  jae short .next

  jmp short .translate

.ctrl_down:
  or byte [shift_flag], 0x02
  jmp short .next

.ctrl_up:
  and byte [shift_flag], 0xfd
  jmp short .next

.shift_down:
  or byte [shift_flag], 0x01
  jmp short .next

.shift_up:
  and byte [shift_flag], 0xfe
  jmp short .next

.backspace:
  test di, di
  jz short .next
  call backspace
  jmp short .reset_cursor_to_di

.crlf:
  call crlf
  jmp short .reset_cursor_to_di

.translate:
  mov bx, qwerty_ascii_upper
  test byte [shift_flag], 1
  jnz short .upper
  mov bx, qwerty_ascii_lower
.upper:
  xlatb

  call control_handler ; this will set al to zero if we shouldn't print it

  cmp al, 0 ; if al is zero, don't draw it
  je short .next

  call draw_character
  inc si
  add di, 2

  call check_buffer

.onemoretry:
  cmp di, 0xc00 ; 0xc00/0xfa0 is 76.8% of the screen, that sounds reasonable
  jl .reset_cursor_to_di
  ; just scroll the view here
  call scroll

.reset_cursor_to_di:
  call reset_cursor_to_di

.next:
  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  sti

  iret

check_buffer:
  mov ax, [write_buffer_addr]
  add ax, 0x200
  cmp si, ax
  jl .bottom
  call write_sector
  sub si, 0x200
  mov [es:di-1], byte 0x20
  mov byte [si], 0xff

.bottom:
  ret

control_handler: ; control is held down, al is the ASCII key.
  test byte [shift_flag], 2
  jz .no_control
  cmp al, 's'
  jne .return
  ; well they are holding down ctrl and pressed s without shift, so save
  ; need to save a partial sector and not blank this one
  call write_sector
  cmp si, 0x900
  jl .return
  sub word [last_sector], 2 ; re-use this sector if we haven't filled it yet
.return:
  ; set al to zero to avoid printing it
  mov al, 0
.no_control:
  ret

scroll: ; scroll back one line, copying 160-di to 0-(di-160)
  mov cx, di
  sub cx, 160

  cmp cx, 0
  jle .return

  push ds
  push si

  mov si, 160
  xor di, di
  push es
  pop ds

  shr cx, 1
  rep movsw

  mov cx, 80
  mov ax, 0x0720
  rep stosw

  pop si
  pop ds

  sub di, 160

.return:
  ret

write_sector: ; this is called when the buffer should be saved
  push es ; save es since int13 requires we change it

  ; si's "origin" is 0x700. in a partial-sector save si should be retained
  ; if it is an automatic save si should be reset to 0x700
  ; also when the partial save occurs it should only write from 0x700 to si
  ; not from 0x700-0x8ff. the rest of the buffer must be zeroed. this can't
  ; be too difficult. it sounds like i need three separate functions:
  ; save 0x700-to-si, clear si-to-0x900, and reset si to 0x700

  ; si is never on a valid character, so we can zero it safely

  ; don't need to touch si to write to disk (es:bx)

  mov eax, [last_sector]
  inc eax
  mov [last_sector], eax
  call lba_to_chs
  mov ah, 3
  mov al, 1
  mov dl, [boot_dev]
  push word 0
  pop es
  mov bx, [write_buffer_addr]
  clc
  int 0x13
  jc int13_error

  ; update the config sector as well
  ; es should still be zero
  mov eax, 1 ; this is 1 since lba is zero-indexed
  call lba_to_chs
  ; es should still be zero
  mov bx, sector_2
  mov ah, 3
  mov al, 1
  mov dl, [boot_dev]
  clc
  int 0x13
  jc int13_error

  pop es ; restore old es value
  ret

draw_character:
  mov [si], al
  mov [es:di], al
  mov [es:di+1], byte 0x07
  ret

;render:
;  ; Copies text from memory buffer ds:si to video buffer es:di
;  ; Stops at 0xff without copying it, puts the cursor where it would be.
;  ; Bytes are not 1-1 since video memory has an attribute byte.
;  ; The attribute byte is set to 0x07.
;
;  lodsb
;  cmp al, 0xff
;  jz .done
;
;  mov ah, 0x07
;  stosw
;  jmp render
;
;.done:
;  call reset_cursor_to_di
;  ret

max_sector: db 0
max_head: db 0
max_cylinder: dw 0
boot_dev: db 0
video_port: dw 0

times 510 - ($ - $$) db 'z' ; position the boot sector marker
dw 0xaa55

sector_2:

backspace:
  mov al, 0x20
  dec si
  sub di, 2
  call draw_character
  mov byte [si], 0xff
  ret

crlf:
  mov [si], al
  inc si
  push word 160
  mov ax, di
  cwd
  idiv word [esp]
  add esp, 2
  sub di, dx
  add di, 160
  ret

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

read_buffer_addr: dw 0x500 ; data stored from 0x500-0x6ff before writing to disk
write_buffer_addr: dw 0x700 ; data read from disk to 0x700-0x8ff when reading

; these values are overwritten during boot
shift_flag: db 0

last_sector: dd 1 ; 0 is the boot sector, 1 is the config sector
; this value is 1 on a "fresh install"

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_lower_end:
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '
qwerty_ascii_upper_end:

