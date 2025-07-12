#!/bin/bash

# Page Usage Investigation
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="page_investigation.db"
TEST_PORT=6037

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Page Usage Investigation ==="
echo "Expected: ~30 bytes per record, ~136 records per page, 200 records = ~2 pages"
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

{
    echo "create table test (id int, name varchar(20), value int)"
    
    # Insert just 10 records first
    for ((i=1; i<=10; i++)); do
        echo "insert into test values ($i, 'Name$i', $((i*100)))"
    done
    
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > results.log

wait $SERVER_PID

echo "=== Results for 10 Records ==="
echo "Records inserted: $(grep "Record inserted successfully" results.log | wc -l)"
echo "Page allocations: $(grep "Allocated new page" server.log | wc -l)"
echo "Page allocation messages:"
grep "Allocated new page" server.log | head -n 5

echo ""
echo "=== Server Log Analysis ==="
echo "INSERT operations in log:"
grep "INSERT:" server.log | wc -l
echo "Page full messages:"
grep -i "page.*full\|full.*page" server.log | head -n 3

echo ""
echo "=== Record Size Analysis ==="
echo "Scan results:"
grep "scan_table:" server.log

cleanup