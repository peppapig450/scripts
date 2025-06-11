# cache_helper

`cache_helper` is a lightweight command-line utility for inspecting and managing the Linux page cache for individual files. It leverages `mincore(2)` to report which pages of a file are resident in memory and `posix_fadvise(3)` to add or remove a file from the cache, making it useful for benchmarking and cache‐related experiments.

---

## Features

* **check**: Report what percentage of a file’s pages are in the page cache.
* **add**: Advise the kernel to preload a file into the page cache.
* **remove**: Advise the kernel to drop a file from the page cache.
* **Verbose** (`-v`/`--verbose`): Print extra status and summary.
* **Details** (`-d`/`--details`): Print per-page cache status.
* **Test suite**: Built-in Makefile targets to generate test data and verify behavior.

---

## Prerequisites

* Linux system supporting `mincore(2)` and `posix_fadvise(3)`.
* C compiler (e.g., `clang` or `gcc`) and GNU Make.
* (Optional) [`hyperfine`](https://github.com/sharkdp/hyperfine) for benchmarking.

---

## Building

By default, the Makefile will compile `cache_helper` with optimization:

```bash
make
```

For a debug build with symbols and `-DDEBUG`:

```bash
make debug
```

Clean up artifacts:

```bash
make clean
```

---

## Installation

By default, `install` places the binary in `$(HOME)/.local/bin`. You can override the prefix by setting `PREFIX`:

```bash
make install        # installs to ~/.local/bin/
make PREFIX=/usr install  # installs to /usr/bin/
```

To uninstall:

```bash
make uninstall
```

---

## Usage

```text
Usage: cache_helper [OPTIONS] OPERATION FILE

Operations:
  check     Check if file pages are in cache
  add       Add file to page cache
  remove    Remove file from page cache

Options:
  -v, --verbose    Verbose output
  -d, --details    Show detailed per-page status
  -h, --help       Show this help message
```

### Examples

```bash
# Check cache status of /path/to/file
cache_helper check /path/to/file

# Add a file to cache with verbose + details
cache_helper -vd add /path/to/file

# Remove a file from cache
cache_helper remove /path/to/file

# Clean build and run a full test suite
make clean test
```

---

## Benchmarking with hyperfine

Caching behavior can skew performance measurements. With [`hyperfine`](https://github.com/sharkdp/hyperfine), use `--prepare` to clear or preload cache before each timing run.

### Clear a specific file from cache

Instead of dropping the entire page cache, you can use `cache_helper remove` in `--prepare` to evict just your target file:

```bash
--prepare './cache_helper remove testfile'
```

### Preload a specific file into cache

Similarly, preload a file:

```bash
--prepare './cache_helper add testfile'
```

### Combined example: `check` under warm cache

```bash
hyperfine \
  --prepare './cache_helper remove testfile' \
  --prepare './cache_helper add testfile' \
  'cache_helper check testfile'
```

This sequence:

1. Evicts only `testfile` from cache.
2. Reloads `testfile` into cache.
3. Measures `check` performance in a consistent warm-cache state.

---

## Makefile Targets

| Target       | Description                                  |
| ------------ | -------------------------------------------- |
| `all`        | Build the optimized binary (`cache_helper`). |
| `debug`      | Build with debug symbols and `-DDEBUG`.      |
| `install`    | Install binary to `$(PREFIX)/bin`.           |
| `uninstall`  | Remove binary from `$(PREFIX)/bin`.          |
| `clean`      | Remove build artifacts.                      |
| `test-setup` | Create a 10 MB test file (`testfile`).       |
| `test`       | Run basic cache-check/add/remove tests.      |
| `help`       | Show available Makefile targets.             |

---

## Testing

The `test` target automates a simple workflow:

1. Generate a 10 MB zero-filled file (`testfile`).
2. Check initial cache status.
3. Add it to cache.
4. Re-check status.
5. Remove from cache.
6. Final status check.
7. Cleanup.

```bash
make test
```

---
