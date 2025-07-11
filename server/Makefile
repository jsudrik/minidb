# MiniDB Server Makefile
# Supports debug and optimized builds

TARGET = minidb_server
CC = gcc

# Source files
SOURCES = main.c \
          network/server.c \
          buffer/buffer_manager.c \
          disk/disk_manager.c \
          storage/storage.c \
          executor/executor.c \
          optimizer/optimizer.c \
          catalog/catalog.c \
          transaction/transaction_manager.c \
          wal/wal_manager.c \
          recovery/recovery_manager.c \
          recovery/page_diagnostics.c

# Common compiler flags
COMMON_FLAGS = -Wall -Wextra -std=c99 -pthread
INCLUDES = -I../common

# Platform-specific flags
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    PLATFORM_FLAGS = -arch arm64 -DMACOS_ARM64 -DMACOS
else
    PLATFORM_FLAGS = -DLINUX
endif

# Debug build flags (multi-process default)
DEBUG_FLAGS = $(COMMON_FLAGS) $(PLATFORM_FLAGS) $(INCLUDES) -g -DDEBUG -O0 -DVERBOSE_LOGGING

# Optimized build flags (multi-process default)
OPTIMIZED_FLAGS = $(COMMON_FLAGS) $(PLATFORM_FLAGS) $(INCLUDES) -O3 -DNDEBUG -DOPTIMIZED

# Threaded build flags
THREADED_FLAGS = $(COMMON_FLAGS) $(PLATFORM_FLAGS) $(INCLUDES) -g -DDEBUG -O0 -DVERBOSE_LOGGING -DMULTITHREADED
THREADED_OPT_FLAGS = $(COMMON_FLAGS) $(PLATFORM_FLAGS) $(INCLUDES) -O3 -DNDEBUG -DOPTIMIZED -DMULTITHREADED

# Default target
debug: $(TARGET)

# Debug build
$(TARGET): $(SOURCES)
	@echo "Building MiniDB Server (Debug Mode)..."
	$(CC) $(DEBUG_FLAGS) -o $(TARGET) $(SOURCES) -pthread $(PLATFORM_FLAGS)
	@echo "Debug build complete: $(TARGET)"

# Optimized build
optimized: $(TARGET)_opt

$(TARGET)_opt: $(SOURCES)
	@echo "Building MiniDB Server (Optimized Mode)..."
	$(CC) $(OPTIMIZED_FLAGS) -o $(TARGET) $(SOURCES) -pthread $(PLATFORM_FLAGS)
	@echo "Optimized build complete: $(TARGET)"

# Threaded builds
threaded: $(TARGET)_threaded

$(TARGET)_threaded: $(SOURCES)
	@echo "Building MiniDB Server (Multi-threaded Debug Mode)..."
	$(CC) $(THREADED_FLAGS) -o $(TARGET) $(SOURCES) -pthread $(PLATFORM_FLAGS)
	@echo "Threaded debug build complete: $(TARGET)"

threaded-optimized: $(TARGET)_threaded_opt

$(TARGET)_threaded_opt: $(SOURCES)
	@echo "Building MiniDB Server (Multi-threaded Optimized Mode)..."
	$(CC) $(THREADED_OPT_FLAGS) -o $(TARGET) $(SOURCES) -pthread $(PLATFORM_FLAGS)
	@echo "Threaded optimized build complete: $(TARGET)"

# Clean
clean:
	rm -f $(TARGET) $(TARGET)_opt $(TARGET)_threaded $(TARGET)_threaded_opt *.o

# Development targets
dev: debug
	@echo "Development build ready"

release: optimized
	@echo "Release build ready"

.PHONY: debug optimized threaded threaded-optimized clean dev release