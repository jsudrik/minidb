#!/bin/bash

# Focused DML Durability Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="focused_durability.db"
TEST_PORT=6004

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Focused DML Durability Test ==="
cleanup

# Phase 1: Insert data and shutdown
echo "Phase 1: Inserting data..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table inventory (id int, item varchar(15), qty int)"
    echo "insert into inventory values (1, 'Laptop', 10)"
    echo "insert into inventory values (2, 'Mouse', 50)"
    echo "insert into inventory values (3, 'Keyboard', 25)"
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log

wait $SERVER_PID

if grep -q "Laptop" phase1.log && grep -q "Mouse" phase1.log; then
    echo "✅ Phase 1 PASS: Data inserted successfully"
else
    echo "❌ Phase 1 FAIL: Data insertion failed"
    cat phase1.log
    cleanup
    exit 1
fi

# Phase 2: Restart and verify persistence
echo "Phase 2: Testing data persistence after restart..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2.log

wait $SERVER_PID

if grep -q "Laptop" phase2.log && grep -q "Mouse" phase2.log && grep -q "Keyboard" phase2.log; then
    echo "✅ Phase 2 PASS: Data persisted after restart"
else
    echo "❌ Phase 2 FAIL: Data not persisted"
    echo "Recovery result:"
    cat phase2.log
    cleanup
    exit 1
fi

# Phase 3: Test UPDATE durability
echo "Phase 3: Testing UPDATE durability..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server3.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "update inventory set qty = 15 where id = 1"
    echo "select * from inventory where id = 1"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase3.log

wait $SERVER_PID

# Restart and check UPDATE persistence
$MINIDB_SERVER $TEST_PORT $TEST_DB > server4.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "select * from inventory where id = 1"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase3_verify.log

wait $SERVER_PID

if grep -q "15" phase3_verify.log; then
    echo "✅ Phase 3 PASS: UPDATE operation is durable"
else
    echo "❌ Phase 3 FAIL: UPDATE not persisted"
    cat phase3_verify.log
    cleanup
    exit 1
fi

# Phase 4: Test DELETE durability
echo "Phase 4: Testing DELETE durability..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server5.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "delete from inventory where id = 3"
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase4.log

wait $SERVER_PID

# Restart and check DELETE persistence
$MINIDB_SERVER $TEST_PORT $TEST_DB > server6.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase4_verify.log

wait $SERVER_PID

if ! grep -q "Keyboard" phase4_verify.log && grep -q "Laptop" phase4_verify.log; then
    echo "✅ Phase 4 PASS: DELETE operation is durable"
else
    echo "❌ Phase 4 FAIL: DELETE not persisted correctly"
    cat phase4_verify.log
    cleanup
    exit 1
fi

echo ""
echo "=== FINAL STATE ==="
cat phase4_verify.log

echo ""
echo "=== DML DURABILITY TEST RESULTS ==="
echo "✅ INSERT durability: PASS"
echo "✅ UPDATE durability: PASS"
echo "✅ DELETE durability: PASS"
echo ""
echo "🎉 ALL DML DURABILITY TESTS PASSED!"

cleanup
exit 0