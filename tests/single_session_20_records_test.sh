#!/bin/bash

# Single Session 20 Records Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="single_session_20.db"
TEST_PORT=6035

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Single Session 20 Records Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

# Single client session for all operations
{
    echo "create table test (id int, name varchar(20), value int)"
    
    # Insert 20 records in single session
    for ((i=1; i<=20; i++)); do
        echo "insert into test values ($i, 'Name$i', $((i*100)))"
    done
    
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

wait $SERVER_PID

echo ""
echo "=== Analysis ==="
echo "WAL records: $(grep "WAL: Wrote" server1.log | wc -l)"
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Page allocations: $(grep "Allocated new page" server1.log | wc -l)"

cleanup