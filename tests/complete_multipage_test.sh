#!/bin/bash

# Complete Multi-page Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="complete_multipage.db"
TEST_PORT=6019

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

test_multipage() {
    local count=$1
    echo "=== Testing $count Records ==="
    cleanup
    
    # Phase 1: Insert records and check page usage
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    echo "create table data (id int, name varchar(20), value int)" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    for ((i=1; i<=count; i++)); do
        echo "insert into data values ($i, 'Record$i', $((i*100)))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null
    done
    
    echo "select * from data where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > first.log
    echo "select * from data where id = $count" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > last.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo "Page usage during insertion:"
    grep "SCAN:" server1.log || echo "No scan info"
    grep "Allocated new page" server1.log || echo "No additional pages allocated"
    
    echo "Original data verification:"
    echo "First: $(grep "Record1" first.log || echo "MISSING")"
    echo "Last:  $(grep "Record$count" last.log || echo "MISSING")"
    
    # Phase 2: Recovery test
    echo ""
    echo "Recovery test..."
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    echo "select * from data where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_first.log
    echo "select * from data where id = $count" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_last.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo "Page usage after recovery:"
    grep "SCAN:" server2.log || echo "No scan info"
    grep "REDO:" server2.log | wc -l | xargs echo "REDO operations:"
    
    echo "Recovered data verification:"
    echo "First: $(grep "Record1" recovered_first.log || echo "MISSING")"
    echo "Last:  $(grep "Record$count" recovered_last.log || echo "MISSING")"
    
    if grep -q "Record1" recovered_first.log && grep -q "Record$count" recovered_last.log; then
        echo "✅ $count records: COMPLETE RECOVERY SUCCESS"
        return 0
    else
        echo "❌ $count records: RECOVERY FAILED"
        return 1
    fi
}

echo "=== Complete Multi-page Recovery Test ==="

# Test 50 records
if test_multipage 50; then
    RESULT_50="PASS"
else
    RESULT_50="FAIL"
fi

echo ""

# Test 100 records
if test_multipage 100; then
    RESULT_100="PASS"
else
    RESULT_100="FAIL"
fi

echo ""
echo "=== FINAL RESULTS ==="
echo "50 records:  $RESULT_50"
echo "100 records: $RESULT_100"

if [ "$RESULT_50" = "PASS" ] && [ "$RESULT_100" = "PASS" ]; then
    echo ""
    echo "🎉 COMPLETE MULTI-PAGE DURABILITY: SUCCESS!"
else
    echo ""
    echo "⚠️  MULTI-PAGE DURABILITY: NEEDS FURTHER INVESTIGATION"
fi

cleanup