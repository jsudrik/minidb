#!/bin/bash

# Simple 10 Records Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="simple_10.db"
TEST_PORT=6028

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Simple 10 Records Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10))"
    for i in {1..10}; do
        echo "insert into test values ($i, 'Name$i')"
    done
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > before.log

wait $SERVER_PID

echo "=== Before Recovery ==="
echo "Records before recovery:"
grep -c "Name[0-9]" before.log || echo "0"
echo "First few records:"
grep "Name[1-3]" before.log || echo "None found"

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > after.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== After Recovery ==="
echo "Records after recovery:"
grep -c "Name[0-9]" after.log || echo "0"
echo "First few records:"
grep "Name[1-3]" after.log || echo "None found"
echo "All recovered records:"
grep "Name[0-9]" after.log || echo "None found"

echo ""
echo "=== Analysis ==="
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Recovery record size: $(grep "Setting recovery record size" server2.log)"

BEFORE_COUNT=$(grep -c "Name[0-9]" before.log || echo "0")
AFTER_COUNT=$(grep -c "Name[0-9]" after.log || echo "0")

echo "Before: $BEFORE_COUNT records"
echo "After: $AFTER_COUNT records"

if [ "$AFTER_COUNT" -eq "10" ]; then
    echo "✅ SUCCESS: All 10 records recovered correctly"
elif [ "$AFTER_COUNT" -gt "0" ]; then
    echo "⚠️  PARTIAL: $AFTER_COUNT out of 10 records recovered"
else
    echo "❌ FAILED: No records recovered"
fi

cleanup