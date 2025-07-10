# MiniDB Usage Examples

This document provides comprehensive examples of using MiniDB for various database operations, from basic setup to advanced transaction scenarios.

## Quick Start

### 1. Starting the Server

```bash
# Start with default settings
./minidb_server

# Start with custom port and database file
./minidb_server 8080 company.db

# Server output:
# Starting MiniDB Server with WAL and Crash Recovery...
# Database file: company.db
# Port: 8080
# MiniDB Server ready with WAL and transaction support!
# MiniDB Server listening on port 8080
```

### 2. Connecting with Client

```bash
# Connect to local server
./minidb_client

# Connect to remote server
./minidb_client 192.168.1.100 8080

# Client output:
# MiniDB Client - Connecting to 192.168.1.100:8080...
# Connected successfully!
# Connected to MiniDB Server (Read Committed Isolation)
# Type 'help' for commands, 'quit' to exit
# minidb[1]>
```

## Basic Database Operations

### Creating Tables

```sql
-- Employee management system
CREATE TABLE employees (
    id INT,
    name VARCHAR(100),
    department VARCHAR(50),
    salary FLOAT,
    employee_id BIGINT
);

-- Product catalog
CREATE TABLE products (
    product_id INT,
    name VARCHAR(200),
    category VARCHAR(50),
    price FLOAT,
    stock_quantity INT
);

-- Customer information
CREATE TABLE customers (
    customer_id INT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20)
);
```

### Viewing Schema Information

```sql
-- List all tables
SHOW TABLES;
-- Output:
-- Table_ID  Table_Name
-- --------  ----------
-- 10        employees
-- 11        products
-- 12        customers
-- (3 rows)

-- Describe table structure
DESCRIBE employees;
-- Output:
-- Column      Type      Size  Nullable
-- ----------  --------  ----  --------
-- id          INT       4     YES
-- name        VARCHAR   100   YES
-- department  VARCHAR   50    YES
-- salary      FLOAT     4     YES
-- employee_id BIGINT    8     YES
-- (5 rows)
```

## Data Manipulation Examples

### Inserting Data

```sql
-- Insert employee records
INSERT INTO employees VALUES ('1', 'Alice Johnson', 'Engineering', '75000.0', '1001');
INSERT INTO employees VALUES ('2', 'Bob Smith', 'Marketing', '65000.0', '1002');
INSERT INTO employees VALUES ('3', 'Carol Davis', 'Engineering', '80000.0', '1003');
INSERT INTO employees VALUES ('4', 'David Wilson', 'Sales', '70000.0', '1004');
INSERT INTO employees VALUES ('5', 'Eve Brown', 'HR', '60000.0', '1005');

-- Insert product data
INSERT INTO products VALUES ('101', 'Laptop Computer', 'Electronics', '999.99', '50');
INSERT INTO products VALUES ('102', 'Office Chair', 'Furniture', '299.99', '25');
INSERT INTO products VALUES ('103', 'Desk Lamp', 'Furniture', '49.99', '100');
INSERT INTO products VALUES ('104', 'Wireless Mouse', 'Electronics', '29.99', '200');

-- Insert customer data
INSERT INTO customers VALUES ('1001', 'John', 'Doe', 'john.doe@email.com', '555-0101');
INSERT INTO customers VALUES ('1002', 'Jane', 'Smith', 'jane.smith@email.com', '555-0102');
INSERT INTO customers VALUES ('1003', 'Mike', 'Johnson', 'mike.j@email.com', '555-0103');
```

### Querying Data

```sql
-- Select all employees
SELECT * FROM employees;
-- Output:
-- id  name           department   salary    employee_id
-- --  -------------  -----------  --------  -----------
-- 1   Alice Johnson  Engineering  75000.00  1001
-- 2   Bob Smith      Marketing    65000.00  1002
-- 3   Carol Davis    Engineering  80000.00  1003
-- 4   David Wilson   Sales        70000.00  1004
-- 5   Eve Brown      HR           60000.00  1005
-- (5 rows)

-- Select all products
SELECT * FROM products;
-- Output:
-- product_id  name            category     price    stock_quantity
-- ----------  --------------  -----------  -------  --------------
-- 101         Laptop Computer Electronics  999.99   50
-- 102         Office Chair    Furniture    299.99   25
-- 103         Desk Lamp       Furniture    49.99    100
-- 104         Wireless Mouse  Electronics  29.99    200
-- (4 rows)
```

### Updating Records

```sql
-- Give Alice a raise
UPDATE employees SET salary = '85000.0' WHERE id = '1';
-- Output: 1 record(s) updated

-- Update product stock
UPDATE products SET stock_quantity = '45' WHERE product_id = '101';
-- Output: 1 record(s) updated

-- Bulk salary update for Engineering department
UPDATE employees SET salary = '82000.0' WHERE department = 'Engineering';
-- Output: 2 record(s) updated
```

### Deleting Records

```sql
-- Remove a specific employee
DELETE FROM employees WHERE id = '5';
-- Output: 1 record(s) deleted

-- Remove out-of-stock products
DELETE FROM products WHERE stock_quantity = '0';
-- Output: 0 record(s) deleted

-- Verify deletion
SELECT * FROM employees;
-- Output shows 4 employees (Eve Brown removed)
```

## Index Management

### Creating Indexes

```sql
-- Create B-tree index for range queries on salary
CREATE INDEX idx_emp_salary ON employees (salary) USING BTREE;
-- Output: Index created successfully

-- Create hash index for fast equality lookups on employee ID
CREATE INDEX idx_emp_id ON employees (id) USING HASH;
-- Output: Index created successfully

-- Create index on product category
CREATE INDEX idx_product_category ON products (category) USING BTREE;
-- Output: Index created successfully

-- Create index on customer email
CREATE INDEX idx_customer_email ON customers (email) USING HASH;
-- Output: Index created successfully
```

### Using Indexes (Automatic Optimization)

```sql
-- Query that will use hash index on employee ID
SELECT * FROM employees WHERE id = '3';
-- Optimizer: Index scan chosen, cost=1, rows=1

-- Query that will use B-tree index on salary
SELECT * FROM employees WHERE salary > '70000.0';
-- Optimizer: Index scan chosen, cost=2, rows=3

-- Query without index (full table scan)
SELECT * FROM employees WHERE name = 'Alice Johnson';
-- Optimizer: Sequential scan chosen, cost=5, rows=4
```

### Dropping Indexes

```sql
-- Remove salary index
DROP INDEX idx_emp_salary;
-- Output: Index dropped successfully

-- Remove product category index
DROP INDEX idx_product_category;
-- Output: Index dropped successfully
```

## Transaction Examples

### Basic Transaction Control

```sql
-- Start a transaction
BEGIN;

-- Perform multiple operations
INSERT INTO employees VALUES ('6', 'Frank Miller', 'IT', '72000.0', '1006');
UPDATE employees SET department = 'Information Technology' WHERE department = 'IT';
INSERT INTO products VALUES ('105', 'Keyboard', 'Electronics', '79.99', '150');

-- Commit the transaction
COMMIT;
-- Output: Transaction committed

-- Verify changes
SELECT * FROM employees WHERE employee_id = '1006';
-- Shows Frank Miller with department 'Information Technology'
```

### Transaction Rollback

```sql
-- Start another transaction
BEGIN;

-- Make some changes
INSERT INTO customers VALUES ('1004', 'Sarah', 'Connor', 'sarah.c@email.com', '555-0104');
UPDATE products SET price = '999999.99' WHERE product_id = '101';
DELETE FROM employees WHERE department = 'Marketing';

-- Decide to rollback
ROLLBACK;
-- Output: Transaction rolled back

-- Verify rollback - changes should be undone
SELECT * FROM customers WHERE customer_id = '1004';
-- Output: No results found (Sarah Connor not inserted)

SELECT * FROM products WHERE product_id = '101';
-- Shows original price, not 999999.99

SELECT * FROM employees WHERE department = 'Marketing';
-- Bob Smith still exists
```

### Complex Transaction Scenario

```sql
-- Business scenario: Process a customer order
BEGIN;

-- Add new customer
INSERT INTO customers VALUES ('1005', 'Tom', 'Anderson', 'tom.a@email.com', '555-0105');

-- Check product availability (simulated)
SELECT * FROM products WHERE product_id = '104';
-- Wireless Mouse, stock: 200

-- Update inventory
UPDATE products SET stock_quantity = '195' WHERE product_id = '104';

-- Record would go to orders table (if it existed)
-- INSERT INTO orders VALUES ('2001', '1005', '104', '5', '149.95');

-- Commit the order
COMMIT;
-- Output: Transaction committed

-- Verify final state
SELECT * FROM customers WHERE customer_id = '1005';
SELECT * FROM products WHERE product_id = '104';
-- Shows Tom Anderson added and mouse stock reduced to 195
```

## Advanced Scenarios

### Concurrent Access Simulation

**Terminal 1:**
```sql
-- Client 1: Start long-running transaction
BEGIN;
UPDATE employees SET salary = '90000.0' WHERE id = '1';
-- Don't commit yet - simulate long processing
```

**Terminal 2:**
```sql
-- Client 2: Try to access same data
SELECT * FROM employees WHERE id = '1';
-- Will see original salary due to read-committed isolation
-- Shows: Alice Johnson with salary 85000.0 (committed value)

-- Try to update same record
UPDATE employees SET department = 'Senior Engineering' WHERE id = '1';
-- May wait for lock or proceed based on isolation level
```

**Terminal 1 (continued):**
```sql
-- Client 1: Complete transaction
COMMIT;
-- Now Client 2 will see updated salary
```

### Crash Recovery Demonstration

```bash
# Terminal 1: Start server and create data
./minidb_server 5432 crash_test.db

# Terminal 2: Connect and create test data
./minidb_client 127.0.0.1 5432
```

```sql
-- Create test table and data
CREATE TABLE crash_test (id INT, data VARCHAR(50));
INSERT INTO crash_test VALUES ('1', 'Before crash');
INSERT INTO crash_test VALUES ('2', 'Also before crash');
COMMIT;

-- Start uncommitted transaction
BEGIN;
INSERT INTO crash_test VALUES ('3', 'Uncommitted data');
-- Don't commit - simulate crash
```

```bash
# Terminal 1: Simulate crash (kill server)
kill -9 <server_pid>

# Restart server - automatic recovery
./minidb_server 5432 crash_test.db
```

**Recovery Output:**
```
Starting crash recovery...
Starting REDO recovery...
REDO: Applied INSERT for TXN 1, page 110
REDO: Applied INSERT for TXN 1, page 110
REDO recovery completed: 2 operations applied
Starting UNDO recovery...
UNDO: Removed INSERT for TXN 2, page 110
UNDO recovery completed: 1 operations undone
Crash recovery completed: 2 REDO, 1 UNDO operations
```

```sql
-- Verify recovery
SELECT * FROM crash_test;
-- Output:
-- id  data
-- --  ----------------
-- 1   Before crash
-- 2   Also before crash
-- (2 rows)
-- Note: Uncommitted data (id=3) was rolled back
```

## Schema Management Examples

### Complete Database Setup

```sql
-- Create comprehensive employee database
CREATE TABLE departments (
    dept_id INT,
    dept_name VARCHAR(50),
    manager_id INT,
    budget FLOAT
);

CREATE TABLE employees (
    emp_id INT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    dept_id INT,
    salary FLOAT,
    hire_date VARCHAR(20)
);

CREATE TABLE projects (
    project_id INT,
    project_name VARCHAR(100),
    dept_id INT,
    budget FLOAT,
    status VARCHAR(20)
);

-- Create indexes for performance
CREATE INDEX idx_emp_dept ON employees (dept_id) USING BTREE;
CREATE INDEX idx_emp_salary ON employees (salary) USING BTREE;
CREATE INDEX idx_proj_dept ON projects (dept_id) USING BTREE;
CREATE INDEX idx_dept_manager ON departments (manager_id) USING HASH;

-- Insert department data
INSERT INTO departments VALUES ('1', 'Engineering', '101', '500000.0');
INSERT INTO departments VALUES ('2', 'Marketing', '102', '300000.0');
INSERT INTO departments VALUES ('3', 'Sales', '103', '400000.0');
INSERT INTO departments VALUES ('4', 'HR', '104', '200000.0');

-- Insert employee data
INSERT INTO employees VALUES ('101', 'Alice', 'Johnson', '1', '95000.0', '2020-01-15');
INSERT INTO employees VALUES ('102', 'Bob', 'Smith', '2', '75000.0', '2019-03-20');
INSERT INTO employees VALUES ('103', 'Carol', 'Davis', '3', '80000.0', '2021-06-10');
INSERT INTO employees VALUES ('104', 'David', 'Wilson', '4', '70000.0', '2018-11-05');
INSERT INTO employees VALUES ('105', 'Eve', 'Brown', '1', '85000.0', '2022-02-28');

-- Insert project data
INSERT INTO projects VALUES ('1001', 'Database System', '1', '150000.0', 'Active');
INSERT INTO projects VALUES ('1002', 'Marketing Campaign', '2', '75000.0', 'Planning');
INSERT INTO projects VALUES ('1003', 'Sales Automation', '3', '100000.0', 'Active');
INSERT INTO projects VALUES ('1004', 'HR Portal', '4', '50000.0', 'Completed');
```

### Database Cleanup

```sql
-- Remove test data
DELETE FROM projects WHERE status = 'Completed';
DELETE FROM employees WHERE hire_date < '2019-01-01';

-- Drop indexes
DROP INDEX idx_emp_dept;
DROP INDEX idx_emp_salary;
DROP INDEX idx_proj_dept;
DROP INDEX idx_dept_manager;

-- Drop tables (in dependency order)
DROP TABLE projects;
DROP TABLE employees;
DROP TABLE departments;

-- Verify cleanup
SHOW TABLES;
-- Should show only system tables
```

## Performance Testing Examples

### Bulk Data Operations

```sql
-- Create test table for performance testing
CREATE TABLE performance_test (
    id INT,
    data VARCHAR(100),
    value FLOAT,
    category VARCHAR(20)
);

-- Create index for testing
CREATE INDEX idx_perf_id ON performance_test (id) USING HASH;
CREATE INDEX idx_perf_category ON performance_test (category) USING BTREE;
```

```bash
# Bulk insert script (would be run from application)
for i in {1..1000}; do
    echo "INSERT INTO performance_test VALUES ('$i', 'Test Data $i', '$((RANDOM % 1000)).99', 'Category$((i % 10))');"
done | ./minidb_client
```

```sql
-- Test query performance
SELECT * FROM performance_test WHERE id = '500';
-- Should use hash index for fast lookup

SELECT * FROM performance_test WHERE category = 'Category5';
-- Should use B-tree index for category scan

-- Cleanup
DROP TABLE performance_test;
```

## Error Handling Examples

### Constraint Violations

```sql
-- Attempt to create duplicate table
CREATE TABLE employees (id INT, name VARCHAR(50));
-- Output: Failed to create table (table already exists)

-- Invalid data type
CREATE TABLE invalid_table (id INVALID_TYPE);
-- Output: Parse error: Unknown data type

-- Invalid SQL syntax
SELCT * FROM employees;
-- Output: Parse error: Invalid SQL syntax
```

### Resource Limitations

```sql
-- Attempt to insert very long string
INSERT INTO employees VALUES ('999', 'Very long name that exceeds the VARCHAR limit of 100 characters and should cause an error', 'Test', '50000.0', '9999');
-- Output: String too long for column

-- Query non-existent table
SELECT * FROM non_existent_table;
-- Output: Table not found
```

## Client Commands

### Interactive Client Features

```sql
-- Get help
help
-- Output: Shows all available SQL commands

-- Transaction status commands
BEGIN;
-- Start transaction

COMMIT;
-- Commit current transaction

ROLLBACK;
-- Rollback current transaction

-- Exit client
quit
-- or
exit
-- Output: Disconnecting from server...
```

### Batch Processing

```bash
# Run SQL from file
cat > batch_commands.sql << EOF
CREATE TABLE batch_test (id INT, name VARCHAR(50));
INSERT INTO batch_test VALUES ('1', 'Batch Insert 1');
INSERT INTO batch_test VALUES ('2', 'Batch Insert 2');
SELECT * FROM batch_test;
DROP TABLE batch_test;
EOF

# Execute batch
./minidb_client < batch_commands.sql
```

This comprehensive set of examples demonstrates the full capabilities of MiniDB, from basic CRUD operations to advanced transaction management and crash recovery scenarios.