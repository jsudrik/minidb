#!/bin/bash

# Detailed Diagnostic Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="diagnostic.db"
TEST_PORT=6021

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Detailed Diagnostic Test ==="
echo "PAGE_SIZE: 4096 bytes"
echo "Available space per page: $((4096 - 12)) bytes (4084 bytes)"
cleanup

# Test with 100 records first
echo ""
echo "=== Testing 100 Records ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

# Create table with known record size
echo "create table test (id int, name varchar(50), description varchar(100), value int)" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

# Calculate expected record size: 1 (delete flag) + 4 (int) + 51 (varchar50+null) + 101 (varchar100+null) + 4 (int) = 161 bytes
echo "Expected record size: 161 bytes per record"
echo "Records per page: $((4084 / 161)) = 25 records per page"
echo "100 records should need: $((100 / 25)) = 4 pages"

echo ""
echo "Inserting 100 records..."
for ((i=1; i<=100; i++)); do
    echo "insert into test values ($i, 'Name$i', 'Description for record number $i with more text to make it longer', $((i*100)))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null
    if [ $((i % 25)) -eq 0 ]; then
        echo "Inserted $i records..."
    fi
done

echo ""
echo "=== Data Verification Before Reboot ==="
echo "First 5 records:"
echo "select * from test where id <= 5" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > first_5.log
cat first_5.log

echo ""
echo "Last 5 records:"
echo "select * from test where id >= 96" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > last_5.log
cat last_5.log

echo ""
echo "Record count verification:"
echo "select count(*) from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > count.log
cat count.log

echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
wait $SERVER_PID

echo ""
echo "=== Storage Analysis ==="
echo "WAL records written:"
grep "WAL: Wrote" server1.log | wc -l
echo "Auto-commits performed:"
grep "auto-committed" server1.log | wc -l
echo "Page allocations:"
grep "Allocated new page" server1.log | wc -l
echo "Page usage summary:"
grep "SCAN:" server1.log | tail -n 5

echo ""
echo "WAL file analysis:"
if [ -f "minidb.wal" ]; then
    echo "WAL file size: $(wc -c < minidb.wal) bytes"
    echo "WAL records: $(($(wc -c < minidb.wal) / 552)) records (assuming 552 bytes per WAL record)"
else
    echo "No WAL file found"
fi

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "First 5 records after recovery:"
echo "select * from test where id <= 5" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_first_5.log
cat recovered_first_5.log

echo ""
echo "Last 5 records after recovery:"
echo "select * from test where id >= 96" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_last_5.log
cat recovered_last_5.log

echo ""
echo "Record count after recovery:"
echo "select count(*) from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_count.log
cat recovered_count.log

echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
wait $SERVER_PID

echo ""
echo "=== Recovery Analysis ==="
echo "REDO operations:"
grep "REDO: Applied INSERT" server2.log | wc -l
echo "Page allocations during recovery:"
grep "REDO: Allocated page" server2.log | wc -l
echo "Recovery record size:"
grep "Setting recovery record size" server2.log
echo "Page usage after recovery:"
grep "SCAN:" server2.log | tail -n 5

echo ""
echo "=== Comparison ==="
echo "Original first record: $(grep "1.*Name1" first_5.log || echo "MISSING")"
echo "Recovered first record: $(grep "1.*Name1" recovered_first_5.log || echo "MISSING")"
echo ""
echo "Original last record: $(grep "100.*Name100" last_5.log || echo "MISSING")"
echo "Recovered last record: $(grep "100.*Name100" recovered_last_5.log || echo "MISSING")"

# Count comparison
ORIGINAL_COUNT=$(grep -o "([0-9]* row" count.log | grep -o "[0-9]*" || echo "0")
RECOVERED_COUNT=$(grep -o "([0-9]* row" recovered_count.log | grep -o "[0-9]*" || echo "0")

echo ""
echo "Original count: $ORIGINAL_COUNT"
echo "Recovered count: $RECOVERED_COUNT"

if [ "$ORIGINAL_COUNT" -eq "$RECOVERED_COUNT" ] && [ "$RECOVERED_COUNT" -eq "100" ]; then
    echo "✅ COMPLETE SUCCESS: All 100 records recovered correctly"
else
    echo "❌ RECOVERY ISSUE: Expected 100, got $RECOVERED_COUNT"
fi

cleanup