#!/bin/bash

# Quick DML Durability Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="quick_dml.db"
TEST_PORT=6005

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Quick DML Durability Test ==="
cleanup

# Test 1: Basic INSERT durability
echo "Test 1: INSERT durability"
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
    echo "insert into test values (2, 'Bob')"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test1.log

wait $SERVER_PID

# Restart and check
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test1_recovery.log

wait $SERVER_PID

echo "=== INSERT Test Results ==="
echo "Original data:"
grep -A 10 "select \* from test" test1.log | tail -n +2
echo ""
echo "After restart:"
grep -A 10 "select \* from test" test1_recovery.log | tail -n +2

if grep -q "Alice" test1_recovery.log && grep -q "Bob" test1_recovery.log; then
    echo "✅ INSERT durability: PASS"
else
    echo "❌ INSERT durability: FAIL"
fi

echo ""
echo "=== Server Recovery Logs ==="
echo "Server 1 log:"
tail -n 5 server1.log
echo ""
echo "Server 2 log (recovery):"
tail -n 10 server2.log

cleanup