#!/bin/bash

# WHERE Debug Test - Step by step debugging

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="where_debug.db"
TEST_PORT=6800

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "🔍 WHERE Clause Debug Test"
echo "=========================="

cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "Step 1: Setup data"
{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
    echo "insert into test values (2, 'Bob')"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > setup.log 2>&1

echo "✅ Setup completed"

echo ""
echo "Step 2: Test WHERE parsing (this should show debug messages)"

# Test WHERE clause with detailed logging
echo "select * from test where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > where_result.log 2>&1 &
CLIENT_PID=$!

# Wait a bit for processing
sleep 5

# Check if client is still running (hung) or finished
if kill -0 $CLIENT_PID 2>/dev/null; then
    echo "❌ Client hung - killing it"
    kill $CLIENT_PID
else
    echo "✅ Client finished"
fi

echo ""
echo "Step 3: Analyze server logs"

echo "WHERE parsing debug messages:"
grep -i "debug.*where\|optimizer.*where" server.log || echo "No WHERE debug messages"

echo ""
echo "Last server activity:"
tail -10 server.log

echo ""
echo "Client result:"
cat where_result.log

# Cleanup
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1
wait $SERVER_PID

cleanup