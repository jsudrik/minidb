#!/bin/bash

echo "Testing DDL WAL logging and auto-commit..."

# Start server
../server/minidb_server 9300 ddl_wal_test.db &
SERVER_PID=$!
sleep 2

echo "=== Test DDL WAL logging ==="
echo "create table test_ddl (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 9300

echo ""
echo "=== Test data operations ==="
echo "insert into test_ddl values (1, 'Alice')" | ../client/minidb_client 127.0.0.1 9300
echo "select * from test_ddl" | ../client/minidb_client 127.0.0.1 9300

echo ""
echo "=== Shutdown and restart to test DDL recovery ==="
echo "shutdown" | ../client/minidb_client 127.0.0.1 9300
wait $SERVER_PID 2>/dev/null

echo ""
echo "=== Restarting server ==="
../server/minidb_server 9300 ddl_wal_test.db &
SERVER_PID=$!
sleep 3

echo "=== Test recovery after DDL auto-commit ==="
echo "select * from test_ddl" | ../client/minidb_client 127.0.0.1 9300

echo "shutdown" | ../client/minidb_client 127.0.0.1 9300
wait $SERVER_PID 2>/dev/null

rm -f ddl_wal_test.db* minidb.wal*