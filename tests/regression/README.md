# MiniDB Regression Test Framework

This directory contains regression tests for MiniDB. The tests are organized by module and verify that MiniDB functionality works correctly and continues to work as expected after code changes.

## Directory Structure

```
regression/
├── run_tests.sh         # Main test runner script
├── README.md            # This file
├── dml/                 # Data Manipulation Language tests (INSERT, UPDATE, DELETE)
├── ddl/                 # Data Definition Language tests (CREATE, DROP, ALTER)
├── queries/             # Query tests (SELECT with various clauses)
├── datatypes/           # Tests for different data types
├── wal/                 # Write-Ahead Logging tests
└── recovery/            # Recovery tests
```

## Test Structure

Each test consists of:

1. A directory named after the test
2. A `test.sql` file containing SQL commands to run
3. An `expected.out` file containing the expected output
4. A `run.out` file will be generated when the test is run
5. Optional additional files specific to the test

Example:
```
queries/
└── select_where/
    ├── test.sql         # SQL commands for the test
    └── expected.out     # Expected output
```

## Running Tests

To run all tests (with automatic cleanup):
```
./run_tests.sh
```

To run all tests in a specific module:
```
./run_tests.sh dml
```

To run a specific test:
```
./run_tests.sh queries select_where
```

### Cleanup Options

To clean up all generated files without running tests:
```
./run_tests.sh --clean
```

To run tests without cleaning up first:
```
./run_tests.sh --no-clean dml
```

To explicitly clean up and then run tests (this is the default):
```
./run_tests.sh --clean-run queries select_where
```

## Adding New Tests

To add a new test:

1. Create a new directory under the appropriate module
2. Create a `test.sql` file with the SQL commands for the test
3. Run the test once to generate output
4. Review the output and if correct, copy it to `expected.out`

Example:
```bash
# Create test directory and files
mkdir -p queries/new_test
echo "create table test (id int, name varchar(20));
insert into test values (1, 'Alice');
select * from test;
shutdown;" > queries/new_test/test.sql

# Run the test to generate output
./run_tests.sh queries new_test

# If the output looks correct, save it as the expected output
cp queries/new_test/run.out queries/new_test/expected.out
```

## Test Modules

### DML Tests
Tests for INSERT, UPDATE, and DELETE operations.

### DDL Tests
Tests for CREATE TABLE, DROP TABLE, and other schema operations.

### Query Tests
Tests for SELECT queries with various clauses (WHERE, ORDER BY, etc.).

### Data Type Tests
Tests for different data types (INT, VARCHAR, etc.).

### WAL Tests
Tests for Write-Ahead Logging functionality.

### Recovery Tests
Tests for database recovery after crashes.