#include <stdlib.h>
#include <stdio.h>

int main ( int arfc, char ** arfv ) {
  int i, limit;

  if ( arfc != 2 ) {
    fprintf(stderr, "no argument, defaulting to 820*6*17*512\n");
    limit = 820*6*17*512;
  } else {
    limit = atoi(arfv[1]);
  }

  for ( i = 0; i < (limit/(sizeof i)); ++ i ) {
    fwrite(&i, sizeof i, 1, stdout);
  }

  return 0;
}

