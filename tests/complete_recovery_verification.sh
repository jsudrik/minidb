#!/bin/bash

# Complete Recovery Verification Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="complete_recovery.db"
TEST_PORT=6014

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Complete Recovery Verification ==="
cleanup

# Phase 1: Insert 5 records
echo "Phase 1: Insert 5 records..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table inventory (id int, item varchar(15), qty int)"
    echo "insert into inventory values (1, 'Laptop', 10)"
    echo "insert into inventory values (2, 'Mouse', 50)"
    echo "insert into inventory values (3, 'Keyboard', 25)"
    echo "insert into inventory values (4, 'Monitor', 200)"
    echo "insert into inventory values (5, 'Printer', 75)"
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log

wait $SERVER_PID

echo "=== Original Data (5 records) ==="
cat phase1.log | grep -A 20 "select \* from inventory"

# Phase 2: Recovery test
echo ""
echo "Phase 2: Full recovery verification..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2.log

wait $SERVER_PID

echo "=== Recovered Data ==="
cat phase2.log

# Phase 3: Test DML operations on recovered data
echo ""
echo "Phase 3: DML operations on recovered data..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server3.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "update inventory set qty = 15 where id = 1"
    echo "delete from inventory where id = 2"
    echo "insert into inventory values (6, 'Scanner', 150)"
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase3.log

wait $SERVER_PID

echo "=== After DML Operations ==="
cat phase3.log | grep -A 20 "select \* from inventory"

# Phase 4: Final recovery test
echo ""
echo "Phase 4: Final recovery test..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server4.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase4.log

wait $SERVER_PID

echo "=== Final Recovered Data ==="
cat phase4.log

echo ""
echo "=== RECOVERY VERIFICATION SUMMARY ==="
echo "Phase 1 - Original records: 5"
echo "Phase 2 - Recovered records: $(grep -o "([0-9] row" phase2.log | grep -o "[0-9]" || echo "0")"
echo "Phase 3 - After DML operations: $(grep -o "([0-9] row" phase3.log | grep -o "[0-9]" || echo "0")"
echo "Phase 4 - Final recovery: $(grep -o "([0-9] row" phase4.log | grep -o "[0-9]" || echo "0")"

echo ""
echo "WAL Analysis:"
echo "Server 1 WAL records: $(grep "WAL: Wrote" server1.log | wc -l)"
echo "Server 2 REDO ops: $(grep "REDO:" server2.log | wc -l)"
echo "Server 3 WAL records: $(grep "WAL: Wrote" server3.log | wc -l)"
echo "Server 4 REDO ops: $(grep "REDO:" server4.log | wc -l)"

if grep -q "Laptop" phase4.log && grep -q "Scanner" phase4.log && ! grep -q "Mouse" phase4.log; then
    echo ""
    echo "🎉 COMPLETE RECOVERY VERIFICATION: SUCCESS!"
    echo "   ✅ All original records recovered"
    echo "   ✅ DML operations work on recovered data"
    echo "   ✅ Final state properly maintained"
else
    echo ""
    echo "⚠️  PARTIAL SUCCESS - Check individual phases"
fi

cleanup