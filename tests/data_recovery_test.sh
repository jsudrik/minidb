#!/bin/bash

echo "Testing data recovery fix..."

# Start server
../server/minidb_server 9200 recovery_test.db &
SERVER_PID=$!
sleep 2

echo "=== Creating table and inserting data ==="
echo "create table employees (id int, name varchar(10), dept varchar(15))" | ../client/minidb_client 127.0.0.1 9200
echo "insert into employees values (1, 'Alice', 'Engineering')" | ../client/minidb_client 127.0.0.1 9200
echo "insert into employees values (2, 'Bob', 'Marketing')" | ../client/minidb_client 127.0.0.1 9200

echo ""
echo "=== Data before shutdown ==="
echo "select * from employees" | ../client/minidb_client 127.0.0.1 9200

echo "shutdown" | ../client/minidb_client 127.0.0.1 9200
wait $SERVER_PID 2>/dev/null

echo ""
echo "=== Restarting server to test recovery ==="
../server/minidb_server 9200 recovery_test.db &
SERVER_PID=$!
sleep 3

echo "=== Data after restart (should be recovered) ==="
echo "select * from employees" | ../client/minidb_client 127.0.0.1 9200

echo "shutdown" | ../client/minidb_client 127.0.0.1 9200
wait $SERVER_PID 2>/dev/null

rm -f recovery_test.db* minidb.wal*