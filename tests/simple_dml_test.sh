#!/bin/bash

# Simple DML Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="simple_dml.db"
TEST_PORT=6003

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "=== Simple DML Test ==="
cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

# Test basic DML operations
{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
    echo "insert into test values (2, 'Bob')"
    echo "select * from test"
    echo "update test set name = 'Charlie' where id = 1"
    echo "select * from test"
    echo "delete from test where id = 2"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test_output.log

wait $SERVER_PID

echo "=== Test Results ==="
cat test_output.log

cleanup