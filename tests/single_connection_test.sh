#!/bin/bash

# Single Connection Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="single_connection.db"
TEST_PORT=6023

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Single Connection Test ==="
cleanup

$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

# Use single client connection for all operations
{
    echo "create table test (id int, name varchar(50), description varchar(100), value int)"
    
    # Insert 100 records in single connection
    for ((i=1; i<=100; i++)); do
        echo "insert into test values ($i, 'Name$i', 'Description for record $i', $((i*100)))"
    done
    
    echo "select * from test where id = 1"
    echo "select * from test where id = 50"
    echo "select * from test where id = 100"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > results.log

wait $SERVER_PID

echo "=== Results Analysis ==="
echo "Insert confirmations:"
grep "Record inserted successfully" results.log | wc -l

echo ""
echo "First record:"
grep -A 3 "select \* from test where id = 1" results.log | tail -n 2

echo ""
echo "50th record:"
grep -A 3 "select \* from test where id = 50" results.log | tail -n 2

echo ""
echo "100th record:"
grep -A 3 "select \* from test where id = 100" results.log | tail -n 2

echo ""
echo "Total records in select all:"
grep -A 200 "select \* from test$" results.log | grep -c "Name" || echo "0"

echo ""
echo "=== Server Analysis ==="
echo "WAL records:"
grep "WAL: Wrote" server1.log | wc -l
echo "Auto-commits:"
grep "auto-committed" server1.log | wc -l
echo "Page allocations:"
grep "Allocated new page" server1.log | wc -l
echo "Scan results:"
grep "scan_table:" server1.log

echo ""
echo "=== Recovery Test ==="
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

{
    echo "select * from test where id = 1"
    echo "select * from test where id = 100"
    echo "select * from test"
    echo "shutdown"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > recovery_results.log

wait $SERVER_PID

echo "Recovery - First record:"
grep -A 3 "select \* from test where id = 1" recovery_results.log | tail -n 2

echo ""
echo "Recovery - 100th record:"
grep -A 3 "select \* from test where id = 100" recovery_results.log | tail -n 2

echo ""
echo "Recovery - Total records:"
grep -A 200 "select \* from test$" recovery_results.log | grep -c "Name" || echo "0"

echo ""
echo "Recovery analysis:"
grep "REDO:" server2.log | wc -l | xargs echo "REDO operations:"
grep "scan_table:" server2.log

cleanup