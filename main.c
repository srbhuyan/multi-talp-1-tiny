#define _XOPEN_SOURCE 700
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <thpool.h>
#include <pthread.h>
#include <stdatomic.h>
#include <string.h>

// Global threadpool for parallel execution
static threadpool global_thpool = NULL;
static int num_threads = 4;

// Initialize global threadpool
void init_global_threadpool() {
    if (global_thpool == NULL) {
        global_thpool = thpool_init(num_threads);
    }
}

// Cleanup global threadpool
void cleanup_global_threadpool() {
    if (global_thpool != NULL) {
        thpool_destroy(global_thpool);
        global_thpool = NULL;
    }
}

typedef struct {
  int thread_id;
  int start;
  int end;
  double** a;
  double** b;
  int c;
  int r;
  double** res;
} ThreadData_mult_line5_0;

void thread_function_mult_line5_0(void* arg) {
  ThreadData_mult_line5_0* thread_data = (ThreadData_mult_line5_0*)arg;

  double** a = thread_data->a;
  double** b = thread_data->b;
  int c = thread_data->c;
  int r = thread_data->r;
  double** res = thread_data->res;

  for (int i = thread_data->start; i < thread_data->end; i++) {
    for(int j=0;j<c;j++){
      for(int k=0;k<r;k++){
        res[i][j] += a[i][k] * b[k][j];
      }
    }
  }
}

void mult(double ** a, double ** b, double ** res, int r, int c){
  {
    // Parallel execution using global thread pool with num_threads threads
    // Loop bound variable: r

    int total_iterations = r;
    int chunk_size = total_iterations / num_threads;
    if (chunk_size == 0) chunk_size = 1;

    // Allocate array of thread data structures
    ThreadData_mult_line5_0* thread_data_array = malloc(num_threads * sizeof(ThreadData_mult_line5_0));

    for (int t = 0; t < num_threads; t++) {
      ThreadData_mult_line5_0* thread_data = &thread_data_array[t];
      thread_data->thread_id = t;
      thread_data->start = t * chunk_size;
      thread_data->end = (t == num_threads - 1) ? total_iterations : (t + 1) * chunk_size;
      thread_data->a = a;
      thread_data->b = b;
      thread_data->c = c;
      thread_data->r = r;
      thread_data->res = res;
      if (thread_data->start < total_iterations) {
        thpool_add_work(global_thpool, thread_function_mult_line5_0, thread_data);
      }
    }

    thpool_wait(global_thpool);
    free(thread_data_array);
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

typedef struct {
  int thread_id;
  int start;
  int end;
  double** a;
  double** b;
  int c;
  int r;
  double** res;
} ThreadData_main_line71_0;

void thread_function_main_line71_0(void* arg) {
  ThreadData_main_line71_0* thread_data = (ThreadData_main_line71_0*)arg;

  double** a = thread_data->a;
  double** b = thread_data->b;
  int c = thread_data->c;
  int r = thread_data->r;
  double** res = thread_data->res;

  for (int i = thread_data->start; i < thread_data->end; i++) {
    for(int j=0;j<c;j++){
      a[i][j] = (double)(i + j);
      b[i][j] = (double)(i + j);
      res[i][j] = 0;
    }
  }
}

int main(int argc, char *argv[]) {

    if (argc < 5) {
        printf("Usage: main_original <operation> <row> <col> <num_threads>\n");
        return 1;
    }

    // Get thread pool and num_threads
    num_threads = atoi(argv[argc-1]);
    init_global_threadpool();

    int operation       = atoi(argv[1]);
    int r               = atoi(argv[2]);
    int c               = atoi(argv[3]);

    if(operation) {

      double ** a   = allocateMatrix(r, c);
      double ** b   = allocateMatrix(r, c);
      double ** res = allocateMatrix(r, c);

      double result    = 0.0;

      printf("Input: ############ row = %d, col = %d\n", r, c);

      // init data
      {
        // Parallel execution using global thread pool with num_threads threads
        // Loop bound variable: r

        int total_iterations = r;
        int chunk_size = total_iterations / num_threads;
        if (chunk_size == 0) chunk_size = 1;

        // Allocate array of thread data structures
        ThreadData_main_line71_0* thread_data_array = malloc(num_threads * sizeof(ThreadData_main_line71_0));

        for (int t = 0; t < num_threads; t++) {
          ThreadData_main_line71_0* thread_data = &thread_data_array[t];
          thread_data->thread_id = t;
          thread_data->start = t * chunk_size;
          thread_data->end = (t == num_threads - 1) ? total_iterations : (t + 1) * chunk_size;
          thread_data->a = a;
          thread_data->b = b;
          thread_data->c = c;
          thread_data->r = r;
          thread_data->res = res;
          if (thread_data->start < total_iterations) {
            thpool_add_work(global_thpool, thread_function_main_line71_0, thread_data);
          }
        }

        thpool_wait(global_thpool);
        free(thread_data_array);
      }

      printf("Matrix ############ a\n");
      print(a, r, c);
      printf("Matrix ############ b\n");
      print(b, r, c);

      mult(a, b, res, r, c);

      printf("Matrix ############ res\n");
      print(res, r, c);

      freeMatrix(a, r);
      freeMatrix(b, r);
      freeMatrix(res, r);

    } else {
      double ** a   = allocateMatrix(r, c);
      double ** b   = allocateMatrix(r, c);
      double ** res = allocateMatrix(r, c);

      double result    = 0.0;

      printf("Input: $$$$$$$$ row = %d, col = %d\n", r, c);

      // init data
      {
        // Parallel execution using global thread pool with num_threads threads
        // Loop bound variable: r

        int total_iterations = r;
        int chunk_size = total_iterations / num_threads;
        if (chunk_size == 0) chunk_size = 1;

        // Allocate array of thread data structures
        ThreadData_main_line71_0* thread_data_array = malloc(num_threads * sizeof(ThreadData_main_line71_0));

        for (int t = 0; t < num_threads; t++) {
          ThreadData_main_line71_0* thread_data = &thread_data_array[t];
          thread_data->thread_id = t;
          thread_data->start = t * chunk_size;
          thread_data->end = (t == num_threads - 1) ? total_iterations : (t + 1) * chunk_size;
          thread_data->a = a;
          thread_data->b = b;
          thread_data->c = c;
          thread_data->r = r;
          thread_data->res = res;
          if (thread_data->start < total_iterations) {
            thpool_add_work(global_thpool, thread_function_main_line71_0, thread_data);
          }
        }

        thpool_wait(global_thpool);
        free(thread_data_array);
      }

      printf("Matrix $$$$$$$$ a\n");
      print(a, r, c);
      printf("Matrix $$$$$$$$ b\n");
      print(b, r, c);

      mult(a, b, res, r, c);

      printf("Matrix $$$$$$$$ res\n");
      print(res, r, c);

      freeMatrix(a, r);
      freeMatrix(b, r);
      freeMatrix(res, r);

    }

    cleanup_global_threadpool();

    return 0;
}
