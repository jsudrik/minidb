#!/bin/bash

# Simple SELECT Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="simple_select.db"
TEST_PORT=6039

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Simple SELECT Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

echo "create table test (id int, name varchar(20))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "insert into test values (1, 'Alice')" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "select id from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

cleanup