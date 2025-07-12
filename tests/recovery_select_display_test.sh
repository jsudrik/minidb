#!/bin/bash

# Recovery SELECT Display Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="recovery_select.db"
TEST_PORT=6025

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Recovery SELECT Display Test ==="
cleanup

# Phase 1: Insert data with single connection
echo "Phase 1: Inserting 100 records with single connection..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(50), description varchar(100), value int)"
    
    # Insert 100 records
    for ((i=1; i<=100; i++)); do
        echo "insert into test values ($i, 'Name$i', 'Description for record $i', $((i*100)))"
    done
    
    echo "select * from test where id = 1"
    echo "select * from test where id = 50" 
    echo "select * from test where id = 100"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1_results.log

wait $SERVER_PID

echo "=== Phase 1 Results (Before Recovery) ==="
echo "Insert confirmations: $(grep "Record inserted successfully" phase1_results.log | wc -l)"
echo ""
echo "SELECT results before recovery:"
echo "First record (id=1):"
grep -A 5 "select \* from test where id = 1" phase1_results.log
echo ""
echo "Middle record (id=50):"
grep -A 5 "select \* from test where id = 50" phase1_results.log
echo ""
echo "Last record (id=100):"
grep -A 5 "select \* from test where id = 100" phase1_results.log

echo ""
echo "=== Storage Analysis ==="
echo "WAL records written: $(grep "WAL: Wrote" server1.log | wc -l)"
echo "Auto-commits: $(grep "auto-committed" server1.log | wc -l)"
echo "Page allocations: $(grep "Allocated new page" server1.log | wc -l)"
echo "Scan results: $(grep "scan_table:" server1.log)"

# Phase 2: Recovery test
echo ""
echo "=== Phase 2: Recovery Test ==="
echo "Restarting server for recovery..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from test where id = 1"
    echo "select * from test where id = 50"
    echo "select * from test where id = 100"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2_results.log

wait $SERVER_PID

echo "=== Phase 2 Results (After Recovery) ==="
echo "Recovery operations: $(grep "REDO:" server2.log | wc -l)"
echo "Scan results after recovery: $(grep "scan_table:" server2.log)"
echo ""
echo "SELECT results after recovery:"
echo "First record (id=1):"
grep -A 5 "select \* from test where id = 1" phase2_results.log
echo ""
echo "Middle record (id=50):"
grep -A 5 "select \* from test where id = 50" phase2_results.log
echo ""
echo "Last record (id=100):"
grep -A 5 "select \* from test where id = 100" phase2_results.log
echo ""
echo "Full SELECT * results (first 10 lines):"
grep -A 15 "select \* from test$" phase2_results.log | head -n 15

echo ""
echo "=== Summary ==="
BEFORE_SCANS=$(grep "scan_table:" server1.log | tail -n 1 | grep -o "Found [0-9]* rows" | grep -o "[0-9]*" || echo "0")
AFTER_SCANS=$(grep "scan_table:" server2.log | tail -n 1 | grep -o "Found [0-9]* rows" | grep -o "[0-9]*" || echo "0")

echo "Records found before recovery: $BEFORE_SCANS"
echo "Records found after recovery: $AFTER_SCANS"

if [ "$AFTER_SCANS" -eq "100" ]; then
    echo "✅ RECOVERY SUCCESS: All 100 records recovered"
elif [ "$AFTER_SCANS" -gt "0" ]; then
    echo "⚠️  PARTIAL RECOVERY: $AFTER_SCANS records recovered out of 100"
else
    echo "❌ RECOVERY FAILED: No records recovered"
fi

cleanup