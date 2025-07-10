#!/bin/bash

# Simple MiniDB Durability Test
# Tests basic data recovery after server restart

set -e

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="simple_durability.db"
TEST_PORT=6001

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "=== Simple Durability Test ==="
cleanup

# Phase 1: Insert data
echo "Phase 1: Inserting test data..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table products (id int, name varchar(10))"
    echo "insert into products values (1, 'Laptop')"
    echo "insert into products values (2, 'Mouse')"
    echo "insert into products values (3, 'Keyboard')"
    echo "select * from products"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > insert_phase.log

wait $SERVER_PID

# Verify insertion
if grep -q "Laptop" insert_phase.log && grep -q "Mouse" insert_phase.log && grep -q "Keyboard" insert_phase.log; then
    echo "✅ Phase 1 PASS: Data inserted successfully"
else
    echo "❌ Phase 1 FAIL: Data insertion failed"
    cat insert_phase.log
    cleanup
    exit 1
fi

# Phase 2: Recovery test
echo "Phase 2: Testing data recovery..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from products"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovery_phase.log

wait $SERVER_PID

# Verify recovery
if grep -q "Laptop" recovery_phase.log && grep -q "Mouse" recovery_phase.log && grep -q "Keyboard" recovery_phase.log; then
    echo "✅ Phase 2 PASS: Data recovered successfully"
    echo "✅ DURABILITY TEST PASSED!"
    
    # Show recovery stats
    echo ""
    echo "Recovery Log Summary:"
    grep "REDO:" server2.log || echo "No REDO operations found"
    grep "recovery completed" server2.log || echo "No recovery summary found"
    
    cleanup
    exit 0
else
    echo "❌ Phase 2 FAIL: Data recovery failed"
    echo "Recovery result:"
    cat recovery_phase.log
    echo ""
    echo "Server recovery log:"
    cat server2.log
    cleanup
    exit 1
fi