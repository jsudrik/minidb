#!/bin/bash
echo "Testing WHERE clause..."
../server/minidb_server 8300 test.db &
sleep 2
echo "create table t (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 8300
echo "insert into t values (1, 'Alice')" | ../client/minidb_client 127.0.0.1 8300
echo "insert into t values (2, 'Bob')" | ../client/minidb_client 127.0.0.1 8300
echo "select * from t where id = 1" | ../client/minidb_client 127.0.0.1 8300
pkill minidb_server
rm -f test.db*