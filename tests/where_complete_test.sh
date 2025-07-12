#!/bin/bash

# Complete WHERE clause test

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="where_complete.db"
TEST_PORT=8100

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "🎯 Complete WHERE Clause Test"
echo "============================="

cleanup

# Build and start server
make -C .. clean > /dev/null 2>&1
make -C .. debug > /dev/null 2>&1

$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "Setting up test data..."
{
    echo "create table employees (id int, name varchar(10), dept varchar(15))"
    echo "insert into employees values (1, 'Alice', 'Engineering')"
    echo "insert into employees values (2, 'Bob', 'Marketing')"
    echo "insert into employees values (3, 'Carol', 'Engineering')"
    echo "insert into employees values (4, 'Dave', 'Sales')"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > setup.log 2>&1

echo "✅ Setup completed"

echo ""
echo "Testing WHERE clause functionality..."

echo "Test 1: SELECT with WHERE"
echo "select * from employees where dept = 'Engineering'" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > select_test.log 2>&1 &
sleep 2
pkill -f "minidb_client.*$TEST_PORT" 2>/dev/null

if grep -q "Alice\|Carol" select_test.log 2>/dev/null; then
    echo "✅ SELECT WHERE: SUCCESS"
else
    echo "❌ SELECT WHERE: FAILED"
fi

echo "Test 2: UPDATE with WHERE"
echo "update employees set name = 'Updated' where id = 2" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > update_test.log 2>&1 &
sleep 2
pkill -f "minidb_client.*$TEST_PORT" 2>/dev/null

if grep -q "updated" update_test.log 2>/dev/null; then
    echo "✅ UPDATE WHERE: SUCCESS"
else
    echo "❌ UPDATE WHERE: FAILED"
fi

echo "Test 3: DELETE with WHERE"
echo "delete from employees where dept = 'Sales'" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > delete_test.log 2>&1 &
sleep 2
pkill -f "minidb_client.*$TEST_PORT" 2>/dev/null

if grep -q "deleted" delete_test.log 2>/dev/null; then
    echo "✅ DELETE WHERE: SUCCESS"
else
    echo "❌ DELETE WHERE: FAILED"
fi

echo ""
echo "Sample results:"
echo "SELECT result:"
head -5 select_test.log 2>/dev/null || echo "No result"

echo ""
echo "UPDATE result:"
head -3 update_test.log 2>/dev/null || echo "No result"

echo ""
echo "DELETE result:"
head -3 delete_test.log 2>/dev/null || echo "No result"

# Cleanup
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1
wait $SERVER_PID 2>/dev/null

cleanup
echo ""
echo "✅ WHERE clause testing completed"