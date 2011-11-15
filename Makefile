CC=gcc
CFLAGS=-Wall -g3
LDFLAGS=-lm

compile:
	nasm reboot.asm
	dd if=reboot of=st251.img conv=notrunc
	ndisasm -o 0x7c00 reboot > disasm
	xxd -l 512 reboot

run: compile
	bochs -f ./testing

parse: fat12parse.c
	$(CC) $(CFLAGS) $(LDFLAGS) fat12parse.c -o fat12parse

write:
	sudo dd if=reboot of=/dev/sdb bs=512 count=1

reimage:
	./c 2>/dev/null > st251.img

