#!/bin/bash

echo "Debugging server crash..."

# Start server with minimal input
echo "Starting server..."
../server/minidb_server 8900 crash_debug.db > server_output.log 2>&1 &
SERVER_PID=$!

sleep 3

echo "Sending CREATE TABLE command..."
echo "create table test (id int)" | ../client/minidb_client 127.0.0.1 8900 > client_output.log 2>&1

sleep 2

# Check if server is still running
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "Server is still running"
    echo "shutdown" | ../client/minidb_client 127.0.0.1 8900 > /dev/null 2>&1
    wait $SERVER_PID
else
    echo "Server crashed"
fi

echo "Server output:"
cat server_output.log

echo ""
echo "Client output:"
cat client_output.log

rm -f crash_debug.db* minidb.wal* server_output.log client_output.log