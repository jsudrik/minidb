#!/bin/bash

# Full Recovery Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="full_recovery.db"
TEST_PORT=6012

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Full Recovery Test ==="
cleanup

# Phase 1: Insert multiple records
echo "Phase 1: Insert multiple records..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table products (id int, name varchar(15), price int)"
    echo "insert into products values (1, 'Laptop', 1200)"
    echo "insert into products values (2, 'Mouse', 25)"
    echo "insert into products values (3, 'Keyboard', 75)"
    echo "insert into products values (4, 'Monitor', 300)"
    echo "select * from products"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log

wait $SERVER_PID

echo "=== Original Data (4 records) ==="
grep -A 10 "select \* from products" phase1.log

# Phase 2: Test full recovery
echo ""
echo "Phase 2: Full recovery test..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from products"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2.log

wait $SERVER_PID

echo "=== Recovered Data ==="
cat phase2.log

echo ""
echo "=== Recovery Analysis ==="
echo "Records inserted originally:"
grep "Record inserted successfully" phase1.log | wc -l
echo "REDO operations during recovery:"
grep "REDO: Applied INSERT" server2.log | wc -l
echo "Final record count:"
grep -o "([0-9] row" phase2.log | grep -o "[0-9]"

# Verify all records are recovered
if grep -q "Laptop" phase2.log && grep -q "Mouse" phase2.log && grep -q "Keyboard" phase2.log && grep -q "Monitor" phase2.log; then
    echo ""
    echo "✅ FULL RECOVERY SUCCESS!"
    echo "   All 4 records properly recovered"
else
    echo ""
    echo "❌ PARTIAL RECOVERY - Missing records"
fi

cleanup