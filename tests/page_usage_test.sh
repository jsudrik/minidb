#!/bin/bash

# Page Usage Investigation Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="page_usage.db"
TEST_PORT=6018

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Page Usage Investigation ==="
cleanup

# Test with 50 records
echo "Testing 50 records..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(20), value int)"
    for ((i=1; i<=50; i++)); do
        echo "insert into test values ($i, 'Record$i', $((i*100)))"
    done
    echo "select count(*) from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > results.log

wait $SERVER_PID

echo "=== Results ==="
cat results.log | grep -A 5 "count"

echo ""
echo "=== Server Log Analysis ==="
echo "Page allocations during insertion:"
grep -i "allocated.*page" server.log || echo "No additional pages allocated"
echo ""
echo "Total INSERT operations:"
grep "Record inserted successfully" results.log | wc -l

cleanup