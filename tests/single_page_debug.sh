#!/bin/bash

# Single Page Debug Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="single_page_debug.db"
TEST_PORT=6032

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Single Page Debug Test ==="
echo "Expected: 50 records × 30 bytes = 1500 bytes (should fit in 4084-byte page)"
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(20), value int)"
    for ((i=1; i<=20; i++)); do
        echo "insert into test values ($i, 'Name$i', $((i*100)))"
    done
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > before.log

wait $SERVER_PID

echo "=== Before Recovery Analysis ==="
echo "Records inserted: $(grep "Record inserted successfully" before.log | wc -l)"
echo "Records in SELECT: $(grep -c "Name[0-9]" before.log || echo "0")"
echo "Page allocations: $(grep "Allocated new page" server1.log | wc -l)"
echo "Scan results: $(grep "scan_table:" server1.log)"

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > after.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== After Recovery Analysis ==="
echo "Records in SELECT: $(grep -c "Name[0-9]" after.log || echo "0")"
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Recovery scan: $(grep "scan_table:" server2.log)"

echo ""
echo "=== Detailed REDO Analysis ==="
echo "REDO messages:"
grep "REDO: Applied INSERT" server2.log | head -n 5
echo "..."
grep "REDO: Applied INSERT" server2.log | tail -n 5

echo ""
echo "=== Record Size Analysis ==="
echo "Recovery record size: $(grep "Setting recovery record size" server2.log)"

if [ "$(grep -c "Name[0-9]" after.log || echo "0")" -eq "20" ]; then
    echo "✅ SUCCESS: All 20 records recovered"
else
    echo "❌ ISSUE: Only $(grep -c "Name[0-9]" after.log || echo "0") out of 20 records recovered"
fi

cleanup