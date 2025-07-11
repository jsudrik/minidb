# MiniDB Top-Level Makefile
# Builds both server and client with debug/optimized modes

.PHONY: all clean debug optimized server client server-debug server-optimized server-threaded server-threaded-optimized client-debug client-optimized

# Default target - build both in debug mode
all: debug

# Build both server and client in debug mode
debug: server-debug client-debug

# Build both server and client in optimized mode
optimized: server-optimized client-optimized

# Server targets
server: server-debug
server-debug:
	$(MAKE) -C server debug

server-optimized:
	$(MAKE) -C server optimized

server-threaded:
	$(MAKE) -C server threaded

server-threaded-optimized:
	$(MAKE) -C server threaded-optimized

# Client targets
client: client-debug
client-debug:
	$(MAKE) -C client debug

client-optimized:
	$(MAKE) -C client optimized

# Clean all builds
clean:
	$(MAKE) -C server clean
	$(MAKE) -C client clean
	rm -f minidb_server minidb_client

# Install targets (copy to root directory)
install: debug
	cp server/minidb_server .
	cp client/minidb_client .

help:
	@echo "MiniDB Build System"
	@echo "=================="
	@echo "Targets:"
	@echo "  all          - Build both server and client (debug mode)"
	@echo "  debug        - Build both in debug mode"
	@echo "  optimized    - Build both in optimized mode"
	@echo "  server       - Build server only (debug)"
	@echo "  client       - Build client only (debug)"
	@echo "  server-debug - Build server in debug mode (multi-process)"
	@echo "  server-optimized - Build server in optimized mode (multi-process)"
	@echo "  server-threaded - Build server in debug mode (multi-threaded)"
	@echo "  server-threaded-optimized - Build server optimized (multi-threaded)"
	@echo "  client-debug - Build client in debug mode"
	@echo "  client-optimized - Build client in optimized mode"
	@echo "  clean        - Clean all builds"
	@echo "  install      - Build and copy binaries to root"