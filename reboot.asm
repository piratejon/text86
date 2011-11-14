top:
bits 16
org 0x7c00

FAT_HEADER:
.jmp: jmp short .boot_code
.nop: nop
.oem: db 'roflmfao' ; 64 bits of ascii flavored botulism, TODO: ABUSE ME!
.bytes_per_sector: dw 0x200 ; 512 byte sectors
.sectors_per_cluster: db 4 ; sectors per cluster
.reserved_sectors: dw 2 ; reserved sectors -- the boot sector and kernel, i guess?
.number_of_fats: db 2 ; number of FATs lol
.number_of_dirents: dw 0x200 ; number of directory entries?
.sectors_in_volume: dw 0x100 ; sectors in volume
.media_descriptor_type: db 0xf8 ; media descriptor type
.sectors_per_fat: dw 1 ; sectors per fat
.sectors_per_track: dw 0x20 ; sectors per track
.heads: dw 0x40 ; heads
.hidden_sectors: dd 0 ; hidden_sectors ; TODO Abuse me?
.large_sectors: dd 0 ; large_sectors ; TODO Abuse me?
.drive_number: db 0 ; drive_number
.signature: db 0x29 ; signature
.serial: dd 0 ; volume serial, ignorable ;TODO: ABUSE ME!
.volume_label: db 'volumelabel' ; space-padded volume label, length 11 ; TODO: ABUSE ME!
.system_id: dd 0xdeadc0d3, 0xc0c0daff; sysid, ignored as untrusted ; TODO: ABUSE ME!
.boot_code:

boot_code:

cli ; we are getting ready don't let anyone interrupt us

push 0
pop es
push 0
pop ds

mov [boot_dev], dl ; save boot device so we don't have to write a USB driver!

mov ax, [0x463]
mov [video_port], ax

; first let's reset the disk subsystem just for fun
mov ah, 0
; dl is still cool
int 0x13
jc int13_error

; now disk subsystem is reset
; now we can read info about the drive!
mov ah, 8
mov dl, [boot_dev]
push word 0
pop es
xor di, di
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

mov eax, 83639
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

mov eax, [sector_2]
call hexprint_eax

; now we should have a good keymap!

jmp await_keypress

lba_to_chs: ; converts zero-indexed LBA sector eax to int13 CHS
; conversion formula:
  ; sector = (lba % max_sector ) + 1
  ; cylhead = ( lba / max_sector )
  ; head = cylhead % (max_head+1)
  ; cylinder = cylhead / (max_head+1)

; registers:
  ; ch = low 8 bits of cylinder #
  ; cl bits 0-5: sector #
  ; cl bits 6-7: high 2 bits of cylinder #
  ; dh = head #

; cwd/cdq sign-extends al/ax into dx:ax or edx:eax

; idiv r/m
  ; divides ah:al by r/m8, al=quotient, ah=remainder
  ; divides dx:ax by r/m16, ax=quotient, dx=remainder
  ; divides edx:eax by r/m32, eax=quotient, dx=remainder

  push ebx
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
  pop ebx

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


boot_dev: db 0
shift_flag: db 0
max_sector: db 0
max_head: db 0
max_cylinder: dw 0
video_port: dw 0
last_vid_byte: dw 0

BEGIN_OVERWRITE:
times 444 - ($ - $$) db 0x00 ; round out the boot sector

dw 0x0 ; why oughtn't i utilize this word? #OCCUPYBOOTSECTORS

times 510 - ($ - $$) db 0xcd ; partition table
dw 0xaa55

sector_2:

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
  jmp short .next

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

  mov al, 0xff
  stosb
  mov al, 0x00
  stosb

  sub di, 2

.reset_cursor_to_di:
  call reset_cursor_to_di

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

last_pos_written: dd 0
                ; initial values for data
last_cylinder: dw 0  ; 0
last_head: dw 0 ; 0
last_sector: dw 0  ; 2

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_lower_end:
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '
qwerty_ascii_upper_end:

