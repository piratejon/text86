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

mov [boot_dev], dl ; save boot device so we don't have to write a USB driver!

; first let's reset the disk subsystem just for fun
mov ah, 0
; dl is still cool
int 0x13
push 0xb800
pop es
xor di, di
; output is: ah status, cf yay/neigh
mov ax, 0xbead
call hexprint_ax
mov eax, 0x12345678
call hexprint_eax

jmp await_keypress

; al ah bl cl ch dl dh  di    es
; 00 00 00 ff ff 02 0f 00 00 00 00 -- from thinkpad t42
; 0a 00 00 ff cc 02 fe 00 00 00 00 -- from the ASUS netbook
; 00 00 04 12 4f 01 01 de ef 00 f0 -- from bochs

; thinkpad max sector number: 0b1111111111111, that's 0x05ff or 1535
;     asus max sector number: 0b1111111001100, that's 0x05cc or 1484
;    bochs max sector number: 0b1001001001111, that's 0x014f or  335

; thinkpad max head number: 0x0f
;     asus max head number: 0xfe
;    bochs max head number: 0x01


;call hexprint_al ; print al
;shr ax, 8
;call hexprint_al ; print ah
;mov ax, bx
;call hexprint_al ; print bl
;mov ax, cx
;call hexprint_al ; print cl
;shr ax, 8
;call hexprint_al ; print ch
;mov ax, dx
;call hexprint_al ; print dl
;shr ax, 8
;call hexprint_al ; print dh
;pop ax ; di
;call hexprint_al ; print lo byte of di
;shr ax, 8
;call hexprint_al ; print hi byte of di
;pop ax ; es
;call hexprint_al ; print lo byte of es
;shr ax, 8
;call hexprint_al ; print hi byte of es
;mov al, '!'
;stosb
;inc di

jmp await_keypress

; can't we all agree on the address of lba sector zero?
; lba 0:
; sector = (lba mod total_sectors) + 1
; cylhead = lba div total_sectors
; head = cylhead mod (total_heads + 1)
; cyl = cylhead div (total_heads + 1)
; so it looks like head and cyl are the quotient and remainder of:
;    cylhead div (total heads + 1)

lba_to_chs: ; input is ax = lba, output is suitable for int 13 ah=02 or ah=03
; output:
; ch = low byte of cyl#
; cl bits 0-5: sector num
; cl bits 6,7: high bits of cyl #
; dh = head #
;  ret

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

; thing has a couple parts:
; read the kernel from the disk

; read us up eh!

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
.spin:
  in al, 0x64
  and al, 0x01
  jz short .spin

  in al, 0x60
  ;               now al has the char(mander)
  ; 'in' is how we BASICally say peek(achu)
  ;      'out' used to be called poke(emon)

  ; is this a control character?
;  cmp al, 0x0e
;  je .backspace
  cmp al, 0x2a
  je short .shift_down
  cmp al, 0x36
  je short .shift_down
  cmp al, 0xaa
  je short .shift_up
  cmp al, 0xb6
  je short .shift_up

  cmp al, 58
  jae .next

  jmp short .translate

.shift_down:
  or byte [shift_flag], 1
  jmp short .next

.shift_up:
  and byte [shift_flag], 0
  jmp short .next

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

.next:
  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  jnz short .spin
                
  iret

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '

shift_flag: db 0

boot_dev: dw 0
last_sector: dw 0
last_vid_byte: dw 0
BEGIN_OVERWRITE:
times 444 - ($ - $$) db 0x00 ; round out the boot sector

dw 0x0 ; why oughtn't i utilize this word? #OCCUPYBOOTSECTORS

times 510 - ($ - $$) db 0xcd ; partition table
dw 0xaa55

;code_page_2:
;db 0x54,0x07,0x68,0x07,0x69,0x07,0x73,0x07,0x20,0x07,0x69,0x07,0x73,0x07,0x20,0x07,0x73,0x07,0x6f,0x07,0x6d,0x07,0x65,0x07,0x20,0x07,0x73,0x07,0x61,0x07,0x6d,0x07,0x70,0x07,0x6c,0x07,0x65,0x07,0x20,0x07,0x74,0x07,0x65,0x07,0x78,0x07,0x74,0x07,0x20,0x07,0x77,0x07,0x68,0x07,0x69,0x07,0x63,0x07,0x68,0x07
;db 0x20,0x07,0x49,0x07,0x20,0x07,0x77,0x07,0x61,0x07,0x6e,0x07,0x74,0x07,0x20,0x07,0x74,0x07,0x6f,0x07,0x20,0x07,0x73,0x07,0x65,0x07,0x65,0x07,0x20,0x07,0x6f,0x07,0x6e,0x07,0x20,0x07,0x74,0x07,0x68,0x07,0x65,0x07,0x20,0x07,0x73,0x07,0x63,0x07,0x72,0x07,0x65,0x07,0x65,0x07,0x6e,0x07,0x2e,0x07,0x0a,0x07
;db 'here is some great sample text that i would really like to see read into RAM by int 13h!'

