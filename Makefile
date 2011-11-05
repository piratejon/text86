CC=gcc
CFLAGS=-Wall -g3

compile:
	nasm reboot.asm

run: compile
	bochs -f ./testing

parse: fat12parse.c
	$(CC) $(CFLAGS) fat12parse.c -o fat12parse

write:
	sudo dd if=reboot of=/dev/sdb bs=512 count=1

