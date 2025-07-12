#!/bin/bash

echo "Testing query processing functionality..."

# Start server
../server/minidb_server 8500 query_test.db &
SERVER_PID=$!
sleep 2

echo "Test 1: CREATE TABLE"
echo "create table employees (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 8500

echo ""
echo "Test 2: INSERT"
echo "insert into employees values (1, 'Alice')" | ../client/minidb_client 127.0.0.1 8500

echo ""
echo "Test 3: SELECT without WHERE"
echo "select * from employees" | ../client/minidb_client 127.0.0.1 8500

echo ""
echo "Test 4: SELECT with WHERE"
echo "select * from employees where id = 1" | ../client/minidb_client 127.0.0.1 8500

echo ""
echo "Test 5: UPDATE with WHERE"
echo "update employees set name = 'Bob' where id = 1" | ../client/minidb_client 127.0.0.1 8500

echo ""
echo "Test 6: DELETE with WHERE"
echo "delete from employees where id = 1" | ../client/minidb_client 127.0.0.1 8500

echo ""
echo "Shutting down server..."
echo "shutdown" | ../client/minidb_client 127.0.0.1 8500

wait $SERVER_PID 2>/dev/null
rm -f query_test.db* minidb.wal*