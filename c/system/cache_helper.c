#include <fcntl.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

// Configurtion and Operation Types
typedef enum { OP_CHECK, OP_ADD, OP_REMOVE, OP_INVALID } operation_t;

typedef struct {
  operation_t op;
  const char *filename;
  int verbose;
  int show_details;
} config_t;

// Use a global variable for page size for convenience.
static long page_size;

// Function Prototypes
static void print_usage(const char *program_name);
static operation_t parse_operation(const char *op_str);
static int check_page_cache(const config_t *config);
static int advise_cache(const config_t *config, int advice);

/**
 * @brief Prints the usage message for the program.
 */
void print_usage(const char *program_name) {
  printf("Usage: %s [OPTIONS] OPERATION FILE\n\n", program_name);
  printf("Page cache helper for benchmarking\n\n");
  printf("Operations:\n");
  printf("  check     Check if file pages are in cache\n");
  printf("  add       Add file to page cache\n");
  printf("  remove    Remove file from page cache\n\n");
  printf("Options:\n");
  printf("  -v, --verbose    Verbose output\n");
  printf("  -d, --details    Show detailed page-by-page cache status\n");
  printf("  -h, --help       Show this help message\n\n");
  printf("Examples:\n");
  printf("  %s check /path/to/file\n", program_name);
  printf("  %s -vd add /path/to/file\n", program_name);
}

/**
 * @brief Parses the operation string into an operation_t enum.
 */
operation_t parse_operation(const char *op_str) {
  if (strcmp(op_str, "check") == 0)
    return OP_CHECK;
  if (strcmp(op_str, "add") == 0)
    return OP_ADD;
  if (strcmp(op_str, "remove") == 0)
    return OP_REMOVE;
  return OP_INVALID;
}

/**
 * @brief Check which pages of a file are in the page cache using mincore().
 * @param config Pointer to the configuration struct.
 * @return 0 on success, -1 on failure.
 */
int check_page_cache(const config_t *config) {
  int fd = -1;
  struct stat st;
  void *addr = MAP_FAILED;
  unsigned char *vec = NULL;
  int ret = -1;

  if ((fd = open(config->filename, O_RDONLY)) == -1) {
    perror("open");
    goto cleanup;
  }

  if (fstat(fd, &st) == -1) {
    perror("fstat");
    goto cleanup;
  }

  if (st.st_size == 0) {
    if (config->verbose)
      printf("File is empty, nothing to check.\n");
    ret = 0;
    goto cleanup;
  }

  addr = mmap(NULL, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
  if (addr == MAP_FAILED) {
    perror("mmap");
    goto cleanup;
  }

  size_t page_count = (st.st_size + page_size - 1) / page_size;

  if (!(vec = malloc(page_count))) {
    perror("malloc for minicore vector");
    goto cleanup;
  }

  if (mincore(addr, st.st_size, vec) == -1) {
    perror("mincore");
    goto cleanup;
  }

  size_t cached_pages = 0;
  for (size_t i = 0; i < page_count; i++) {
    if (vec[i] & 1) { // Check the last bit
      cached_pages++;
      if (config->show_details)
        printf("Page %zu: IN CACHE\n", i);
    } else if (config->show_details) {
      printf("Page %zu: NOT IN CACHE\n", i);
    }
  }

  double cache_ratio =
      (page_count > 0) ? (double)cached_pages / page_count * 100.0 : 0.0;
  printf("File:     %s\n", config->filename);
  printf("Size:     %ld bytes (%zu pages)\n", st.st_size, page_count);
  printf("Cached:   %zu/%zu pages (%.1f%%)\n", cached_pages, page_count,
         cache_ratio);

  if (config->verbose) {
    const char *status = (cached_pages == page_count) ? "Fully cached"
                         : (cached_pages == 0)        ? "Not cached"
                                                      : "Partially cached";
    printf("Status:   %s\n", status);
  }

  ret = 0;

cleanup:
  if (vec)
    free(vec);
  if (addr != MAP_FAILED)
    munmap(addr, st.st_size);
  if (fd != -1)
    close(fd);
  return ret;
}

/**
 * @brief Advises the kernel on cache management using posix_fadvise().
 * @param config Pointer to the configuration struct.
 * @param advice The advice to give (e.g., POSIX_FADV_WILLNEED).
 * @return 0 on success, -1 on falure.
 */
int advise_cache(const config_t *config, int advice) {
  int fd = -1;
  struct stat st;
  int ret = -1;

  if ((fd = open(config->filename, O_RDONLY)) == -1) {
    perror("open");
    goto cleanup;
  }

  if (fstat(fd, &st) == -1) {
    perror("fstat");
    goto cleanup;
  }

  if (st.st_size == 0) {
    if (config->verbose)
      printf("File is empty, no operation performed.\n");
    ret = 0;
    goto cleanup;
  }

  if (posix_fadvise(fd, 0, st.st_size, advice) != 0) {
    perror("posix_fadvise");
    goto cleanup;
  }

  const char *action_str =
      (advice == POSIX_FADV_WILLNEED) ? "Added" : "Removed";
  const char *preposition_str = (advice == POSIX_FADV_WILLNEED) ? "to" : "from";

  if (config->verbose) {
    printf("%s %s %s page cache (%ld bytes)\n", action_str, config->filename,
           preposition_str, st.st_size);
  } else {
    printf("%s %s cache: %s\n", action_str, preposition_str, config->filename);
  }

  ret = 0;

cleanup:
  if (fd != -1)
    close(fd);
  return ret;
}

/**
 * @brief Main entry point. Parses args and executes the requested operation.
 */
int main(int argc, char *argv[]) {
  config_t config = {
      .op = OP_INVALID, .filename = NULL, .verbose = 0, .show_details = 0};
  int opt;

  // Dynamically get the system's page size for portability.
  page_size = sysconf(_SC_PAGESIZE);
  if (page_size == -1) {
    perror("sysconf(_SC_PAGESIZE)");
    page_size = 4096; // Fallback to common default.
  }

  static struct option long_options[] = {{"verbose", no_argument, 0, 'v'},
                                         {"details", no_argument, 0, 'd'},
                                         {"help", no_argument, 0, 'h'},
                                         {0, 0, 0, 0}};

  while ((opt = getopt_long(argc, argv, "vdh", long_options, NULL)) != -1) {
    switch (opt) {
    case 'v':
      config.verbose = 1;
      break;
    case 'd':
      config.show_details = 1;
      break;
    case 'h':
      print_usage(argv[0]);
      return 0;
    default: /* '?' */
      print_usage(argv[0]);
      return 1;
    }
  }

  if (optind + 2 != argc) {
    fprintf(stderr, "Error: Missing operation or filename.\n\n");
    print_usage(argv[0]);
    return 1;
  }

  config.op = parse_operation(argv[optind]);
  config.filename = argv[optind + 1];

  if (config.op == OP_INVALID) {
    fprintf(stderr, "Error: Invalid operation '%s'.\n\n", argv[optind]);
    print_usage(argv[0]);
    return 1;
  }

  switch (config.op) {
  case OP_CHECK:
    return check_page_cache(&config);
  case OP_ADD:
    return advise_cache(&config, POSIX_FADV_WILLNEED);
  case OP_REMOVE:
    return advise_cache(&config, POSIX_FADV_DONTNEED);
  default:
    fprintf(stderr, "Error: Unknown operation.\n");
    return 1;
  }
}
