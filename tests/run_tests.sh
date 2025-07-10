#!/bin/bash

# MiniDB Test Runner
echo "Starting MiniDB Test Suite..."

# Start server in background
echo "Starting MiniDB server on port 5433..."
cd ..
./minidb_server 5433 test.db &
SERVER_PID=$!

# Wait for server to start
sleep 3

echo "Running basic tests..."

# Function to run SQL command
run_sql() {
    echo "$1" | timeout 10 ./minidb_client 127.0.0.1 5433
    echo "----------------------------------------"
}

# Test 1: Create table
echo "Test 1: Creating employees table..."
run_sql "CREATE TABLE employees (id INT, name VARCHAR(100), department VARCHAR(50), salary FLOAT, employee_id BIGINT)"

# Test 2: Show tables
echo "Test 2: Show tables..."
run_sql "SHOW TABLES"

# Test 3: Describe table
echo "Test 3: Describe employees table..."
run_sql "DESCRIBE employees"

# Test 4: Insert data
echo "Test 4: Inserting test data..."
run_sql "INSERT INTO employees VALUES ('1', 'John Doe', 'Engineering', '75000.50', '1001')"
run_sql "INSERT INTO employees VALUES ('2', 'Jane Smith', 'Marketing', '65000.00', '1002')"
run_sql "INSERT INTO employees VALUES ('3', 'Bob Johnson', 'Engineering', '80000.25', '1003')"

# Test 5: Select data
echo "Test 5: Selecting all employees..."
run_sql "SELECT * FROM employees"

# Test 6: Create index
echo "Test 6: Creating B-tree index..."
run_sql "CREATE INDEX idx_emp_salary ON employees (salary) USING BTREE"

# Test 7: Create hash index
echo "Test 7: Creating hash index..."
run_sql "CREATE INDEX idx_emp_id ON employees (id) USING HASH"

# Test 8: Update data
echo "Test 8: Updating employee salary..."
run_sql "UPDATE employees SET salary = '85000.00'"

# Test 9: Select after update
echo "Test 9: Selecting after update..."
run_sql "SELECT * FROM employees"

# Test 10: Delete data
echo "Test 10: Deleting records..."
run_sql "DELETE FROM employees"

# Test 11: Select after delete
echo "Test 11: Selecting after delete..."
run_sql "SELECT * FROM employees"

# Test 12: Create another table
echo "Test 12: Creating departments table..."
run_sql "CREATE TABLE departments (dept_id INT, dept_name VARCHAR(50), manager_id INT)"

# Test 13: Insert into departments
echo "Test 13: Inserting into departments..."
run_sql "INSERT INTO departments VALUES ('1', 'Engineering', '1')"
run_sql "INSERT INTO departments VALUES ('2', 'Marketing', '2')"

# Test 14: Select from departments
echo "Test 14: Selecting from departments..."
run_sql "SELECT * FROM departments"

# Test 15: Drop index
echo "Test 15: Dropping index..."
run_sql "DROP INDEX idx_emp_salary"

# Test 16: Drop table
echo "Test 16: Dropping departments table..."
run_sql "DROP TABLE departments"

# Test 17: Show tables after drop
echo "Test 17: Show tables after drop..."
run_sql "SHOW TABLES"

# Test 18: Transaction commit
echo "Test 18: Transaction commit test..."
run_sql "INSERT INTO employees VALUES ('4', 'Alice Brown', 'Sales', '70000.00', '1004')"
run_sql "COMMIT"

# Test 19: Final select
echo "Test 19: Final select..."
run_sql "SELECT * FROM employees"

# Cleanup
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Cleaning up test database..."
rm -f test.db

echo "Test suite completed!"