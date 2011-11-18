#!/bin/bash

ndisasm -o 0x7c00 text86 > tmp_disasm

paste -d' ' <(cut --complement -c 10- tmp_disasm) <(awk '{print length($2)/2}' tmp_disasm) <(cut -c 10- tmp_disasm ) | awk '/00007[^E]../,/^00007E../' > disasm

rm tmp_disasm

