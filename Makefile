
compile:
	nasm keyboard_sample.asm
#	ndisasm keyboard_sample -o 0x7c00 | cut --complement -c9-26 > disasm
	ndisasm keyboard_sample -o 0x7c00 > disasm
#	mousepad disasm

run:
	bochs -f ./testing

