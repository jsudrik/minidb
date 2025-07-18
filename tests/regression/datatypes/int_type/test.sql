create table int_test (id int, value int);
insert into int_test values (1, 100);
insert into int_test values (2, 200);
insert into int_test values (3, -300);
insert into int_test values (4, 2147483647);
select * from int_test;
select * from int_test where value > 0;
select * from int_test where value < 0;
shutdown;