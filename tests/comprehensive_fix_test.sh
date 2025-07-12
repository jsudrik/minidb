#!/bin/bash

echo "Testing all three critical fixes..."

# Start server
../server/minidb_server 9000 fix_test.db &
SERVER_PID=$!
sleep 2

echo "=== Test 1: UPDATE (should not crash) ==="
echo "create table test (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 9000
echo "insert into test values (1, 'Alice')" | ../client/minidb_client 127.0.0.1 9000
echo "update test set name = 'Bob' where id = 1" | ../client/minidb_client 127.0.0.1 9000

echo ""
echo "=== Test 2: SELECT with column list ==="
echo "select id from test" | ../client/minidb_client 127.0.0.1 9000
echo "select name from test" | ../client/minidb_client 127.0.0.1 9000

echo ""
echo "=== Test 3: Data persistence (restart test) ==="
echo "insert into test values (2, 'Carol')" | ../client/minidb_client 127.0.0.1 9000
echo "select * from test" | ../client/minidb_client 127.0.0.1 9000

echo "shutdown" | ../client/minidb_client 127.0.0.1 9000
wait $SERVER_PID 2>/dev/null

echo ""
echo "=== Restarting server to test recovery ==="
../server/minidb_server 9000 fix_test.db &
SERVER_PID=$!
sleep 3

echo "select * from test" | ../client/minidb_client 127.0.0.1 9000

echo "shutdown" | ../client/minidb_client 127.0.0.1 9000
wait $SERVER_PID 2>/dev/null

rm -f fix_test.db* minidb.wal*