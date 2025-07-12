#!/bin/bash

# Recovery Debug Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="recovery_debug.db"
TEST_PORT=6011

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Recovery Debug Test ==="
cleanup

# Phase 1: Insert data and check immediate state
echo "Phase 1: Insert data..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10), value int)"
    echo "insert into test values (1, 'Alice', 100)"
    echo "insert into test values (2, 'Bob', 200)"
    echo "insert into test values (3, 'Charlie', 300)"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log

wait $SERVER_PID

echo "=== Phase 1 Results ==="
grep -A 10 "select \* from test" phase1.log

# Phase 2: Recovery with detailed logging
echo ""
echo "Phase 2: Recovery analysis..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2.log

wait $SERVER_PID

echo "=== Phase 2 Results ==="
cat phase2.log

echo ""
echo "=== Recovery Log Analysis ==="
echo "WAL records found:"
grep "WAL: Wrote" server1.log
echo ""
echo "Recovery operations:"
grep "REDO:" server2.log
echo ""
echo "Record count during recovery:"
grep "record_count" server2.log

cleanup