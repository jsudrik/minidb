#!/bin/bash

# Large Scale Recovery Test - 50 and 100 records
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="large_scale.db"
TEST_PORT=6015

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

test_recovery() {
    local record_count=$1
    local test_name="$record_count records"
    
    echo "=== Testing Recovery: $test_name ==="
    cleanup
    
    # Phase 1: Insert records
    echo "Phase 1: Inserting $record_count records..."
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    {
        echo "create table test_data (id int, name varchar(20), value int)"
        
        for ((i=1; i<=record_count; i++)); do
            echo "insert into test_data values ($i, 'Item$i', $((i*10)))"
        done
        
        echo "select count(*) from test_data"
        echo "select * from test_data where id = 1"
        echo "select * from test_data where id = $record_count"
        echo "shutdown"
    } | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log
    
    wait $SERVER_PID
    
    # Phase 2: Recovery test
    echo "Phase 2: Testing recovery..."
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    {
        echo "select count(*) from test_data"
        echo "select * from test_data where id = 1"
        echo "select * from test_data where id = $((record_count/2))"
        echo "select * from test_data where id = $record_count"
        echo "shutdown"
    } | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2.log
    
    wait $SERVER_PID
    
    # Verify results
    echo "=== Results for $test_name ==="
    echo "Original data verification:"
    grep -A 5 "select \* from test_data where id = 1" phase1.log | tail -n 3
    echo ""
    echo "Recovered data verification:"
    cat phase2.log
    
    # Check if all records recovered
    local recovered_count=$(grep -o "([0-9]* row" phase2.log | head -n 1 | grep -o "[0-9]*" || echo "0")
    
    if [ "$recovered_count" -eq "$record_count" ] && grep -q "Item1" phase2.log && grep -q "Item$record_count" phase2.log; then
        echo "✅ $test_name: PASS - All records recovered correctly"
        return 0
    else
        echo "❌ $test_name: FAIL - Expected $record_count, got $recovered_count"
        return 1
    fi
}

echo "=== Large Scale Recovery Test ==="

# Test 50 records
if test_recovery 50; then
    TEST_50_RESULT="PASS"
else
    TEST_50_RESULT="FAIL"
fi

echo ""

# Test 100 records  
if test_recovery 100; then
    TEST_100_RESULT="PASS"
else
    TEST_100_RESULT="FAIL"
fi

echo ""
echo "=== LARGE SCALE RECOVERY SUMMARY ==="
echo "50 records test:  $TEST_50_RESULT"
echo "100 records test: $TEST_100_RESULT"

if [ "$TEST_50_RESULT" = "PASS" ] && [ "$TEST_100_RESULT" = "PASS" ]; then
    echo ""
    echo "🎉 ALL LARGE SCALE RECOVERY TESTS PASSED!"
    echo "   ✅ 50 records: Fully recovered and displayed"
    echo "   ✅ 100 records: Fully recovered and displayed"
else
    echo ""
    echo "❌ SOME LARGE SCALE TESTS FAILED!"
fi

cleanup