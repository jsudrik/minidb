#!/bin/bash

# Debug SELECT Simple Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="debug_select.db"
TEST_PORT=6024

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Debug SELECT Simple Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

# Very simple test with just 3 records
{
    echo "create table simple (id int, name varchar(10))"
    echo "insert into simple values (1, 'Alice')"
    echo "insert into simple values (2, 'Bob')"
    echo "insert into simple values (3, 'Charlie')"
    echo "select * from simple"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > simple_results.log

wait $SERVER_PID

echo "=== Simple Results ==="
cat simple_results.log

echo ""
echo "=== Server Log Analysis ==="
echo "Scan operations:"
grep "scan_table:" server.log
echo ""
echo "SCAN page details:"
grep "SCAN:" server.log

cleanup