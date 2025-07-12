#!/bin/bash

echo "Testing DML fixes: INSERT auto-commit, UPDATE crash fix, DELETE functionality..."

# Start server
../server/minidb_server 9400 dml_fix_test.db &
SERVER_PID=$!
sleep 2

echo "=== Test 1: CREATE TABLE ==="
echo "create table test_dml (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 9400

echo ""
echo "=== Test 2: INSERT with auto-commit ==="
echo "insert into test_dml values (1, 'Alice')" | ../client/minidb_client 127.0.0.1 9400
echo "insert into test_dml values (2, 'Bob')" | ../client/minidb_client 127.0.0.1 9400

echo ""
echo "=== Test 3: SELECT to verify INSERT ==="
echo "select * from test_dml" | ../client/minidb_client 127.0.0.1 9400

echo ""
echo "=== Test 4: UPDATE (should not crash) ==="
echo "update test_dml set name = 'Charlie' where id = 1" | ../client/minidb_client 127.0.0.1 9400

echo ""
echo "=== Test 5: SELECT after UPDATE ==="
echo "select * from test_dml" | ../client/minidb_client 127.0.0.1 9400

echo ""
echo "=== Test 6: Shutdown and restart to test recovery ==="
echo "shutdown" | ../client/minidb_client 127.0.0.1 9400
wait $SERVER_PID 2>/dev/null

echo ""
echo "=== Restarting server ==="
../server/minidb_server 9400 dml_fix_test.db &
SERVER_PID=$!
sleep 3

echo "=== Test 7: SELECT after restart (should show correct data) ==="
echo "select * from test_dml" | ../client/minidb_client 127.0.0.1 9400

echo "shutdown" | ../client/minidb_client 127.0.0.1 9400
wait $SERVER_PID 2>/dev/null

rm -f dml_fix_test.db* minidb.wal*