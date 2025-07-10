# MiniDB - Complete RDBMS with Transaction Logging and Crash Recovery

MiniDB is a minimal relational database management system (RDBMS) implemented in C, designed for educational purposes and as a foundation for understanding database internals. It provides complete ACID transaction support with Write-Ahead Logging (WAL) and crash recovery capabilities. 

Having said that, it is not production ready and should be seen as experimental and not fully functional. The code is still unstable and has issues. Its is not thoroughly tested on all aspects. It has minimalist approach of RDBMS server and doesn't claim to be scalable.

Following is just the list of features which are attempted. There are many more missing in it's current state. 

## Features

### Core Database Engine
- **Multithreaded TCP/IP Server**: Concurrent client connections with session management
- **SQL Parser**: Case-insensitive Lex/Bison-based parser supporting comprehensive SQL syntax
- **Query Optimizer**: Cost-based optimization with index selection and query planning
- **Query Executor**: Full SQL execution engine with transaction isolation
- **Buffer Manager**: LRU page replacement with 4K pages and proper concurrency control
- **Storage Engine**: Complete page-based storage with B-tree and Hash indexes
- **Disk I/O Manager**: Thread-safe page-based disk operations

### Transaction System
- **ACID Compliance**: Full Atomicity, Consistency, Isolation, and Durability support
- **Write-Ahead Logging (WAL)**: Transaction logging for durability and recovery
- **Crash Recovery**: Automatic REDO/UNDO recovery on server restart
- **Read Committed Isolation**: Proper transaction isolation with concurrent access
- **Deadlock Prevention**: Resource locking with timeout mechanisms

### SQL Support
- **Data Definition Language (DDL)**:
  - `CREATE TABLE` with multiple data types
  - `DROP TABLE` with cascade operations
  - `CREATE INDEX` (B-tree and Hash)
  - `DROP INDEX`
  - `DESCRIBE` table structure
  - `SHOW TABLES`

- **Data Manipulation Language (DML)**:
  - `INSERT INTO` with value lists
  - `SELECT` with projection and filtering
  - `UPDATE` with conditional modifications
  - `DELETE` with conditional removal

- **Transaction Control**:
  - `BEGIN` transaction
  - `COMMIT` transaction
  - `ROLLBACK` transaction

### Data Types
- **Numeric Types**: `INT`, `BIGINT`, `FLOAT`
- **String Types**: `CHAR(n)`, `VARCHAR(n)`
- **NULL Support**: Nullable columns with proper handling

### Index Types
- **B-tree Indexes**: Efficient range queries and sorting
- **Hash Indexes**: Fast equality lookups
- **Automatic Optimization**: Query optimizer selects appropriate index

## Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   SQL Client    │────│  Network Layer  │
└─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │   SQL Parser    │
                       └─────────────────┘
                              │
                       ┌─────────────────┐
                       │ Query Optimizer │
                       └─────────────────┘
                              │
                       ┌─────────────────┐
                       │ Query Executor  │
                       └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│Transaction Mgr  │  │  Buffer Manager │  │  WAL Manager    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                    ┌─────────────────┐
                    │ Storage Manager │
                    └─────────────────┘
                              │
                    ┌─────────────────┐
                    │  Disk Manager   │
                    └─────────────────┘
```

## Installation

### Prerequisites
- GCC compiler with C99 support
- POSIX-compliant system (Linux, macOS, Unix)
- pthread library
- Make build system
- Optional: Flex and Bison for parser development

#### macOS Specific:
- Xcode Command Line Tools: `xcode-select --install`
- Native ARM64 support for Apple Silicon (M1/M2/M3)
- Automatic platform detection in build system

### Building from Source

```bash
# Clone or extract the MiniDB source code
cd minidb

# Check dependencies and configure build environment
./configure

# Build server and client (automatic platform detection)
make all

# Build with debug symbols
make debug

# Build optimized release version
make release

# Test platform compatibility
make platformtest

# Install system-wide (optional)
sudo make install
```

#### Platform-Specific Builds

**macOS (Apple Silicon):**
```bash
# Automatic ARM64 detection and optimization
make all
# Builds with: -arch arm64 -DMACOS_ARM64 -DMACOS
```

**macOS (Intel):**
```bash
# Automatic x86_64 detection
make all
# Builds with: -arch x86_64 -DMACOS_X86_64 -DMACOS
```

**Linux:**
```bash
# Standard POSIX build
make all
```

### Build Targets
- `make all` - Build server and client (default)
- `make test` - Run comprehensive test suite
- `make crashtest` - Run crash recovery tests
- `make quicktest` - Run quick functionality test
- `make sample` - Create sample database with test data
- `make clean` - Remove build files
- `make help` - Show all available targets

## Usage

### Starting the Server

```bash
# Start with default settings (port 5432, database file minidb.dat)
./minidb_server

# Specify custom port and database file
./minidb_server 8080 mydb.dat

# Server will create WAL file automatically (mydb.dat.wal)
```

**Server Output:**
```
Starting MiniDB Server with WAL and Crash Recovery...
Database file: mydb.dat
Port: 8080
Disk manager initialized, file: mydb.dat, next_page_id: 10
WAL manager initialized, file: mydb.dat.wal, current LSN: 0
Buffer manager initialized with 100 pages (4K each)
Checking for crash recovery...
System catalog initialized with 4 system tables
MiniDB Server ready with WAL and transaction support!
MiniDB Server listening on port 8080
```

### Connecting with Client

```bash
# Connect to local server on default port
./minidb_client

# Connect to specific host and port
./minidb_client 192.168.1.100 8080
```

**Client Interface:**
```
MiniDB Client - Connecting to 127.0.0.1:5432...
Connected successfully!

Connected to MiniDB Server (Read Committed Isolation)
Type 'help' for commands, 'quit' to exit

minidb[1]> 
```

## SQL Examples

### Database Schema Creation

```sql
-- Create a table with various data types
CREATE TABLE employees (
    id INT,
    name VARCHAR(100),
    department VARCHAR(50),
    salary FLOAT,
    employee_id BIGINT
);

-- Create indexes for performance
CREATE INDEX idx_emp_dept ON employees (department) USING BTREE;
CREATE INDEX idx_emp_id ON employees (id) USING HASH;

-- View table structure
DESCRIBE employees;

-- List all tables
SHOW TABLES;
```

### Data Operations

```sql
-- Insert data
INSERT INTO employees VALUES ('1', 'Alice Johnson', 'Engineering', '75000.0', '1001');
INSERT INTO employees VALUES ('2', 'Bob Smith', 'Marketing', '65000.0', '1002');
INSERT INTO employees VALUES ('3', 'Carol Davis', 'Engineering', '80000.0', '1003');

-- Query data
SELECT * FROM employees;

-- Update records
UPDATE employees SET salary = '85000.0' WHERE id = '1';

-- Delete records
DELETE FROM employees WHERE department = 'Marketing';
```

### Transaction Management

```sql
-- Start a transaction
BEGIN;

-- Perform operations
INSERT INTO employees VALUES ('4', 'David Wilson', 'Sales', '70000.0', '1004');
UPDATE employees SET department = 'Sales Engineering' WHERE id = '3';

-- Commit changes
COMMIT;

-- Or rollback if needed
-- ROLLBACK;
```

### Schema Modifications

```sql
-- Drop an index
DROP INDEX idx_emp_dept;

-- Drop a table
DROP TABLE employees;
```

## Configuration

### Server Configuration
The server accepts command-line parameters:

```bash
./minidb_server [port] [database_file]
```

- **port**: TCP port number (default: 5432)
- **database_file**: Path to database file (default: minidb.dat)

### Client Configuration
The client accepts connection parameters:

```bash
./minidb_client [host] [port]
```

- **host**: Server hostname or IP (default: 127.0.0.1)
- **port**: Server port number (default: 5432)

## Testing

### Comprehensive Test Suite

```bash
# Run all tests
make test

# Run crash recovery tests
make crashtest

# Run quick functionality test
make quicktest
```

### Manual Testing

```bash
# Create sample database
make sample

# Start server with sample data
./minidb_server 5432 sample.db

# Connect and explore
./minidb_client
```

### Test Scenarios Covered
- **Basic CRUD Operations**: Create, Read, Update, Delete
- **Transaction Isolation**: Concurrent access testing
- **Crash Recovery**: Server crash and restart scenarios
- **Index Operations**: B-tree and Hash index functionality
- **Schema Operations**: DDL command testing
- **Data Integrity**: Constraint and validation testing

## Crash Recovery

MiniDB provides automatic crash recovery through Write-Ahead Logging:

### Recovery Process
1. **Server Startup**: Automatically detects previous crash
2. **REDO Phase**: Replays all committed transactions from WAL
3. **UNDO Phase**: Rolls back uncommitted transactions
4. **Normal Operation**: Continues with consistent database state

### Recovery Example
```bash
# Server crashes during operation
kill -9 <server_pid>

# Restart server - automatic recovery
./minidb_server 5432 mydb.dat
```

**Recovery Output:**
```
Starting crash recovery...
Starting REDO recovery...
REDO: Applied INSERT for TXN 15, page 105
REDO: Applied UPDATE for TXN 16, page 106
REDO recovery completed: 2 operations applied
Starting UNDO recovery...
UNDO: Removed INSERT for TXN 17, page 107
UNDO recovery completed: 1 operations undone
Crash recovery completed: 2 REDO, 1 UNDO operations
```

## Performance Characteristics

### Throughput
- **Concurrent Connections**: Supports multiple simultaneous clients
- **Transaction Rate**: ~1000 transactions/second (simple operations)
- **Query Performance**: Optimized with index selection

### Storage
- **Page Size**: 4KB pages for efficient I/O
- **Buffer Pool**: 100 pages (400KB) default buffer cache
- **Index Efficiency**: B-tree for range queries, Hash for equality

### Scalability
- **Database Size**: Limited by available disk space
- **Table Size**: ~1M records per table (depending on record size)
- **Concurrent Users**: ~100 simultaneous connections

## Troubleshooting

### Common Issues

**Server Won't Start:**
```bash
# Check if port is already in use
netstat -an | grep :5432

# Use different port
./minidb_server 5433 mydb.dat
```

**Connection Refused:**
```bash
# Verify server is running
ps aux | grep minidb_server

# Check firewall settings
# Ensure client connects to correct host/port
```

**Database Corruption:**
```bash
# Remove corrupted files and restart
rm mydb.dat mydb.dat.wal
./minidb_server 5432 mydb.dat
```

### Debug Mode
Build with debug symbols for troubleshooting:

```bash
make debug
gdb ./minidb_server
```

## Limitations

### Current Limitations
- **Single Database**: One database per server instance
- **No User Authentication**: Open access (suitable for development)
- **Limited SQL**: Subset of full SQL standard
- **No Joins**: Single table queries only
- **Fixed Buffer Size**: 100 pages (configurable in source)

### Future Enhancements
- Multi-database support
- User authentication and authorization
- JOIN operations
- Advanced SQL features (GROUP BY, ORDER BY, etc.)
- Replication and clustering
- Web-based administration interface

## Contributing

MiniDB is designed for educational purposes. To contribute:

1. **Fork the Repository**: Create your own copy
2. **Make Changes**: Implement features or fixes
3. **Test Thoroughly**: Run all test suites
4. **Document Changes**: Update README and comments
5. **Submit Pull Request**: Share your improvements

### Development Guidelines
- Follow C99 standard
- Use consistent coding style
- Add comprehensive tests
- Document all public functions
- Maintain ACID properties

## License

MiniDB is released under the MIT License. See LICENSE file for details.

## Support

For questions, issues, or contributions:

- **Documentation**: This README and inline code comments
- **Testing**: Comprehensive test suite included
- **Examples**: Sample databases and queries provided
- **Architecture**: Well-documented modular design

---

**MiniDB** - A complete educational RDBMS with transaction logging and crash recovery capabilities.
