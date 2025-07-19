-- Test for DELETE with various operators
create table test_delete (
    id int,
    name varchar(50),
    age int,
    salary int,
    active int
);

-- Insert test data
insert into test_delete values (1, 'Alice', 30, 75000, 1);
insert into test_delete values (2, 'Bob', 35, 85000, 1);
insert into test_delete values (3, 'Charlie', 40, 95000, 0);
insert into test_delete values (4, 'David', 45, 105000, 1);
insert into test_delete values (5, 'Eve', 50, 115000, 0);
insert into test_delete values (6, 'Frank', 55, 125000, 1);
insert into test_delete values (7, 'Grace', 60, 135000, 0);

-- Show initial data
select * from test_delete;

-- Test DELETE with equality operator (=)
delete from test_delete where id = 1;
select * from test_delete;

-- Test DELETE with greater than operator (>)
delete from test_delete where age > 55;
select * from test_delete;

-- Test DELETE with less than operator (<)
delete from test_delete where salary < 90000;
select * from test_delete;

-- Test DELETE with greater than or equal operator (>=)
delete from test_delete where age >= 45;
select * from test_delete;

-- Test DELETE with less than or equal operator (<=)
delete from test_delete where salary <= 95000;
select * from test_delete;

shutdown;