#!/bin/bash

# Multi-page Durability Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="multipage.db"
TEST_PORT=6033

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

test_multipage() {
    local count=$1
    echo "=== Testing $count Records (Multi-page) ==="
    cleanup
    
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    # Use single client session for all operations
    {
        echo "create table test (id int, name varchar(100), description varchar(200), value int)"
        
        # Insert all records in single session
        for ((i=1; i<=count; i++)); do
            echo "insert into test values ($i, 'Name$i with longer text to force multiple pages', 'This is a much longer description for record $i to ensure we use more space per record and force page overflow', $((i*100)))"
        done
        
        echo "select * from test"
        echo "shutdown"
    } | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > before.log
    
    wait $SERVER_PID
    
    echo "SELECT ALL RECORDS before recovery:"
    grep -A 1000 "select \* from test" before.log | grep -E "^[0-9]" | head -n 10
    echo "... (showing first 10 records)"
    echo "Total records before: $(grep -c "Name[0-9]" before.log)"
    
    # Recovery test
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > after.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo ""
    echo "SELECT ALL RECORDS after recovery:"
    grep -A 1000 "select \* from test" after.log | grep -E "^[0-9]" | head -n 10
    echo "... (showing first 10 records)"
    echo "Total records after: $(grep -c "Name[0-9]" after.log)"
    
    echo ""
    echo "Analysis:"
    echo "WAL records: $(grep "WAL: Wrote" server1.log | wc -l)"
    echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
    echo "Page allocations: $(grep "Allocated new page" server1.log | wc -l)"
    echo "Scan results: $(grep "scan_table:" server2.log)"
    
    local before_count=$(grep -c "Name[0-9]" before.log)
    local after_count=$(grep -c "Name[0-9]" after.log)
    
    if [ "$after_count" -eq "$before_count" ] && [ "$after_count" -eq "$count" ]; then
        echo "✅ $count records: COMPLETE SUCCESS"
        return 0
    else
        echo "❌ $count records: Expected $count, got $after_count"
        return 1
    fi
}

echo "=== Multi-page Durability Test ==="
echo "Using larger records to force multi-page storage:"
echo "Record size: ~320 bytes (should fit ~12 records per page)"

# Test 50 records (should need ~4 pages)
if test_multipage 50; then
    RESULT_50="PASS"
else
    RESULT_50="FAIL"
fi

echo ""

# Test 100 records (should need ~8 pages)  
if test_multipage 100; then
    RESULT_100="PASS"
else
    RESULT_100="FAIL"
fi

echo ""
echo "=== FINAL RESULTS ==="
echo "50 records (multi-page):  $RESULT_50"
echo "100 records (multi-page): $RESULT_100"

if [ "$RESULT_50" = "PASS" ] && [ "$RESULT_100" = "PASS" ]; then
    echo ""
    echo "🎉 MULTI-PAGE DURABILITY SUCCESS!"
else
    echo ""
    echo "⚠️  MULTI-PAGE DURABILITY ISSUES"
fi

cleanup