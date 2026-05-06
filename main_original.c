#define _XOPEN_SOURCE 700
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

/*
 * Matrix multiply
 */

void mult(double ** a, double ** b, double ** res, int r, int c){
  for(int i=0;i<r;i++){
    for(int j=0;j<c;j++){
      for(int k=0;k<r;k++){
        res[i][j] += a[i][k] * b[k][j];
      }
    }
  }
}

void print(double ** a, int r, int c){

  printf("Printing first 5 rows and 5 columns");
  int r1 = r;
  int c1 = c;

  r = r > 5 ? 5 : r;
  c = c > 5 ? 5 : c;

  printf("\n");
  for(int row=0;row<r;row++){
    for(int col=0;col<c;col++){
      printf("%.2lf ", a[row][col]);
    }
    printf("\n");
  }
  if(r1 > 5 || c1 > 5) {
    printf("... [%d x %d]\n", r1, c1);
  }

  printf("\n");
}

double ** allocateMatrix(int r, int c){
  double ** m = (double **)malloc(r * sizeof(double *));
  for(int i=0;i<r;i++){
    m[i] = (double *)malloc(c * sizeof(double));
  }
  return m;
}

void freeMatrix(double ** m, int r){
  for(int i=0;i<r;i++){
    free(m[i]);
  }
  free(m);
}

int main(int argc, char *argv[]) {

    if (argc < 4) {
        printf("Usage: main_original <operation> <row> <col>\n");

        return 1;
    }

    int operation       = atoi(argv[1]);
    int r               = atoi(argv[2]);
    int c               = atoi(argv[3]);

    if(operation){

      printf("Operation: ############ Matrix-multiply row = %d, col = %d\n", r, c);

      double ** a   = allocateMatrix(r, c);
      double ** b   = allocateMatrix(r, c);
      double ** res = allocateMatrix(r, c);

      double result    = 0.0;

      printf("Input: ############ row = %d, col = %d\n", r, c);

      // init data
      for(int i=0;i<r;i++){
        for(int j=0;j<c;j++){
          a[i][j] = (double)(i + j);
          b[i][j] = (double)(i + j);
          res[i][j] = 0;
        }
      }

      printf("Matrix a ############\n");
      print(a, r, c);
      printf("Matrix b ############\n");
      print(b, r, c);

      mult(a, b, res, r, c);

      printf("Matrix res ############\n");
      print(res, r, c);

      freeMatrix(a, r);
      freeMatrix(b, r);
      freeMatrix(res, r);

    } else {

      printf("Operation: $$$$$$$$ Matrix-multiply and Matrix-add row = %d, col = %d\n", r, c);

      double ** a   = allocateMatrix(r, c);
      double ** b   = allocateMatrix(r, c);
      double ** res = allocateMatrix(r, c);

      double result    = 0.0;

      printf("Input: $$$$$$$$ row = %d, col = %d\n", r, c);

      // init data
      for(int i=0;i<r;i++){
        for(int j=0;j<c;j++){
          a[i][j] = (double)(i + j);
          b[i][j] = (double)(i + j);
          res[i][j] = 0;
        }
      }

      printf("Matrix a $$$$$$$$\n");
      print(a, r, c);
      printf("Matrix b $$$$$$$$\n");
      print(b, r, c);

      mult(a, b, res, r, c);

      printf("Matrix res $$$$$$$$\n");
      print(res, r, c);

      freeMatrix(a, r);
      freeMatrix(b, r);
      freeMatrix(res, r);
    }

    return 0;
}
