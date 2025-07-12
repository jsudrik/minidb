#!/bin/bash

# Minimal Recovery Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="minimal.db"
TEST_PORT=6013

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Minimal Recovery Test ==="
cleanup

# Test 1: Basic insert and immediate select
echo "Test 1: Basic operations..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

echo "create table test (id int, name varchar(10))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "insert into test values (1, 'Alice')" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "insert into test values (2, 'Bob')" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test1.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== Test 1 Results ==="
cat test1.log

# Test 2: Recovery
echo ""
echo "Test 2: Recovery..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test2.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== Test 2 Results ==="
cat test2.log

echo ""
echo "=== Server Logs ==="
echo "Server 1 WAL records:"
grep "WAL: Wrote" server1.log | wc -l
echo "Server 2 REDO operations:"
grep "REDO:" server2.log | wc -l

cleanup