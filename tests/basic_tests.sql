-- Basic MiniDB Test Suite
-- Test all major SQL operations

-- Test 1: Create table with various data types
CREATE TABLE employees ( id INT, name VARCHAR(100), department VARCHAR(50), salary FLOAT, employee_id BIGINT);

-- Test 2: Show tables
-- SHOW TABLES;

-- Test 3: Describe table structure
DESCRIBE employees;

-- Test 4: Insert test data
INSERT INTO employees VALUES ('1', 'John Doe', 'Engineering', '75000.50', '1001');
INSERT INTO employees VALUES ('2', 'Jane Smith', 'Marketing', '65000.00', '1002');
INSERT INTO employees VALUES ('3', 'Bob Johnson', 'Engineering', '80000.25', '1003');
INSERT INTO employees VALUES ('4', 'Alice Brown', 'Sales', '70000.00', '1004');

-- Test 5: Select all records
SELECT * FROM employees;

-- Test 6: Create B-tree index
CREATE INDEX idx_emp_salary ON employees (salary) USING BTREE;

-- Test 7: Create hash index
CREATE INDEX idx_emp_id ON employees (id) USING HASH;

-- Test 8: Update records
UPDATE employees SET salary = '85000.00' WHERE id = '1';

-- Test 9: Select after update
SELECT * FROM employees;

-- Test 10: Delete records
DELETE FROM employees WHERE department = 'Sales';

-- Test 11: Select after delete
SELECT * FROM employees;

-- Test 12: Create another table for more tests
CREATE TABLE departments ( dept_id INT, dept_name VARCHAR(50), manager_id INT);

-- Test 13: Insert into departments
INSERT INTO departments VALUES ('1', 'Engineering', '1');
INSERT INTO departments VALUES ('2', 'Marketing', '2');
INSERT INTO departments VALUES ('3', 'Sales', '4');

-- Test 14: Select from departments
SELECT * FROM departments;

-- Test 15: Drop index
DROP INDEX idx_emp_salary;

-- Test 16: Drop table
DROP TABLE departments;

-- Test 17: Show tables after drop
-- SHOW TABLES;

-- Test 18: Transaction test - commit
BEGIN;
INSERT INTO employees VALUES ('5', 'Charlie Wilson', 'HR', '60000.00', '1005');
COMMIT;

-- Test 19: Transaction test - rollback
BEGIN;
INSERT INTO employees VALUES ('6', 'David Lee', 'Finance', '72000.00', '1006');
ROLLBACK;

-- Test 20: Final select to verify transaction behavior
SELECT * FROM employees;
