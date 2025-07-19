-- Test for UPDATE with various operators
create table test_update (
    id int,
    name varchar(50),
    age int,
    salary int,
    active int
);

-- Insert test data
insert into test_update values (1, 'Alice', 30, 75000, 1);
insert into test_update values (2, 'Bob', 35, 85000, 1);
insert into test_update values (3, 'Charlie', 40, 95000, 0);
insert into test_update values (4, 'David', 45, 105000, 1);
insert into test_update values (5, 'Eve', 50, 115000, 0);

-- Show initial data
select * from test_update;

-- Test UPDATE with equality operator (=)
update test_update set name = 'Charles' where id = 3;
select * from test_update;

-- Test UPDATE with greater than operator (>)
update test_update set salary = 120000 where age > 45;
select * from test_update;

-- Test UPDATE with less than operator (<)
update test_update set active = 0 where age < 35;
select * from test_update;

-- Test UPDATE with greater than or equal operator (>=)
update test_update set name = 'Senior' where age >= 40;
select * from test_update;

-- Test UPDATE with less than or equal operator (<=)
update test_update set salary = 90000 where salary <= 90000;
select * from test_update;

shutdown;