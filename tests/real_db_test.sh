#!/bin/bash

echo "Testing real database functionality..."

# Start server
../server/minidb_server 8700 real_test.db &
SERVER_PID=$!
sleep 2

echo "Test 1: CREATE TABLE"
echo "create table users (id int, email varchar(20))" | ../client/minidb_client 127.0.0.1 8700

echo ""
echo "Test 2: INSERT real data"
echo "insert into users values (100, 'test@example.com')" | ../client/minidb_client 127.0.0.1 8700

echo ""
echo "Test 3: INSERT more real data"
echo "insert into users values (200, 'user@domain.org')" | ../client/minidb_client 127.0.0.1 8700

echo ""
echo "Test 4: SELECT all (should show real inserted data)"
echo "select * from users" | ../client/minidb_client 127.0.0.1 8700

echo ""
echo "Test 5: SELECT with WHERE (should filter real data)"
echo "select * from users where id = 100" | ../client/minidb_client 127.0.0.1 8700

echo ""
echo "Test 6: DESCRIBE table"
echo "describe users" | ../client/minidb_client 127.0.0.1 8700

echo ""
echo "Shutting down..."
echo "shutdown" | ../client/minidb_client 127.0.0.1 8700

wait $SERVER_PID 2>/dev/null
rm -f real_test.db* minidb.wal*