#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <math.h>

FAT_FIELD_INDEX field_index;
char ** field;

// 0 means stop
int field_size[] = {
  3, 8, 2, 1, 2, 1, 2, 2, 1, 2, 2, 2, 4, 4, // normal BPB
  1, 1, 1, 4, 11, 8, 448, 2,  // EBB
  0 // stop codon
};


typedef enum {
  BS_jmpBoot,
  BS_OEMName,
  BPB_BytsPerSec,
  BPB_SecPerClus,
  BPB_RsvdSecCnt,
  BPB_NumFATs,
  BPB_RootEntCnt,
  BPB_TotSec16,
  BPB_Media,
  BPB_FATSz16,
  BPB_SecPerTrk,
  BPB_NumHeads,
  BPB_HiddSec,
  BPB_TotSec32,
  BS_DrvNum,
  BS_Reserved1,
  BS_BootSig,
  BS_VolID,
  BS_VolLab,
  BS_FilSysType,
  BOOT_CODE,
  MBR_SIG,
  STOP_CODON
} FAT_FIELD_INDEX;

const char * FIELD_NAMES[] = {
  "BS_jmpBoot",
  "BS_OEMName",
  "BPB_BytsPerSec",
  "BPB_SecPerClus",
  "BPB_RsvdSecCnt",
  "BPB_NumFATs",
  "BPB_RootEntCnt",
  "BPB_TotSec16",
  "BPB_Media",
  "BPB_FATSz16",
  "BPB_SecPerTrk",
  "BPB_NumHeads",
  "BPB_HiddSec",
  "BPB_TotSec32",
  "BS_DrvNum",
  "BS_Reserved1",
  "BS_BootSig",
  "BS_VolID",
  "BS_VolLab",
  "BS_FilSysType",
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



int main ( int arfc, char ** arfv ) {

  FILE * fin = stdin;
  FAT_FIELD_INDEX field_index;
  char ** field;

  if ( 2 == arfc ) {
    fin = fopen(arfv[1], "r");
    if ( !fin ) {
      printf("failed to open %s errno %d\n", arfv[1], errno);
      exit(1);
    }
  }

  field = malloc((sizeof*field)*STOP_CODON);

  for ( field_index = 0; field_index < STOP_CODON; field_index ++ ) {
    field[field_index] = malloc ( (sizeof*field[field_index])*field_size[field_index] );
    fread(field[field_index], field_size[field_index], sizeof*field[field_index], fin);
    if ( BOOT_CODE != field_index ) {
      printf("%s: ", FIELD_NAMES[field_index]);
      dump(stdout, field[field_index], field_size[field_index]);
      printf("\n");
    }
  }

  int RootDirSectors;
  printf("RootDirSectors: %d\n", RootDirSectors = ceil((field[BPB_RootEntCnt]*32) + (field_index[BPB_BytsPerSec]-1)) / field[BPB_BytsPerSec]);

  if ( stdin != fin ) fclose(stdin);

  for  ( field_index = 0; field_index < STOP_CODON; field_index ++ ) {
    free(field[field_index]);
  }

  free(field);

  return 0;
}

