create table test (id int, name varchar(20), value int);
insert into test values (1, 'Alice', 100);
insert into test values (2, 'Bob', 200);
insert into test values (3, 'Charlie', 300);
select id from test;
select name from test;
select id, name from test;
shutdown;