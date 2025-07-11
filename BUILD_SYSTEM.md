# MiniDB Build System Documentation

## Overview
MiniDB uses a hierarchical Makefile structure supporting both debug and optimized builds for server and client components.

## Build Structure
```
minidb/
├── Makefile              # Top-level build coordination
├── server/
│   └── Makefile         # Server-specific build rules
└── client/
    └── Makefile         # Client-specific build rules
```

## Build Targets

### Top-Level Targets
- `make all` or `make` - Build both server and client (debug mode)
- `make debug` - Build both components in debug mode
- `make optimized` - Build both components in optimized mode
- `make clean` - Clean all build artifacts
- `make install` - Build and copy binaries to root directory

### Server Build Targets
- `make server` - Build server only (debug, multi-process)
- `make server-debug` - Build server in debug mode (multi-process)
- `make server-optimized` - Build server in optimized mode (multi-process)
- `make server-threaded` - Build server in debug mode (multi-threaded)
- `make server-threaded-optimized` - Build server optimized (multi-threaded)

### Client Build Targets
- `make client` - Build client only (debug)
- `make client-debug` - Build client in debug mode
- `make client-optimized` - Build client in optimized mode

## Build Modes

### Debug Mode
- Compiler flags: `-g -DDEBUG -O0 -DVERBOSE_LOGGING`
- Features:
  - Full debug symbols
  - No optimization
  - Verbose logging enabled
  - Debug assertions active
  - Suitable for development and debugging

### Optimized Mode
- Compiler flags: `-O3 -DNDEBUG -DOPTIMIZED`
- Features:
  - Maximum optimization
  - Debug symbols stripped
  - Assertions disabled
  - Suitable for production deployment

## Server Concurrency Modes

### Multi-Process Mode (Default)
- Each client connection handled by separate process
- Process isolation prevents client crashes from affecting server
- Uses shared memory for server state coordination
- Higher memory usage but better fault isolation
- Compiler flag: None (default behavior)

### Multi-Threaded Mode
- Each client connection handled by separate thread
- Lower memory usage, faster context switching
- Shared memory space between all client threads
- Requires careful synchronization
- Compiler flag: `-DMULTITHREADED`

## Platform Support
- **macOS**: ARM64 architecture with macOS-specific flags
- **Linux**: Generic Linux support (future)
- Automatic platform detection via `uname -s`

## Usage Examples
```bash
# Development build (multi-process)
make debug

# Production build (multi-process)
make optimized

# Multi-threaded development build
make server-threaded

# Multi-threaded production build
make server-threaded-optimized

# Build only server (optimized, multi-process)
make server-optimized

# Clean and rebuild
make clean && make optimized

# Install binaries
make install
```

## Choosing Concurrency Mode

### Use Multi-Process Mode When:
- Maximum fault isolation is required
- Client connections may be unstable
- Memory usage is not a primary concern
- Running on systems with abundant memory

### Use Multi-Threaded Mode When:
- Memory efficiency is important
- High connection throughput is required
- Client connections are stable and trusted
- Running on memory-constrained systems