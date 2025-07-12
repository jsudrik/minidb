#!/bin/bash

# Step by Step Investigation Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="step_by_step.db"
TEST_PORT=6026

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Step by Step Investigation ==="
cleanup

echo "Step 1: Start server and create table"
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

echo "create table test (id int, name varchar(20))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "✅ Table created"

echo ""
echo "Step 2: Insert 5 records"
for i in {1..5}; do
    echo "insert into test values ($i, 'Name$i')" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    echo "Inserted record $i"
done

echo ""
echo "Step 3: Try SELECT before recovery"
echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > select_before.log
echo "SELECT before recovery:"
cat select_before.log

echo ""
echo "Step 4: Shutdown server"
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
wait $SERVER_PID

echo ""
echo "Step 5: Check server logs"
echo "WAL records: $(grep "WAL: Wrote" server1.log | wc -l)"
echo "Scan results: $(grep "scan_table:" server1.log || echo "No scan results")"

echo ""
echo "Step 6: Restart server for recovery"
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo ""
echo "Step 7: Try SELECT after recovery"
echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > select_after.log
echo "SELECT after recovery:"
cat select_after.log

echo ""
echo "Step 8: Shutdown and analyze"
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
wait $SERVER_PID

echo ""
echo "=== Analysis ==="
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Recovery scan results: $(grep "scan_table:" server2.log || echo "No scan results")"

echo ""
echo "=== Comparison ==="
echo "Before recovery file size: $(wc -c < select_before.log) bytes"
echo "After recovery file size: $(wc -c < select_after.log) bytes"

if grep -q "Name1" select_after.log; then
    echo "✅ SUCCESS: Data visible after recovery"
else
    echo "❌ ISSUE: Data not visible after recovery"
fi

cleanup