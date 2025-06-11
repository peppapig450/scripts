# Compiler and flags
CC       = clang
CFLAGS   = -Wall -Wextra -pedantic -O2 -std=gnu11 

# Program name and source
TARGET   = cache_helper
SOURCE   = cache_helper.c

# Installation prefix
PREFIX   ?= $(HOME)/.local

.PHONY: all debug install uninstall clean test-setup test help

all: $(TARGET)

# Build target
$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $@ $<

# Debug build adds symbols and debug define
debug: CFLAGS += -g -DDEBUG
debug: clean $(TARGET)

# Install into $(PREFIX)/bin
install: $(TARGET)
	install -m 755 $(TARGET) $(PREFIX)/bin/

# Remove from $(PREFIX)/bin
uninstall:
	rm -f $(PREFIX)/bin/$(TARGET)

# Clean up build artifacts
clean:
	rm -f $(TARGET)

# Create a 10 MB file for testing
test-setup:
	dd if=/dev/zero of=testfile bs=1M count=10 2>/dev/null

# Run basic functionality tests
test: $(TARGET) test-setup
	@echo "=== 1. Checking cache status of testfile ==="
	./$(TARGET) check testfile
	@echo "\n=== 2. Adding testfile to cache ==="
	./$(TARGET) add testfile
	@echo "\n=== 3. Checking cache status after add ==="
	./$(TARGET) check testfile
	@echo "\n=== 4. Removing testfile from cache ==="
	./$(TARGET) remove testfile
	@echo "\n=== 5. Checking cache status after remove ==="
	./$(TARGET) check testfile
	@echo "\n=== 6. Verbose output check ==="
	./$(TARGET) -v check testfile
	@rm -f testfile
	@echo "\nAll tests completed!"

# List available targets
help:
	@echo "Available targets:"
	@echo "  all        Build the program (default)"
	@echo "  debug      Build with debug symbols"
	@echo "  install    Install to $(PREFIX)/bin/"
	@echo "  uninstall  Remove from $(PREFIX)/bin/"
	@echo "  clean      Remove built files"
	@echo "  test       Run basic functionality tests"
	@echo "  help       Show this help message"

