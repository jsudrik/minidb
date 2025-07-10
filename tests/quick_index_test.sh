#!/bin/bash

# Quick Index Test

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="quick_index.db"
TEST_PORT=6300

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "=== Quick Index Test ==="
cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 3

# Test queries
{
    echo 'create table emp (id int, dept varchar(10))'
    echo 'insert into emp values (1, "Engineering")'
    echo 'insert into emp values (2, "Marketing")'
    echo 'create index idx_dept on emp (dept) using btree'
    echo 'select * from emp'
    echo 'select * from emp where dept = "Engineering"'
    echo 'shutdown'
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > client.log 2>&1

# Wait for completion
wait $SERVER_PID

echo "=== Results ==="
echo "Client output:"
cat client.log | tail -20

echo ""
echo "Optimizer messages:"
grep "OPTIMIZER" server.log || echo "No optimizer messages"

echo ""
echo "WHERE parsing:"
grep "WHERE" server.log || echo "No WHERE messages"

cleanup