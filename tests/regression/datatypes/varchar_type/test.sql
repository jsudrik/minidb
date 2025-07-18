create table varchar_test (id int, name varchar(50));
insert into varchar_test values (1, 'Alice');
insert into varchar_test values (2, 'Bob');
insert into varchar_test values (3, 'Charlie');
insert into varchar_test values (4, 'This is a longer string to test varchar limits');
select * from varchar_test;
select * from varchar_test where name = 'Bob';
shutdown;