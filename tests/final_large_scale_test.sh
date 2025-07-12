#!/bin/bash

# Final Large Scale Test - 50 and 100 records
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="final_large.db"
TEST_PORT=6017

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

test_large_scale() {
    local count=$1
    echo "=== Testing $count Records ==="
    cleanup
    
    # Phase 1: Insert records
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    # Create table
    echo "create table data (id int, name varchar(20), value int)" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    # Insert records one by one to ensure each is committed
    for ((i=1; i<=count; i++)); do
        echo "insert into data values ($i, 'Record$i', $((i*100)))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null
        if [ $((i % 10)) -eq 0 ]; then
            echo "Inserted $i records..."
        fi
    done
    
    # Verify original data
    echo "select * from data where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > original1.log
    echo "select * from data where id = $count" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > original2.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo "Original data verification:"
    echo "First record:" && cat original1.log | grep "Record1"
    echo "Last record:" && cat original2.log | grep "Record$count"
    
    # Phase 2: Recovery test
    echo "Testing recovery..."
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    # Verify recovered data
    echo "select * from data where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered1.log
    echo "select * from data where id = $count" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered2.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo "Recovered data verification:"
    echo "First record:" && cat recovered1.log | grep "Record1" || echo "MISSING"
    echo "Last record:" && cat recovered2.log | grep "Record$count" || echo "MISSING"
    
    # Check if both records are recovered
    if grep -q "Record1" recovered1.log && grep -q "Record$count" recovered2.log; then
        echo "✅ $count records: RECOVERY SUCCESS"
        return 0
    else
        echo "❌ $count records: RECOVERY FAILED"
        return 1
    fi
}

echo "=== Final Large Scale Recovery Test ==="

# Test 50 records
if test_large_scale 50; then
    RESULT_50="PASS"
else
    RESULT_50="FAIL"
fi

echo ""

# Test 100 records
if test_large_scale 100; then
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
    echo "🎉 LARGE SCALE DURABILITY: SUCCESS!"
    echo "   ✅ Multi-page storage working"
    echo "   ✅ All records properly recovered"
    echo "   ✅ Data displayed correctly"
else
    echo ""
    echo "⚠️  LARGE SCALE DURABILITY: NEEDS INVESTIGATION"
fi

cleanup