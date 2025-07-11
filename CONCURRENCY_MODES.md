# MiniDB Concurrency Modes

## Overview
MiniDB supports two concurrency models for handling client connections: Multi-Process and Multi-Threaded modes. Each mode has distinct characteristics and use cases.

## Multi-Process Mode (Default)

### Architecture
- **Process Model**: Fork separate process for each client connection
- **Memory Model**: Shared memory for server state coordination
- **Isolation**: Complete process isolation between clients
- **Communication**: Inter-process communication via shared memory

### Advantages
- **Fault Isolation**: Client crashes don't affect server or other clients
- **Security**: Process boundaries provide additional security isolation
- **Stability**: More robust against memory corruption and crashes
- **Debugging**: Easier to debug individual client sessions

### Disadvantages
- **Memory Usage**: Higher memory overhead per connection
- **Context Switching**: More expensive process context switches
- **Resource Limits**: Limited by system process limits

### Build Commands
```bash
make server-debug           # Multi-process debug build
make server-optimized       # Multi-process optimized build
```

## Multi-Threaded Mode

### Architecture
- **Thread Model**: Create separate thread for each client connection
- **Memory Model**: Shared memory space between all client threads
- **Isolation**: Thread-level isolation within same process
- **Communication**: Direct memory sharing with synchronization

### Advantages
- **Memory Efficiency**: Lower memory overhead per connection
- **Performance**: Faster thread context switching
- **Scalability**: Can handle more concurrent connections
- **Resource Usage**: More efficient use of system resources

### Disadvantages
- **Fault Propagation**: Thread crashes can affect entire server
- **Synchronization**: Requires careful thread synchronization
- **Complexity**: More complex debugging and error handling
- **Memory Safety**: Shared memory requires careful management

### Build Commands
```bash
make server-threaded                # Multi-threaded debug build
make server-threaded-optimized      # Multi-threaded optimized build
```

## Implementation Details

### Conditional Compilation
The server uses conditional compilation to enable different concurrency modes:

```c
#ifdef MULTITHREADED
static int use_multiprocess = 0; // Multi-threaded mode
#else
static int use_multiprocess = 1; // Multi-process mode (default)
#endif
```

### Shared Memory Usage
- **Multi-Process**: Uses shared memory for server state coordination
- **Multi-Threaded**: No shared memory needed (threads share process memory)

### Thread Safety
Both modes implement proper synchronization:
- **Locks**: Mutex locks for critical sections
- **Transaction Isolation**: Each client gets dedicated transaction context
- **Buffer Management**: Thread-safe buffer pool operations

## Performance Characteristics

### Multi-Process Mode
- **Connection Setup**: ~5-10ms per connection (fork overhead)
- **Memory per Connection**: ~2-4MB (process overhead)
- **Context Switch**: ~10-50μs (process context switch)
- **Maximum Connections**: Limited by system process limits (~1000-4000)

### Multi-Threaded Mode
- **Connection Setup**: ~1-2ms per connection (thread creation)
- **Memory per Connection**: ~8KB-2MB (thread stack)
- **Context Switch**: ~1-10μs (thread context switch)
- **Maximum Connections**: Limited by thread limits (~10000-50000)

## Use Case Guidelines

### Choose Multi-Process Mode When:
- **High Reliability Required**: Banking, financial systems
- **Untrusted Clients**: Public-facing applications
- **Memory is Abundant**: High-end servers with plenty of RAM
- **Connection Stability**: Long-running, stable connections
- **Debugging Needs**: Development and testing environments

### Choose Multi-Threaded Mode When:
- **High Concurrency Required**: Web applications, API servers
- **Memory Constrained**: Embedded systems, containers
- **Trusted Environment**: Internal applications, controlled clients
- **Performance Critical**: High-throughput, low-latency requirements
- **Resource Efficiency**: Cloud deployments with resource limits

## Configuration Examples

### Development Environment
```bash
# Multi-process for stability during development
make server-debug
./server/minidb_server 5432 dev.db
```

### Production Environment
```bash
# Multi-threaded for efficiency in production
make server-threaded-optimized
./server/minidb_server 5432 prod.db
```

### High-Availability Setup
```bash
# Multi-process for maximum fault tolerance
make server-optimized
./server/minidb_server 5432 ha.db
```

### Container Deployment
```bash
# Multi-threaded for resource efficiency
make server-threaded-optimized
./server/minidb_server 5432 container.db
```

## Monitoring and Diagnostics

### Multi-Process Mode
- Monitor process count: `ps aux | grep minidb_server | wc -l`
- Check shared memory: `ipcs -m`
- Memory usage: `pmap <server_pid>`

### Multi-Threaded Mode
- Monitor thread count: `ps -T -p <server_pid>`
- Thread stack usage: `cat /proc/<pid>/status | grep Threads`
- Memory usage: `cat /proc/<pid>/smaps`

## Future Enhancements

### Planned Features
- **Hybrid Mode**: Combination of processes and threads
- **Connection Pooling**: Reuse processes/threads for multiple connections
- **Dynamic Scaling**: Automatic adjustment based on load
- **NUMA Awareness**: Optimize for multi-socket systems