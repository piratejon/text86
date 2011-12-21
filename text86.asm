top:
bits 16
org 0x7c00

; WHAT: constants hard-coding known-available addresses or values
%define default_attribute 0x07

%define kf_shift_on       0x01
%define kf_shift_off      ~kf_shift_on
%define kf_ctrl_on        0x02
%define kf_ctrl_off       ~kf_ctrl_on

%define max_sector        0x500
%define max_head          0x502
%define max_cylinder      0x504
%define boot_dev          0x506

%define write_buffer      0x600
%define end_of_buffer     0x7bff
; no need to protect parts of the initialization routine, but want
; to make sure code stays out of the data

%define vga_io_port       0x463
%define video_memory      0xb800

boot_code:

cli ; we are getting ready don't let anyone interrupt us

; WHAT: reset the disk subsystem with int13/ah=0
; right off the bat we need zeros in ax, dh, es, ds, and di

xor ax, ax
push ax
push ax
mov dh, ah
pop ds
pop es
mov di, ax

mov [boot_dev], dx ; save boot device
; later, word [boot_dev] will make dh 0 and dl=boot_dev
; byte [boot_dev] will make dl=boot_dev
; costs two bytes with xor dh, dh

; reset the disk subsystem
int 0x13
jc short int13_error

; WHAT: read the drive geometry with int13/ah=8
mov ah, 8
;mov dl, [boot_dev]
; es:di should still be 0:0
; dl should still be the drive
int 0x13
jc short int13_error

; WHAT: save the drive geometry in memory
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

; WHAT: load the config sector; hard-coded register values for CHS 0/0/2
; statically set registers for fixed sector 1
; ch = low 8 bits of cyl #
; cl bits 0-5 = sector # (needs to be 2 since CHS sectors are 1-indexed)
; dh = heads, should be 0 here
push dword 2
pop cx
pop dx
mov dl, [boot_dev]
mov ax, 0x0201 ; int13/ah=2, al=#sectors to read
mov bx, config_sector
int 0x13
jc short int13_error

; WHAT: restore the last sector and reset si
mov cx, [cx_int13]
mov dh, [dh_int13]
mov ax, 0x201 ; ah=2 read sector, al=01 # of sectors
mov bx, write_buffer
int 0x13
jc short int13_error
mov si, write_buffer

; WHAT: draw the contents of the buffer
; this also gets both si and di to the correct positions
push video_memory
pop es

mov al, default_attribute
mov cx, [si_at_last_save]
draw_buffer:
  movsb ; copy the character
  stosb ; set the attribute
  loopnz draw_buffer

push di
mov cx, 2000
sub cx, di
mov ax, 0x0720
rep stosw
pop di

; WHAT: setup the keyboard interrupt handler, write buffer, and video pointer
mov eax, keyboard_handler
mov [36], eax

; WHAT: start the main loop
main_loop:
  xor bp, bp
  sti
do_not_overwrite_the_following_code_with_data:
  jmp short $

; WHAT: subroutine int13_error: print the int13 al status followed by a red-highlighted 'e'
int13_error:
  push word video_memory
  pop es
  xor di, di
  call small_hexprint_al
  mov ax, 0x4065
;  mov al, 'e'
;  stosb
;  mov al, 0x40
;  stosb
  stosw
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

; WHAT: subroutine hexprint_al: write the value of al as a human-readable 2-character hex byte to es:di
;hexprint_al:
;  push ax
;  shr al, 4
;  call hexprint_low_nibble_of_al
;  pop ax
;  call hexprint_low_nibble_of_al
;  ret
;
;; WHAT: subroutine hexprint_low_nibble_of_al: write the single-digit value of al & 0xf in hex to es:di
;hexprint_low_nibble_of_al:
;  mov ah, default_attribute
;  and al, 0x0f
;  cmp al, 0x09
;  jle short .num
;  add al, ah
;.num:
;  add al, 0x30
;  stosw
;
;  ret

small_hexprint_al:
  push word 0
  pop ds
  mov bx, al_conv_ascii
  mov ah, default_attribute
  push ax
  and al, 0xf0
  xlatb
  stosw
  pop ax
  shr al, 4
  xlatb
  stosw
  ret

; WHAT: keyboard interrupt handler
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
  push ax
  call control_check
  pop ax

  cmp al, qwerty_ascii_lower_end - qwerty_ascii_lower + 1
  jae short .post_draw

.translate:
  mov bx, qwerty_ascii_upper
  test bp, kf_shift_on
  jnz short .upper
  mov bx, qwerty_ascii_lower
.upper:
  xlatb

  test bp, kf_ctrl_on
  jz short .draw

; control characters
  cmp al, 's'
  jne short .post_draw
  push es
  call save
  pop es
  jmp short .post_draw

.draw:
  test al, al
  jz short .next

  mov [si], al
  inc si
  mov ah, default_attribute
  stosw

.post_draw:

.scroll_check: ; scroll down one line, copying [160,di] to [0,di-160]
  cmp di, 0xc00 ; only do this if we are about 3/4ths down the screen
  jl short .end_scroll_check

  push di
  xor di, di
.scroll_loop:
  mov ax, [es:di+160]
  stosw
  cmp di, 0xc00
  jl .scroll_loop
  pop di

.end_scroll_check:

.reset_cursor_to_di: ; can be replaced with a call to int10?
  ; cursor position is row+(col*80), which happens to be half of di
  mov bx, di
  shr bx, 1

  mov dx, [vga_io_port]
  mov al, 0x0f ; selects the low word of the cursor position
  out dx, al

  inc dx
  mov ax, bx
  out dx, al

  dec dx
  mov al, 0x0e ; selects the high word of the cursor position
  out dx, al

  inc dx
  mov al, bh
  out dx, al

.next:
  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  sti
  iret

control_check:
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

  ret ; didn't find a match, return

.shift_down:
  or bp, kf_shift_on
  ret

.shift_up:
  and bp, kf_shift_off
  ret

.ctrl_down:
  or bp, kf_ctrl_on
  ret

.ctrl_up:
  and bp, kf_ctrl_off
  ret

.backspace:
  test di, di
  jz short .no_bksp
  cmp si, write_buffer
  je short .no_bksp
  mov ax, 0x0700
  dec si
  dec di
  dec di ; two decs is less than a sub
  mov [si], al
  mov [es:di], ax
.no_bksp:

  ret

.crlf:
  push bp
  mov [si], al
  inc si
  mov bp, 160
  mov ax, di
  cwd
  idiv bp
  sub di, dx
  add di, bp
  pop bp

  ret

save:
; writing [write_buffer,si) to the disk, one sector at a time
; caller should save es
  push word 0
  pop es
  mov bx, write_buffer

  mov cx, [cx_int13]
  mov dh, [dh_int13]
  mov dl, [boot_dev]
.loop:
  ;push cx
  ;push dx ; does int13/ah=3 trash registers cx&dh?
  call write_sector
  ;pop dx ; we save and restore these so the increment works proper
  ;pop cx
  add bx, 0x200
  cmp bx, si
  jge short .done_writing

;increment_chs_sector: ; increment one sector in a int13 CHS cx+dh
  mov al, cl
  and al, 0x3f ; test the low six bits only
  cmp al, [max_sector]
  jl short .increment_sector
  ; sector wrapped, reset to minimum value of 1
  and cl, 0xc0
  inc cl
  ; try to increment the head
  cmp dh, [max_head]
  jl short .increment_head
  ; head wrapped, reset to minimum value of 0
  xor dh, dh
  ; try to increment the 10-bit cylinder number
  inc ch
  jno short .no_overflow
  ; here, the cylinder number overflowed 8 bits
  ; cmp ax, [max_cylinder]
  ; jge int13_error ; jge disk_full ; LOL
  add cl, 0x40
.no_overflow:
  jmp short .chs_inc_bottom
.increment_head:
  inc dh
  jmp short .chs_inc_bottom
.increment_sector:
  inc cl

.chs_inc_bottom:
  ; this saves the changes we made to the config
  ; it is committed to disk below when save_config is called
  mov [cx_int13], cx
  mov [dh_int13], dh
  jmp short .loop

.done_writing:

  ; move the current sector back to the starting sector
  mov cx, si
  and cx, 0x01ff
  and si, 0xfe00
  mov bx, write_buffer
.buffer_scootch:
  lodsb
  mov [bx], al
  inc bx
  loopnz .buffer_scootch

  mov si, bx

  and bx, 0x1ff
  mov [si_at_last_save], bx

save_config:
  ;call lba_to_chs ; static lba sector 1, chs sector 2
  ; need dh=0,ch=0,cl=2
  mov cx, 2
  mov dx, [boot_dev]
  mov bx, config_sector
;  call write_sector
;  ret
; no need to call/ret when the thing is right below us

write_sector: ; always goes to the same sector
  ; already called lba_to_chs, and bx is loaded
  mov ax, 0x301
  int 0x13
  jc int13_error
  ret

%ifndef _NOSIZE
times 510 - ($ - $$) db 0x21 ; position the bootsector marker 0xaa55
%endif
; using indicator such as ! visualizes remaining space with xxd -l 512
dw 0xaa55

config_sector:

; last sector written to. the default value corresponds to a "blank slate"
cx_int13: dw 3 ; i guess this assumes there are at least 3 sectors/track :-/
dh_int13: db 0
si_at_last_save: dw 0

al_conv_ascii: db '0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_lower_end:
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '
qwerty_ascii_upper_end:

