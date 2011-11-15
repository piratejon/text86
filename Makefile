CC=gcc
CFLAGS=-Wall -g3
LDFLAGS=-lm

text86:
	nasm text86.asm
	dd if=text86 of=st251.img conv=notrunc
	ndisasm -o 0x7c00 text86 > disasm
	xxd -l 512 text86

parse: fat12parse.c
	$(CC) $(CFLAGS) $(LDFLAGS) fat12parse.c -o fat12parse

reimage: c text86
	./c 2>/dev/null > st251.img

clean:
	rm -rf c text86 st251.img

