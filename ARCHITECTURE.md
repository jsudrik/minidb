# MiniDB Architecture Documentation

## System Overview

MiniDB is a complete relational database management system implemented in C, featuring a layered architecture that provides full ACID transaction support with Write-Ahead Logging (WAL) and crash recovery capabilities.

## Component Architecture

### Layer Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Applications                       │
└─────────────────────────────────────────────────────────────┘
                              │ TCP/IP
┌─────────────────────────────────────────────────────────────┐
│                     Network Layer                           │
│  • Session Management  • Protocol Handling  • Threading    │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      SQL Parser                             │
│  • Lexical Analysis   • Syntax Parsing   • AST Generation  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Query Optimizer                           │
│  • Cost Estimation   • Index Selection   • Plan Generation │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Query Executor                            │
│  • Plan Execution    • Result Generation  • Error Handling │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────┬─────────────────┬─────────────────────────┐
│ Transaction Mgr │  Buffer Manager │      WAL Manager        │
│ • ACID Support  │ • LRU Caching   │ • Write-Ahead Logging   │
│ • Concurrency   │ • Page Pinning  │ • Crash Recovery        │
│ • Isolation     │ • Dirty Tracking│ • Durability            │
└─────────────────┴─────────────────┴─────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   Storage Manager                           │
│  • Page Layout    • Record Management   • Index Structures │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Disk Manager                             │
│  • File I/O       • Page Allocation     • Synchronization  │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Network Layer (`server/network/`)

**Purpose**: Handles client connections and communication protocol

**Key Files**:
- `server.c` - TCP server implementation with threading

**Responsibilities**:
- Accept client connections
- Manage client sessions
- Handle SQL command protocol
- Format and send query results
- Thread management for concurrent clients

**Threading Model**:
- One thread per client connection
- Thread-safe resource access
- Automatic cleanup on disconnection

### 2. SQL Parser (`server/parser/`)

**Purpose**: Converts SQL text into executable query plans

**Key Files**:
- `lexer.l` - Lexical analyzer (Flex)
- `parser.y` - Grammar parser (Bison)

**Supported SQL**:
```sql
-- DDL Commands
CREATE TABLE name (col1 TYPE, col2 TYPE, ...)
DROP TABLE name
CREATE INDEX name ON table (column) USING {BTREE|HASH}
DROP INDEX name
DESCRIBE table
SHOW TABLES

-- DML Commands  
INSERT INTO table VALUES (val1, val2, ...)
SELECT {*|columns} FROM table [WHERE condition]
UPDATE table SET column = value [WHERE condition]
DELETE FROM table [WHERE condition]

-- Transaction Control
BEGIN
COMMIT
ROLLBACK
```

**Features**:
- Case-insensitive keywords
- Comprehensive error handling
- AST generation for optimization

### 3. Query Optimizer (`server/optimizer/`)

**Purpose**: Generates efficient execution plans

**Key Files**:
- `optimizer.c` - Cost-based optimization

**Optimization Strategies**:
- **Index Selection**: Choose between sequential scan and index scan
- **Cost Estimation**: Estimate I/O and CPU costs
- **Plan Generation**: Create optimal execution plans

**Cost Model**:
```c
// Sequential scan cost
int seq_cost = table_size / pages_per_io;

// Index scan cost  
int index_cost = index_height + selectivity * table_size;
```

### 4. Query Executor (`server/executor/`)

**Purpose**: Executes optimized query plans

**Key Files**:
- `executor.c` - Query execution engine

**Execution Operations**:
- **Table Scan**: Sequential and index-based scanning
- **Record Operations**: Insert, update, delete with transaction logging
- **Result Formatting**: Prepare results for client display
- **Transaction Integration**: Coordinate with transaction manager

### 5. Transaction Manager (`server/transaction/`)

**Purpose**: Provides ACID transaction support

**Key Files**:
- `transaction_manager.c` - Transaction control and concurrency

**ACID Implementation**:

**Atomicity**:
- All-or-nothing transaction execution
- Automatic rollback on failure
- WAL-based recovery

**Consistency**:
- Constraint enforcement
- Referential integrity
- System catalog maintenance

**Isolation**:
- Read Committed isolation level
- Read-write locks for concurrency control
- Deadlock prevention

**Durability**:
- Write-Ahead Logging (WAL)
- Force-log-at-commit protocol
- Crash recovery mechanisms

### 6. Buffer Manager (`server/buffer/`)

**Purpose**: Manages in-memory page cache

**Key Files**:
- `buffer_manager.c` - LRU buffer pool management

**Features**:
- **LRU Replacement**: Least Recently Used page eviction
- **Pin/Unpin Protocol**: Prevent replacement of active pages
- **Dirty Page Tracking**: Track modified pages for write-back
- **Thread Safety**: Concurrent access protection

**Buffer Pool Structure**:
```c
typedef struct {
    int page_id;           // Unique page identifier
    char data[PAGE_SIZE];  // 4KB page data
    bool dirty;            // Modified flag
    bool in_use;           // Active flag
    int pin_count;         // Reference count
    pthread_mutex_t mutex; // Concurrency control
} Page;
```

### 7. WAL Manager (`server/wal/`)

**Purpose**: Write-Ahead Logging for durability and recovery

**Key Files**:
- `wal_manager.c` - Transaction logging implementation

**WAL Record Types**:
```c
typedef enum {
    WAL_BEGIN,     // Transaction start
    WAL_COMMIT,    // Transaction commit
    WAL_ABORT,     // Transaction abort
    WAL_INSERT,    // Record insertion
    WAL_UPDATE,    // Record modification
    WAL_DELETE,    // Record deletion
    WAL_CHECKPOINT // Consistency point
} WALRecordType;
```

**WAL Protocol**:
1. **Write-Ahead Rule**: Log before data modification
2. **Force-Log-at-Commit**: Flush log before commit acknowledgment
3. **Checksum Verification**: Ensure log record integrity

### 8. Recovery Manager (`server/recovery/`)

**Purpose**: Crash recovery using WAL

**Key Files**:
- `recovery_manager.c` - REDO/UNDO recovery implementation

**Recovery Algorithm**:
```
1. REDO Phase:
   - Scan WAL from beginning
   - Replay all operations (committed and uncommitted)
   - Restore database to crash point

2. UNDO Phase:
   - Identify uncommitted transactions
   - Reverse operations in reverse chronological order
   - Restore consistent state
```

### 9. Storage Manager (`server/storage/`)

**Purpose**: Physical data storage and retrieval

**Key Files**:
- `storage.c` - Record and page management

**Storage Structures**:

**Data Page Layout**:
```c
typedef struct {
    int record_count;      // Number of records
    int next_page;         // Next page in chain
    int deleted_count;     // Deleted record count
    char records[...];     // Variable-length records
} DataPage;
```

**B-Tree Index Page**:
```c
typedef struct {
    int key_count;         // Number of keys
    int is_leaf;           // Leaf node flag
    int parent;            // Parent page ID
    struct {
        Value key;         // Search key
        int page_id;       // Child page ID
    } entries[100];
    int children[101];     // Child pointers
} BTreePage;
```

**Hash Index Page**:
```c
typedef struct {
    int bucket_count;      // Number of buckets
    struct {
        Value key;         // Hash key
        int record_id;     // Record identifier
        int next_bucket;   // Collision chain
        bool deleted;      // Deletion flag
    } buckets[200];
} HashPage;
```

### 10. Disk Manager (`server/disk/`)

**Purpose**: Low-level file I/O operations

**Key Files**:
- `disk_manager.c` - File system interface

**Responsibilities**:
- **Page I/O**: Read/write 4KB pages
- **File Management**: Database file operations
- **Space Allocation**: Page allocation and deallocation
- **Synchronization**: Thread-safe file access

### 11. System Catalog (`server/catalog/`)

**Purpose**: Metadata management

**Key Files**:
- `catalog.c` - System catalog implementation

**Catalog Tables**:
- `sys_tables` - Table metadata
- `sys_columns` - Column definitions
- `sys_indexes` - Index metadata
- `sys_types` - Data type information

## Data Flow

### Query Processing Flow

```
1. Client sends SQL query
   ↓
2. Network layer receives query
   ↓
3. Parser converts SQL to AST
   ↓
4. Optimizer generates execution plan
   ↓
5. Executor processes plan:
   - Acquires transaction locks
   - Logs operations to WAL
   - Accesses data through buffer manager
   - Modifies pages in storage manager
   ↓
6. Results formatted and sent to client
   ↓
7. Transaction committed/aborted
```

### Transaction Lifecycle

```
1. BEGIN transaction
   - Allocate transaction ID
   - Log BEGIN record to WAL
   ↓
2. Execute operations
   - Acquire appropriate locks
   - Log each operation to WAL
   - Modify data pages
   ↓
3. COMMIT/ROLLBACK
   - Log COMMIT/ABORT to WAL
   - Release locks
   - Flush WAL to disk (for COMMIT)
```

### Recovery Process

```
1. Server startup after crash
   ↓
2. REDO Phase:
   - Read WAL from beginning
   - Replay all logged operations
   - Restore database to crash point
   ↓
3. UNDO Phase:
   - Identify uncommitted transactions
   - Reverse operations in reverse order
   - Achieve consistent state
   ↓
4. Normal operation resumes
```

## Concurrency Control

### Locking Protocol

**Read-Write Locks**:
- **Shared Locks**: Multiple readers allowed
- **Exclusive Locks**: Single writer, no readers
- **Lock Granularity**: Page-level locking

**Deadlock Prevention**:
- **Timeout-based**: Abort transactions after timeout
- **Resource Ordering**: Consistent lock acquisition order

### Transaction Isolation

**Read Committed Level**:
- Transactions see committed data only
- No dirty reads
- Phantom reads possible
- Non-repeatable reads possible

## Performance Characteristics

### Memory Usage
- **Buffer Pool**: 400KB (100 × 4KB pages)
- **WAL Buffer**: 4KB write buffer
- **Per-Connection**: ~8KB per client thread

### I/O Patterns
- **Sequential Scans**: Efficient page-by-page reading
- **Index Lookups**: Logarithmic B-tree traversal
- **WAL Writes**: Sequential append-only writes

### Scalability Limits
- **Concurrent Connections**: ~100 clients
- **Database Size**: Limited by disk space
- **Transaction Rate**: ~1000 TPS for simple operations

## Configuration Parameters

### Compile-Time Constants
```c
#define PAGE_SIZE 4096          // Page size in bytes
#define MAX_COLUMNS 32          // Maximum columns per table
#define MAX_NAME_LEN 64         // Maximum identifier length
#define MAX_RESULT_ROWS 1000    // Maximum result set size
#define BUFFER_POOL_SIZE 100    // Buffer pool pages
```

### Runtime Parameters
- **Port Number**: TCP listening port
- **Database File**: Path to database file
- **WAL File**: Automatically created as {database}.wal

## Error Handling

### Error Categories
1. **Network Errors**: Connection failures, timeouts
2. **Parse Errors**: Invalid SQL syntax
3. **Execution Errors**: Constraint violations, resource limits
4. **System Errors**: I/O failures, memory allocation
5. **Recovery Errors**: WAL corruption, inconsistent state

### Error Recovery
- **Graceful Degradation**: Continue operation when possible
- **Transaction Rollback**: Automatic cleanup on failure
- **Connection Cleanup**: Resource deallocation on disconnect
- **Crash Recovery**: Automatic database repair on restart

## Testing Strategy

### Unit Tests
- Individual component testing
- Mock dependencies
- Edge case coverage

### Integration Tests
- Multi-component interaction
- End-to-end query processing
- Concurrency testing

### System Tests
- Full server-client interaction
- Crash recovery scenarios
- Performance benchmarking

This architecture provides a solid foundation for understanding database system internals while maintaining production-quality features like ACID transactions, crash recovery, and concurrent access control.