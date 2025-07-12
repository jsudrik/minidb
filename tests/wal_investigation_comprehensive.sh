#!/bin/bash

# Comprehensive WAL Investigation Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="wal_comprehensive.db"
TEST_PORT=6020

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

test_wal_comprehensive() {
    local count=$1
    echo "=== WAL Investigation: $count Records ==="
    cleanup
    
    # Phase 1: Insert records with detailed WAL tracking
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    echo "create table test (id int, name varchar(50), description varchar(100), value int)" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    echo "Inserting $count records..."
    for ((i=1; i<=count; i++)); do
        echo "insert into test values ($i, 'Name$i', 'Description for record number $i with more text', $((i*100)))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null
        if [ $((i % 25)) -eq 0 ]; then
            echo "Inserted $i records..."
        fi
    done
    
    # Check original data
    echo "select * from test where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > original_first.log
    echo "select * from test where id = $count" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > original_last.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo "=== WAL Analysis Phase 1 ==="
    echo "WAL records written:"
    grep "WAL: Wrote" server1.log | wc -l
    echo "Auto-commits performed:"
    grep "auto-committed" server1.log | wc -l
    echo "Page allocations:"
    grep "Allocated new page" server1.log | wc -l
    echo "Page usage:"
    grep "SCAN:" server1.log | tail -n 2
    
    echo "Original data verification:"
    echo "First: $(grep "Name1" original_first.log || echo "MISSING")"
    echo "Last:  $(grep "Name$count" original_last.log || echo "MISSING")"
    
    # Phase 2: Recovery with detailed tracking
    echo ""
    echo "=== Recovery Phase ==="
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    echo "select * from test where id = 1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_first.log
    echo "select * from test where id = $count" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovered_last.log
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
    
    wait $SERVER_PID
    
    echo "=== Recovery Analysis ==="
    echo "REDO operations:"
    grep "REDO: Applied INSERT" server2.log | wc -l
    echo "Page clearing:"
    grep "CLEARED page" server2.log
    echo "Recovery record size:"
    grep "Setting recovery record size" server2.log
    echo "Page usage after recovery:"
    grep "SCAN:" server2.log | tail -n 2
    
    echo "Recovered data verification:"
    echo "First: $(grep "Name1" recovered_first.log || echo "MISSING")"
    echo "Last:  $(grep "Name$count" recovered_last.log || echo "MISSING")"
    
    # Detailed WAL analysis
    echo ""
    echo "=== Detailed WAL Analysis ==="
    echo "WAL file size:"
    ls -la minidb.wal 2>/dev/null || echo "No WAL file found"
    
    if grep -q "Name1" recovered_first.log && grep -q "Name$count" recovered_last.log; then
        echo "✅ $count records: COMPLETE SUCCESS"
        return 0
    else
        echo "❌ $count records: RECOVERY FAILED"
        echo "Debug info:"
        echo "Server2 log tail:"
        tail -n 10 server2.log
        return 1
    fi
}

echo "=== Comprehensive WAL Investigation ==="

# Test with larger records to force multi-page usage
# Test 200 records (should definitely require multiple pages)
if test_wal_comprehensive 200; then
    RESULT_200="PASS"
else
    RESULT_200="FAIL"
fi

echo ""
echo "=== FINAL ANALYSIS ==="
echo "200 records: $RESULT_200"

cleanup