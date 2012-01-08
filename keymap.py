#!/usr/bin/python

import sys

def build_scancode_array_from_key_string(j):
  k = list(map(ord, j))
  out = [0,0] + k[1:13] + [0,0] + k[13:25] + [0,0] + k[26:37]
  out.append(k[0])
  out.append(0)
  out.append(k[25])
  out = out + k[37:48] + [0,0,0,32]
  return out

#lower_printable = input("Please press the keys labeled:\n`1234567890-=qwertyuiop[]\\asdfghjkl;'zcxvbnm,./\n")
#upper_printable = input('Next, do these:\n~!@#$%^&*()_+QWERTYUIOP{}|ASDFGHJKL:"ZXCVBNM<>?\n')

lower_printable = "`1234567890[]',.pyfgcrl?+\\aoeuidhtns-;qjkxbmwvz"
upper_printable = "~!@#$%^&*(){}\"<>PYFGCRL?+|AOEUIDHTNS_:QJKXBMWVZ"

lower = build_scancode_array_from_key_string(lower_printable)
upper = build_scancode_array_from_key_string(upper_printable)

for c in lower:
  sys.stdout.write(chr(c))

for c in upper:
  sys.stdout.write(chr(c))

#ascii_lower: db 0,0,'1','2','3','4','5','6','7','8','9','0','-','=',0,0,'q','w','e','r','t','y','u','i','o','p','[',']',0,0,'a','s','d','f','g','h','j','k','l', 0x3b, 0x27, '`', 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '
#ascii_lower_end:
#ascii_upper: db 0,0,0x21,'@',0x23,'$','%','^','&','*','(',')','_','+',0,0,'Q','W','E','R','T','Y','U','I','O','P','{','}',0,0,'A','S','D','F','G','H','J','K','L', ':', '"', '~', 0, 0x7c, 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0, 0, 0, ' '
#ascii_upper_end:

