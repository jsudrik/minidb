#!/bin/bash

# Display Records Test - Show SELECT output on screen
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="display_records.db"
TEST_PORT=6029

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

echo "=== Display Records Test ==="
cleanup

echo "Starting server..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server1.log 2>&1 &
SERVER_PID=$!
sleep 2

echo ""
echo "Creating table and inserting 10 records..."
echo "create table test (id int, name varchar(10))" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

for i in {1..10}; do
    echo "insert into test values ($i, 'Name$i')" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null
    echo "Inserted record $i"
done

echo ""
echo "=== SELECT OUTPUT BEFORE RECOVERY ==="
echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

echo ""
echo "Shutting down server..."
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
wait $SERVER_PID

echo ""
echo "=== RECOVERY PHASE ==="
echo "Restarting server for recovery..."
$MINIDB_SERVER $TEST_PORT $TEST_DB > server2.log 2>&1 &
SERVER_PID=$!
sleep 3

echo ""
echo "=== SELECT OUTPUT AFTER RECOVERY ==="
echo "select * from test" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT

echo ""
echo "Shutting down..."
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
wait $SERVER_PID

echo ""
echo "=== ANALYSIS ==="
echo "WAL records written: $(grep "WAL: Wrote" server1.log | wc -l)"
echo "REDO operations: $(grep "REDO:" server2.log | wc -l)"
echo "Recovery record size: $(grep "Setting recovery record size" server2.log)"

cleanup