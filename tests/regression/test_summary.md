# MiniDB Regression Test Framework

## Overview

The MiniDB Regression Test Framework provides a structured way to test MiniDB functionality and ensure that changes don't break existing features. The framework is organized by module and includes tests for various aspects of the database system.

## Directory Structure

```
regression/
├── run_tests.sh         # Main test runner script
├── README.md            # Main documentation
├── dml/                 # Data Manipulation Language tests
├── ddl/                 # Data Definition Language tests
├── queries/             # Query tests
├── datatypes/           # Data type tests
├── wal/                 # Write-Ahead Logging tests
└── recovery/            # Recovery tests
```

## Test Modules

### DML Tests
- **insert_basic**: Tests basic INSERT functionality
- **update_where**: Tests UPDATE with WHERE clause
- **delete_where**: Tests DELETE with WHERE clause

### DDL Tests
- **create_table**: Tests CREATE TABLE functionality
- **show_tables**: Tests SHOW TABLES functionality

### Query Tests
- **select_star**: Tests SELECT * queries
- **select_columns**: Tests SELECT column_list queries
- **select_where**: Tests SELECT with WHERE clause

### Data Type Tests
- **int_type**: Tests INT data type
- **varchar_type**: Tests VARCHAR data type

### WAL Tests
- **basic_logging**: Tests basic Write-Ahead Logging

### Recovery Tests
- **crash_recovery**: Tests database recovery after crashes

## Running Tests

To run all tests (with automatic cleanup):
```
bash run_tests.sh
```

To run all tests in a specific module:
```
bash run_tests.sh dml
```

To run a specific test:
```
bash run_tests.sh queries select_where
```

### Cleanup Options

The test framework now includes options to manage test file cleanup:

- **--clean**: Clean up all generated files without running tests
  ```
  bash run_tests.sh --clean
  ```

- **--clean-run**: Clean up and then run tests (this is the default)
  ```
  bash run_tests.sh --clean-run dml
  ```

- **--no-clean**: Run tests without cleaning up first
  ```
  bash run_tests.sh --no-clean queries select_where
  ```

## Test Results

Each test compares the actual output with the expected output and reports success or failure. The test runner provides a summary of passed and failed tests for each module.

## Adding New Tests

To add a new test:

1. Create a new directory under the appropriate module
2. Create a `test.sql` file with the SQL commands for the test
3. Run the test once to generate output (saved as `run.out`)
4. Review the output and if correct, copy it to `expected.out`

See the README.md in each module directory for module-specific guidance.