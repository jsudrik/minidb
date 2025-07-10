#!/bin/bash

# Minimal test to isolate WHERE clause issue

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="minimal.db"
TEST_PORT=6400

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "=== Minimal WHERE Test ==="
cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

echo "Testing basic queries first..."

# Test 1: Basic queries (should work)
{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
    echo "select * from test"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > basic.log 2>&1

echo "Basic queries result:"
tail -5 basic.log

echo ""
echo "Testing WHERE clause..."

# Test 2: WHERE clause (crashes server)
echo "select * from test where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > where.log 2>&1

echo "WHERE query result:"
cat where.log

echo ""
echo "Server status:"
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "Server still running"
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1
    wait $SERVER_PID
else
    echo "Server crashed/exited"
fi

echo ""
echo "Server log (last 10 lines):"
tail -10 server.log

cleanup