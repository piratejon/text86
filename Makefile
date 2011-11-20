CC=gcc
CFLAGS=-Wall -g3
LDFLAGS=-lm

text86: text86.asm
	nasm text86.asm
	dd if=text86 of=st251.img conv=notrunc
	./disasm.sh
	xxd -l 512 text86

nosize:
	nasm -D_NOSIZE text86.asm
	./disasm.sh
	less disasm

parse: fat12parse.c
	$(CC) $(CFLAGS) $(LDFLAGS) fat12parse.c -o fat12parse

reimage: c
	./c 2>/dev/null > st251.img
	dd if=text86 of=st251.img conv=notrunc

clean:
	rm -rf c text86 st251.img

