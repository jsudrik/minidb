#!/bin/bash

# Page Allocation Debug Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="page_debug.db"
TEST_PORT=6031

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Page Allocation Debug ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(20), value int)"
    for ((i=1; i<=30; i++)); do
        echo "insert into test values ($i, 'Name$i', $((i*100)))"
    done
    echo "select * from test where id = 1"
    echo "select * from test where id = 30"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > results.log

wait $SERVER_PID

echo "=== Results ==="
echo "Records inserted: $(grep "Record inserted successfully" results.log | wc -l)"
echo "First record: $(grep "1.*Name1" results.log || echo "MISSING")"
echo "Last record: $(grep "30.*Name30" results.log || echo "MISSING")"

echo ""
echo "=== Server Analysis ==="
echo "Page allocations: $(grep "Allocated new page" server.log | wc -l)"
echo "Page allocation messages:"
grep "Allocated new page" server.log || echo "None"
echo ""
echo "Scan results:"
grep "scan_table:" server.log
echo ""
echo "SCAN page details:"
grep "SCAN:" server.log

cleanup