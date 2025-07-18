create table test (id int, name varchar(20), value int);
insert into test values (1, 'Alice', 100);
insert into test values (2, 'Bob', 200);
insert into test values (3, 'Charlie', 300);
update test set name = 'Updated' where id = 2;
delete from test where id = 3;
select * from test;
shutdown;