#!/bin/bash

# Simple WHERE clause test

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="where_test.db"
TEST_PORT=6200

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "=== Simple WHERE Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
    echo "insert into test values (2, 'Bob')"
    echo "select * from test"
    echo "select * from test where id = 1"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo ""
echo "Server log:"
cat server.log | grep "OPTIMIZER\|WHERE\|Error"

cleanup