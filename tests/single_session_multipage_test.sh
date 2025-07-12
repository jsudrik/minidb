#!/bin/bash

# Single Session Multi-page Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="single_session_multipage.db"
TEST_PORT=6034

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Single Session Multi-page Test ==="
echo "Using large records to force multiple pages"
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

# Single client session for all operations
{
    echo "create table test (id int, name varchar(100), description varchar(200), value int)"
    
    # Insert 30 large records in single session
    for ((i=1; i<=30; i++)); do
        echo "insert into test values ($i, 'Name$i with very long text to make records larger and force page overflow', 'This is a very long description for record number $i that contains lots of text to ensure each record takes up significant space and forces the database to use multiple pages for storage', $((i*100)))"
    done
    
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > before.log

wait $SERVER_PID

echo "=== Before Recovery ==="
echo "Records inserted: $(grep "Record inserted successfully" before.log | wc -l)"
echo "Total records displayed: $(grep -c "Name[0-9]" before.log)"
echo "Page allocations: $(grep "Allocated new page" server1.log | wc -l)"

echo ""
echo "First 5 records before recovery:"
grep -A 1000 "select \* from test" before.log | grep -E "^[0-9]" | head -n 5

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > after.log
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo "=== After Recovery ==="
echo "Total records displayed: $(grep -c "Name[0-9]" after.log)"
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Recovery scan: $(grep "scan_table:" server2.log)"

echo ""
echo "First 5 records after recovery:"
grep -A 1000 "select \* from test" after.log | grep -E "^[0-9]" | head -n 5

echo ""
echo "=== Analysis ==="
BEFORE_COUNT=$(grep -c "Name[0-9]" before.log)
AFTER_COUNT=$(grep -c "Name[0-9]" after.log)

echo "Before recovery: $BEFORE_COUNT records"
echo "After recovery: $AFTER_COUNT records"

if [ "$AFTER_COUNT" -eq "$BEFORE_COUNT" ] && [ "$AFTER_COUNT" -eq "30" ]; then
    echo "✅ SUCCESS: All 30 records recovered correctly"
else
    echo "❌ ISSUE: Expected 30, got $AFTER_COUNT"
fi

cleanup