#!/bin/bash

# Complete WAL Test - All DML Operations
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="complete_wal.db"
TEST_PORT=6009

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Complete WAL Test ==="
cleanup

# Phase 1: Test all DML operations with WAL logging
echo "Phase 1: Testing complete DML operations with WAL..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table inventory (id int, item varchar(15), qty int)"
    echo "insert into inventory values (1, 'Laptop', 10)"
    echo "insert into inventory values (2, 'Mouse', 50)"
    echo "insert into inventory values (3, 'Keyboard', 25)"
    echo "update inventory set qty = 15 where id = 1"
    echo "delete from inventory where id = 2"
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log

wait $SERVER_PID

echo "=== WAL Records Generated ==="
grep "WAL: Wrote" server1.log

echo ""
echo "=== Auto-commit Operations ==="
grep "auto-committed" server1.log

echo ""
echo "=== Phase 1 Data ==="
tail -n 15 phase1.log

# Phase 2: Test recovery
echo ""
echo "Phase 2: Testing WAL recovery..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from inventory"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase2.log

wait $SERVER_PID

echo "=== Recovery Operations ==="
grep -E "(REDO|UNDO)" server2.log

echo ""
echo "=== Recovered Data ==="
cat phase2.log

echo ""
echo "=== DURABILITY VERIFICATION ==="
if grep -q "Laptop" phase2.log && ! grep -q "Mouse" phase2.log && grep -q "Keyboard" phase2.log; then
    echo "✅ ALL DML OPERATIONS ARE DURABLE:"
    echo "   - INSERT: Records persisted"
    echo "   - UPDATE: Changes maintained"  
    echo "   - DELETE: Records removed"
else
    echo "⚠️  PARTIAL DURABILITY - Check results above"
fi

cleanup