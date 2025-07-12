#!/bin/bash

echo "Testing SELECT column list and data recovery fixes..."

# Start server
../server/minidb_server 9100 two_fixes.db &
SERVER_PID=$!
sleep 2

echo "=== Test 1: SELECT with column list ==="
echo "create table employees (id int, name varchar(10), dept varchar(15))" | ../client/minidb_client 127.0.0.1 9100
echo "insert into employees values (1, 'Alice', 'Engineering')" | ../client/minidb_client 127.0.0.1 9100
echo "insert into employees values (2, 'Bob', 'Marketing')" | ../client/minidb_client 127.0.0.1 9100

echo ""
echo "SELECT * (should show all columns):"
echo "select * from employees" | ../client/minidb_client 127.0.0.1 9100

echo ""
echo "SELECT id (should show only id column):"
echo "select id from employees" | ../client/minidb_client 127.0.0.1 9100

echo ""
echo "SELECT name (should show only name column):"
echo "select name from employees" | ../client/minidb_client 127.0.0.1 9100

echo ""
echo "SELECT id, name (should show id and name columns):"
echo "select id, name from employees" | ../client/minidb_client 127.0.0.1 9100

echo ""
echo "=== Test 2: Data persistence after restart ==="
echo "Current data before shutdown:"
echo "select * from employees" | ../client/minidb_client 127.0.0.1 9100

echo "shutdown" | ../client/minidb_client 127.0.0.1 9100
wait $SERVER_PID 2>/dev/null

echo ""
echo "=== Restarting server to test recovery ==="
../server/minidb_server 9100 two_fixes.db &
SERVER_PID=$!
sleep 3

echo "Data after restart (should be same as before):"
echo "select * from employees" | ../client/minidb_client 127.0.0.1 9100

echo "shutdown" | ../client/minidb_client 127.0.0.1 9100
wait $SERVER_PID 2>/dev/null

rm -f two_fixes.db* minidb.wal*