#!/bin/bash

# Simple 3 Records Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="simple_3.db"
TEST_PORT=6027

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Simple 3 Records Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10))"
    echo "insert into test values (1, 'Alice')"
    echo "insert into test values (2, 'Bob')"
    echo "insert into test values (3, 'Charlie')"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > before.log

wait $SERVER_PID

echo "=== Before Recovery ==="
cat before.log

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > after.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== After Recovery ==="
cat after.log

echo ""
echo "=== Analysis ==="
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Recovery record size: $(grep "Setting recovery record size" server2.log)"

if grep -q "Alice" after.log && grep -q "Bob" after.log && grep -q "Charlie" after.log; then
    echo "✅ SUCCESS: All 3 records recovered correctly"
else
    echo "❌ FAILED: Records not recovered correctly"
    echo "Expected: Alice, Bob, Charlie"
    echo "Got: $(grep -o "Name[0-9]*\|Alice\|Bob\|Charlie" after.log | tr '\n' ' ')"
fi

cleanup