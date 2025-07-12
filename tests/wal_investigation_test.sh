#!/bin/bash

# WAL Investigation Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="wal_test.db"
TEST_PORT=6008

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== WAL Investigation Test ==="
cleanup

# Test WAL record writing during DML operations
echo "Phase 1: Testing WAL record creation..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(10), value int)"
    echo "insert into test values (1, 'Alice', 100)"
    echo "insert into test values (2, 'Bob', 200)"
    echo "update test set value = 150 where id = 1"
    echo "delete from test where id = 2"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > phase1.log

wait $SERVER_PID

echo "=== WAL Records Written ==="
grep "WAL:" server.log

echo ""
echo "=== Auto-commit Messages ==="
grep "auto-committed" server.log

echo ""
echo "=== Phase 1 Results ==="
cat phase1.log

# Test recovery
echo ""
echo "Phase 2: Testing WAL recovery..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > recovery.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovery_result.log

wait $SERVER_PID

echo "=== Recovery Process ==="
grep -E "(REDO|recovery|WAL)" recovery.log

echo ""
echo "=== Recovery Results ==="
cat recovery_result.log

echo ""
echo "=== WAL File Analysis ==="
if [ -f "minidb.wal" ]; then
    echo "WAL file size: $(wc -c < minidb.wal) bytes"
    echo "WAL file exists and contains data"
else
    echo "No WAL file found"
fi

cleanup