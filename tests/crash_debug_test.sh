#!/bin/bash

# Crash Debug Test - Find exact crash point

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="crash_debug.db"
TEST_PORT=7100

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "🔍 Crash Debug Test"
echo "==================="

cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "Step 1: Setup simple data"
{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > setup.log 2>&1

echo "✅ Setup completed"

echo ""
echo "Step 2: Test WHERE query with detailed logging"

# Run WHERE query and monitor for crash
echo "select * from test where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > where_result.log 2>&1 &
CLIENT_PID=$!

# Monitor for 10 seconds
for i in {1..10}; do
    if ! kill -0 $CLIENT_PID 2>/dev/null; then
        echo "Client finished after $i seconds"
        break
    fi
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo "Server crashed after $i seconds"
        break
    fi
    sleep 1
done

# Kill client if still running
kill $CLIENT_PID 2>/dev/null

echo ""
echo "Step 3: Analyze crash point"

echo "Last server debug messages:"
tail -20 server.log

echo ""
echo "Client result:"
cat where_result.log

echo ""
echo "Server status:"
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "Server still running"
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1
    wait $SERVER_PID
else
    echo "Server crashed/exited"
fi

cleanup