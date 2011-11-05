#include <stdlib.h>
#include <stdio.h>
#include <errno.h>

typedef enum {
  JMP,
  OEM,
  BYTES_PER_SECTOR,
  SECTORS_PER_CLUSTER,
  RESERVED_SECTORS,
  NUMBER_OF_FATS,
  NUMBER_OF_DIRENTS,
  SECTORS_IN_VOLUME,
  MEDIA_DESCRIPTOR_TYPE,
  SECTORS_PER_FAT,
  SECTORS_PER_TRACK,
  HEADS,
  HIDDEN_SECTORS,
  LARGE_SECTORS,
  DRIVE_NUMBER,
  FLAGS,
  SIGNATURE,
  SERIAL,
  LABEL,
  SYSTEM_ID,
  BOOT_CODE,
  MBR_SIG,
  STOP_CODON
} FAT_FIELD_INDEX;

const char * FIELD_NAMES[] = {
  "JMP",
  "OEM",
  "BYTES_PER_SECTOR",
  "SECTORS_PER_CLUSTER",
  "RESERVED_SECTORS",
  "NUMBER_OF_FATS",
  "NUMBER_OF_DIRENTS",
  "SECTORS_IN_VOLUME",
  "MEDIA_DESCRIPTOR_TYPE",
  "SECTORS_PER_FAT",
  "SECTORS_PER_TRACK",
  "HEADS",
  "HIDDEN_SECTORS",
  "LARGE_SECTORS",
  "DRIVE_NUMBER",
  "FLAGS",
  "SIGNATURE",
  "SERIAL",
  "LABEL",
  "SYSTEM_ID",
  "BOOT_CODE",
  "MBR_SIG",
  "STOP_CODON"
};

void dump ( FILE * fout, char * buf, int count ) {
  int i;
  if ( 2 == count )
    while ( count -- > 0 )
      printf("%02x", (unsigned char)buf[count]);
  else
    for ( i = 0; i < count; ++ i )
      printf("%02x", (unsigned char)buf[i]);
}

// 0 means stop
int field_size[] = {
  3, 8, 2, 1, 2, 1, 2, 2, 1, 2, 2, 2, 4, 4, // normal BPB
  1, 1, 1, 4, 11, 8, 448, 2,  // EBB
  0 // stop codon
};

int main ( int arfc, char ** arfv ) {

  FILE * fin = stdin;
  FAT_FIELD_INDEX field_index;

  if ( 2 == arfc ) {
    fin = fopen(arfv[1], "r");
    if ( !fin ) {
      printf("failed to open %s errno %d\n", arfv[1], errno);
      exit(1);
    }
  }

  for ( field_index = 0; field_index < STOP_CODON; field_index ++ ) {
    char * buf = malloc ( (sizeof*buf)*field_size[field_index] );
    fread(buf, field_size[field_index], sizeof*buf, fin);
    printf("%s: ", FIELD_NAMES[field_index]);
    dump(stdout, buf, field_size[field_index]);
    printf("\n");
    free(buf);
  }

  if ( stdin != fin ) fclose(stdin);

  return 0;
}

