#!/bin/bash

# MiniDB Durability/Persistence Test
# Tests data recovery after server restart with 50 and 100 rows

set -e

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="durability_test.db"
TEST_PORT=6000

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

test_durability() {
    local row_count=$1
    local test_name="$row_count rows"
    
    echo "=== Testing Durability: $test_name ==="
    
    cleanup
    
    # Start server
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    # Create table and insert data
    {
        echo "create table test_data (id int, name varchar(20), value int)"
        
        # Insert specified number of rows
        for ((i=1; i<=row_count; i++)); do
            echo "insert into test_data values ($i, 'Item$i', $((i*10)))"
        done
        
        echo "select * from test_data where id = 1"
        echo "shutdown"
    } | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > insert_result.log
    
    wait $SERVER_PID
    
    # Verify data was inserted
    if grep -q "Record inserted successfully" insert_result.log && grep -q "Item1" insert_result.log; then
        echo "✅ Data inserted: $test_name"
    else
        echo "❌ FAIL: Data insertion failed for $test_name"
        return 1
    fi
    
    # Restart server for recovery test
    $MINIDB_SERVER $TEST_PORT $TEST_DB > recovery.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    # Verify data recovery
    {
        echo "select * from test_data where id = 1"
        echo "select * from test_data where id = $row_count"
        echo "shutdown"
    } | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovery_result.log
    
    wait $SERVER_PID
    
    # Check recovery results
    if grep -q "Item1" recovery_result.log && grep -q "Item$row_count" recovery_result.log; then
        echo "✅ PASS: $test_name recovered successfully"
        echo "✅ PASS: Data integrity verified for $test_name"
        return 0
    else
        echo "❌ FAIL: $test_name recovery failed"
        echo "Recovery result:"
        cat recovery_result.log
        return 1
    fi
}

# Main test execution
echo "Starting MiniDB Durability Tests..."
echo "=================================="

# Build if needed
if [ ! -f $MINIDB_SERVER ] || [ ! -f $MINIDB_CLIENT ]; then
    echo "Building MiniDB..."
    cd ..
    make all
    cd tests
fi

# Test with 50 rows
if test_durability 50; then
    TEST_50_RESULT="PASS"
else
    TEST_50_RESULT="FAIL"
fi

echo ""

# Test with 100 rows  
if test_durability 100; then
    TEST_100_RESULT="PASS"
else
    TEST_100_RESULT="FAIL"
fi

echo ""
echo "=== DURABILITY TEST SUMMARY ==="
echo "50 rows test:  $TEST_50_RESULT"
echo "100 rows test: $TEST_100_RESULT"

if [ "$TEST_50_RESULT" = "PASS" ] && [ "$TEST_100_RESULT" = "PASS" ]; then
    echo "🎉 ALL DURABILITY TESTS PASSED!"
    cleanup
    exit 0
else
    echo "❌ SOME DURABILITY TESTS FAILED!"
    echo "Check server.log and recovery.log for details"
    cleanup
    exit 1
fi