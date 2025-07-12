#!/bin/bash

echo "Testing client commands and shutdown..."

# Start server
../server/minidb_server 8400 test.db &
SERVER_PID=$!
sleep 2

echo "Test 1: Simple command"
echo "create table test (id int)" | ../client/minidb_client 127.0.0.1 8400

echo "Test 2: Insert command"  
echo "insert into test values (1)" | ../client/minidb_client 127.0.0.1 8400

echo "Test 3: Select command"
echo "select * from test" | ../client/minidb_client 127.0.0.1 8400

echo "Test 4: Shutdown command"
echo "shutdown" | ../client/minidb_client 127.0.0.1 8400

# Wait a moment for shutdown
sleep 2

# Check if server is still running
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "❌ Server still running after shutdown"
    kill $SERVER_PID
else
    echo "✅ Server shutdown successfully"
fi

rm -f test.db* minidb.wal*