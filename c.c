#include <stdlib.h>
#include <stdio.h>

int main ( int arfc, char ** arfv ) {
  if ( arfc != 2 ) {
    printf("need a single argument\n");
    return 0;
  }

  int limit = atoi(arfv[1]);
  int i;

  for ( i = 0; i < (limit/(sizeof i)); ++ i ) {
    fwrite(&i, sizeof i, 1, stdout);
  }

  return 0;
}

