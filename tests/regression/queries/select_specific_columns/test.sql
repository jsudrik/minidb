-- Test for selecting specific columns
create table test_columns (
    id int,
    name varchar(50),
    age int,
    salary int,
    department varchar(50)
);

-- Insert test data
insert into test_columns values (1, 'Alice', 30, 75000, 'Engineering');
insert into test_columns values (2, 'Bob', 35, 85000, 'Marketing');
insert into test_columns values (3, 'Charlie', 40, 95000, 'Finance');
insert into test_columns values (4, 'David', 45, 105000, 'HR');
insert into test_columns values (5, 'Eve', 50, 115000, 'Sales');

-- Test single column selection
select id from test_columns;

-- Test multiple column selection
select id, name from test_columns;

-- Test column selection with different order
select name, id, salary from test_columns;

-- Test all columns with specific order
select department, salary, age, name, id from test_columns;

-- Test column selection with WHERE clause
select id, name, salary from test_columns where age > 35;

shutdown;