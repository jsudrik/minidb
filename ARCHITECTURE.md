# MiniDB Architecture Documentation

## System Overview
MiniDB is a relational database management system with enterprise-grade features including ACID transactions, crash recovery, and query optimization.

## Component Architecture

### 1. Query Optimizer (`server/optimizer/`)
**Purpose**: Analyzes SQL queries and selects optimal execution plans

**Key Features**:
- Cost-based optimization using page I/O estimates
- Index vs table scan selection
- Support for B-Tree and Hash index optimization
- Selectivity estimation for WHERE clauses

**Decision Logic**:
- Hash indexes: Preferred for equality predicates (`WHERE col = value`)
- B-Tree indexes: Preferred for range predicates (`WHERE col > value`)
- Table scans: Fallback when no suitable index exists

**Cost Model**:
- Primary factor: Page I/O operations
- Secondary factor: CPU costs (comparisons, sorting)
- Estimates: ~50 rows per page, logarithmic index access

### 2. Query Executor (`server/executor/`)
**Purpose**: Implements physical operations for data access and manipulation

**Scan Types**:
1. **Sequential Scan (Table Scan)**:
   - Reads all pages sequentially
   - Applies WHERE filters during scan
   - Cost: O(n) where n = number of pages

2. **Index Scan**:
   - Uses B-Tree or Hash index for efficient access
   - B-Tree: Supports range queries, sorted results
   - Hash: Supports equality queries, fastest for exact matches
   - Cost: O(log n + k) where k = result size

**Execution Pipeline**:
1. Receive optimized query plan
2. Initialize appropriate scan operator
3. Apply WHERE clause filters (predicate pushdown)
4. Project requested columns
5. Format results for client

### 3. Network Layer (`server/network/`)
**Purpose**: Handles client-server communication

**Protocol Design**:
- Simple text-based protocol over TCP
- Connection-oriented: one connection per client session
- Client sends SQL queries as plain text
- Server responds with formatted result sets

**Concurrency Model**:
- Multi-process architecture (fork per client)
- Shared memory for server state coordination
- Process isolation prevents client crashes from affecting server
- Each client gets dedicated transaction context

**Communication Flow**:
1. Client connects to server on specified port
2. Server sends welcome message
3. Client sends SQL queries (terminated by newline)
4. Server processes query and sends formatted results
5. Connection remains open for multiple queries

### 4. Transaction Manager (`server/transaction/`)
**Purpose**: Ensures ACID properties for database operations

**Transaction Properties**:
- **Atomicity**: All operations succeed or all fail
- **Consistency**: Database remains in valid state
- **Isolation**: Concurrent transactions don't interfere
- **Durability**: Committed changes survive system failures

**Isolation Levels**:
- **READ COMMITTED** (default):
  - Prevents dirty reads
  - Uses shared locks for reads, exclusive locks for writes
  - Locks released immediately after operation

**Locking Protocol**:
- Two-Phase Locking (2PL) for serializability
- Growing phase: Acquire locks as needed
- Shrinking phase: Release all locks at commit/abort
- Read locks: Multiple transactions can hold simultaneously
- Write locks: Exclusive access, blocks all other transactions

**Commit Protocol**:
1. Write all changes to WAL (Write-Ahead Logging)
2. Force WAL to disk (durability guarantee)
3. Mark transaction as committed
4. Release all locks
5. Apply changes to data pages (can be deferred)

### 5. Recovery Manager (`server/recovery/`)
**Purpose**: Ensures database consistency after system failures

**Recovery Algorithm (ARIES-based)**:
1. **ANALYSIS**: Scan WAL to identify committed/uncommitted transactions
2. **REDO**: Replay all operations to restore database to crash state
3. **UNDO**: Rollback all uncommitted transactions

**WAL Protocol**:
- All changes written to WAL before data pages (Write-Ahead)
- WAL records contain before/after images for undo/redo
- LSN (Log Sequence Number) provides total ordering
- Force WAL to disk before commit (durability)

**REDO Logic**:
- Replay all operations from WAL in forward order
- Idempotent: Safe to replay multiple times
- Restores database to state at time of crash
- Includes both committed and uncommitted changes

**UNDO Logic**:
- Rollback uncommitted transactions in reverse order
- Uses before-images to restore original values
- Ensures atomicity: all-or-nothing transaction semantics

**Checkpointing**:
- Periodic snapshots to limit recovery time
- Forces dirty pages to disk
- Records active transactions at checkpoint time
- Enables recovery to start from checkpoint

## Index System

### B-Tree Indexes
- **Use Case**: Range queries, sorted access
- **Structure**: Balanced tree with sorted keys
- **Operations**: Search O(log n), Insert O(log n), Delete O(log n)
- **Storage**: Internal nodes contain keys, leaf nodes contain data pointers

### Hash Indexes
- **Use Case**: Equality queries, exact matches
- **Structure**: Hash table with bucket chains
- **Operations**: Search O(1) average, Insert O(1), Delete O(1)
- **Storage**: Hash buckets contain key-value pairs

### Index Selection
- Optimizer chooses index type based on query predicates
- Multiple indexes per table supported
- Index-only scans for covering indexes (future enhancement)

## Storage Architecture

### Page Structure
- Fixed 4KB pages for consistent I/O
- Page header contains metadata (record count, next page, etc.)
- Data area contains variable-length records
- Free space management for efficient storage

### Buffer Management
- LRU-based page replacement
- Dirty page tracking for write optimization
- Pin/unpin mechanism for concurrent access
- Write-ahead logging integration

## Build System
- Hierarchical Makefiles (top-level, server, client)
- Debug and optimized build modes
- Platform-specific compilation flags
- Automatic dependency management