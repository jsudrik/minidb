-- Test for SELECT with various operators
create table test_operators (
    id int,
    name varchar(50),
    age int,
    salary int,
    active int
);

-- Insert test data
insert into test_operators values (1, 'Alice', 30, 75000, 1);
insert into test_operators values (2, 'Bob', 35, 85000, 1);
insert into test_operators values (3, 'Charlie', 40, 95000, 0);
insert into test_operators values (4, 'David', 45, 105000, 1);
insert into test_operators values (5, 'Eve', 50, 115000, 0);

-- Test equality operator (=)
select * from test_operators where id = 3;
select * from test_operators where name = 'Bob';

-- Test greater than operator (>)
select * from test_operators where age > 40;
select * from test_operators where salary > 90000;

-- Test less than operator (<)
select * from test_operators where age < 40;
select * from test_operators where salary < 90000;

-- Test greater than or equal operator (>=)
select * from test_operators where age >= 40;
select * from test_operators where salary >= 95000;

-- Test less than or equal operator (<=)
select * from test_operators where age <= 40;
select * from test_operators where salary <= 95000;

-- Test with multiple conditions
select * from test_operators where age > 35 and salary < 100000;
select * from test_operators where age >= 45 or active = 0;

shutdown;