# MiniDB Client Makefile
# Supports debug and optimized builds

TARGET = minidb_client
CC = gcc

# Source files
SOURCES = client.c

# Common compiler flags
COMMON_FLAGS = -Wall -Wextra -std=c99
INCLUDES = -I../common

# Platform-specific flags
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    PLATFORM_FLAGS = -arch arm64 -DMACOS_ARM64 -DMACOS
else
    PLATFORM_FLAGS = -DLINUX
endif

# Debug build flags
DEBUG_FLAGS = $(COMMON_FLAGS) $(PLATFORM_FLAGS) $(INCLUDES) -g -DDEBUG -O0

# Optimized build flags
OPTIMIZED_FLAGS = $(COMMON_FLAGS) $(PLATFORM_FLAGS) $(INCLUDES) -O3 -DNDEBUG

# Default target
debug: $(TARGET)

# Debug build
$(TARGET): $(SOURCES)
	@echo "Building MiniDB Client (Debug Mode)..."
	$(CC) $(DEBUG_FLAGS) -o $(TARGET) $(SOURCES) $(PLATFORM_FLAGS)
	@echo "Debug build complete: $(TARGET)"

# Optimized build
optimized: $(TARGET)_opt

$(TARGET)_opt: $(SOURCES)
	@echo "Building MiniDB Client (Optimized Mode)..."
	$(CC) $(OPTIMIZED_FLAGS) -o $(TARGET) $(SOURCES) $(PLATFORM_FLAGS)
	@echo "Optimized build complete: $(TARGET)"

# Clean
clean:
	rm -f $(TARGET) $(TARGET)_opt *.o

.PHONY: debug optimized clean