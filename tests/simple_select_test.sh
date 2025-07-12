#!/bin/bash

# Simple SELECT Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="simple_select.db"
TEST_PORT=6022

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Simple SELECT Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table simple (id int, name varchar(10))"
    echo "insert into simple values (1, 'Alice')"
    echo "insert into simple values (2, 'Bob')"
    echo "select * from simple"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > results.log

wait $SERVER_PID

echo "=== Results ==="
cat results.log

echo ""
echo "=== Server Log Analysis ==="
echo "Scan operations:"
grep "scan_table:" server.log
echo "SCAN page info:"
grep "SCAN:" server.log

cleanup