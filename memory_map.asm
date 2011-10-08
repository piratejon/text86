; DIRECTLY TRANSCRIBED FROM http://wiki.osdev.org/PS2_Keyboard !!!
; YES, LITERALLY TRANSCRIBED, I TYPED IT BY HAND
top:
use16
org 0x7C00

; where our records will be stored
push mem_map
pop di

; find all the ram -- from http://wiki.osdev.org/How_Do_I_Determine_The_Amount_Of_RAM#Getting_an_E820_Memory_Map
  xor ebx, ebx
  push bx
  pop es
  xor bp, bp
  mov edx, 0x0534d4150
  mov eax, 0xe820
  mov [es:di+20], dword 1
  mov ecx, 24
  int 0x15
  jc short .failed
  mov edx, 0x0534d4150
  cmp eax, edx
  jne short .failed
  test ebx, ebx
  je short .failed
  jmp short .jmpin
.e820lp:
  mov eax, 0xe820
  mov [es:di+20], dword 1
  mov ecx, 24
  int 0x15
  jc short .e820f
  mov edx, 0x0534d4150
.jmpin:
  jcxz .skipent
  cmp cl, 20
  jbe short .notext
  test byte [es:di+20], 1
  je short .skipent
.notext:
  mov ecx, [es:di+8]
  or ecx, [es:di+12]
  jz .skipent
  inc bp
  add di, 24
.skipent:
  test ebx, ebx
  jne short .e820lp
.e820f:
  ; mov [mmap_ent], bp
  ; bp has the count of entries
  clc
;  ret
.failed:
;  stc
;  ret

; yeah right, we couldn't have failed ...

; all our string ops move forward
  cld

; initialize the keyboard interrupt handler
;  cli
;  xor ax, ax
;  push ax
;  pop ds
;  mov word[ds:(9*4)], keyboard_handler
;  mov word[ds:(9*4)+2], 0

; reset the screen b800:0-b800:7c0, that's b8000-b87cf
  push 0xb800
  pop es
  xor di,di
  mov cx, 2000
  ; mov ax, 0x7820
  mov ax, 0x0700
  ;repnz stosw

  push bp
  pop cx
  inc cx
  lea si, [mem_map]

fun_loop:

  push cx

  mov cx, 8
  call write_cx_bytes_to_video_memory

  mov al, 0x20
  stosb
  inc di

  mov cx, 8
  call write_cx_bytes_to_video_memory

  mov al, 0x20
  stosb
  inc di

  mov cx, 8
  call write_cx_bytes_to_video_memory

  add di, 48

  pop cx
  loop fun_loop

  hlt

write_cx_bytes_to_video_memory:
  mov al, [si]
  inc si
  call write_al_to_video_memory
  loop write_cx_bytes_to_video_memory

write_al_to_video_memory:
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

  ret

  hlt

; initialize the buffer and index
  mov cx, pbuffer
  shr cx, 4
  mov es, cx
  ;;xor di, di
  mov di, 0x3e8

; clear the shift flag
  xor cl, cl

; ds is scancode-to-ascii LUT offset
  xor ax, ax
  push ax
  pop ds

; start the "main" loop by turning on interrupts
  sti   
  jmp $

keyboard_handler:
  ; pushf ; push all flags!

.spin: ; interrupt indicates key pressed; dizzyloop til read-ok
  in al, 0x64
  and al, 0x01
  jz .spin

  in al, 0x60
  ; now al has the char(mander)
  ; 'in' is how we BASICally say peek(achu)
  ; 'out' used to be called poke(emon)

  ; is this a control character?
  cmp al, 0x0e ; backspace
  je .backspace
  cmp al, 0x2a
  je .shift_down
  cmp al, 0x36
  je .shift_down
  cmp al, 0xaa
  je .shift_up
  cmp al, 0xb6
  je .shift_up

  jmp .translate

.backspace:
  cmp di, 2
  jl .done ; are we already at the beginning?
  sub di, 2
  mov byte [es:di], 0x20
  jmp .blit

.shift_down:
  or cl, 1
  jmp .done

.shift_up:
  and cl, 0
  jmp .done

.crlf:
  jmp .done

  ; here the scan code is translated to ascii and drawn
.translate:
  mov bx, qwerty_ascii_upper
  test cl, 1
  jnz .upper
  mov bx, qwerty_ascii_lower
.upper:
  push 0
  pop ds
  xlatb
  cmp al, 0
  je .done

.draw:
  mov ah, 0x78
  mov [es:di], ax
  add di, 2

.blit:
; movs from address DS:(E)SI to address ES:(E)DI
  push cx ; save the shift flag
  push di ; save the buffer index
  xor si, si
  xor di, di
  push 0xb800
  push es
  pop ds
  pop es
  mov cx, 1920
  repnz movsw
  pop di ; restore the buffer index
  pop cx ; restore the shift flag
  push ds
  pop es

.done:

  ; don't be lame and leave the brogrammable interrupt controller hangin'
  mov al, 0x20
  out 0x20, al

  ; popf

iret

qwerty_ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
qwerty_ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '

pbuffer: dw 0 ; pointer to the buffer in memory
pcursor: dw 0 ; cursor offset from start of buffer
pwindow: dw 0 ; address of first character to display at 0xb800, for scrolling

mem_map:

times 510-($-$$) db 0
dw 0xAA55

times 1474560 - ($ - $$) db 0x20 ; our "filesystem"

