#!/bin/bash

echo "Testing data verification with SELECT..."

# Start server
../server/minidb_server 8600 data_test.db &
SERVER_PID=$!
sleep 2

echo "Step 1: CREATE TABLE"
echo "create table test (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 8600

echo ""
echo "Step 2: INSERT data"
echo "insert into test values (1, 'Alice')" | ../client/minidb_client 127.0.0.1 8600

echo ""
echo "Step 3: INSERT more data"
echo "insert into test values (2, 'Bob')" | ../client/minidb_client 127.0.0.1 8600

echo ""
echo "Step 4: SELECT all data (should show actual records)"
echo "select * from test" | ../client/minidb_client 127.0.0.1 8600

echo ""
echo "Step 5: SELECT with WHERE (should show filtered data)"
echo "select * from test where id = 1" | ../client/minidb_client 127.0.0.1 8600

echo ""
echo "Shutting down..."
echo "shutdown" | ../client/minidb_client 127.0.0.1 8600

wait $SERVER_PID 2>/dev/null
rm -f data_test.db* minidb.wal*