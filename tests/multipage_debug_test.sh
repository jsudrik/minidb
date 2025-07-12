#!/bin/bash

# Multi-page Debug Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="multipage.db"
TEST_PORT=6016

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Multi-page Debug Test ==="
cleanup

# Test with 10 records first
echo "Test: Insert 10 records..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10))"
    for ((i=1; i<=10; i++)); do
        echo "insert into test values ($i, 'Item$i')"
    done
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test1.log

wait $SERVER_PID

echo "=== Original 10 Records ==="
cat test1.log | grep -A 15 "select \* from test"

echo ""
echo "=== Server Log Analysis ==="
echo "Page allocations:"
grep "Allocated new page" server1.log || echo "No new pages allocated"
echo "Insert operations:"
grep "INSERT:" server1.log | wc -l

# Recovery test
echo ""
echo "Recovery test..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test2.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== Recovered Records ==="
cat test2.log

echo ""
echo "=== Recovery Analysis ==="
echo "REDO operations:"
grep "REDO:" server2.log | wc -l
echo "Page allocations during recovery:"
grep "Allocated new page" server2.log || echo "No new pages allocated during recovery"

cleanup