#!/bin/bash

# Test WHERE clause fix

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="where_fix.db"
TEST_PORT=7500

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "🔧 Testing WHERE Clause Fix"
echo "==========================="

cleanup

# Build and start server
make -C .. server-debug > /dev/null 2>&1
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "Setting up test data..."
{
    echo "create table employees (id int, name varchar(10), dept varchar(15))"
    echo "insert into employees values (1, 'Alice', 'Engineering')"
    echo "insert into employees values (2, 'Bob', 'Marketing')"
    echo "insert into employees values (3, 'Carol', 'Engineering')"
    echo "create index idx_dept on employees (dept) using btree"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > setup.log 2>&1

echo "✅ Setup completed"

echo ""
echo "Testing WHERE clause queries..."

echo "Test 1: WHERE with string value"
echo "select * from employees where dept = 'Engineering'" | timeout 10 $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test1.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ String WHERE query: SUCCESS"
    grep -c "Alice\|Carol" test1.log > /dev/null && echo "  ✅ Correct results returned"
else
    echo "❌ String WHERE query: FAILED/TIMEOUT"
fi

echo "Test 2: WHERE with integer value"
echo "select * from employees where id = 2" | timeout 10 $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > test2.log 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Integer WHERE query: SUCCESS"
    grep -c "Bob" test2.log > /dev/null && echo "  ✅ Correct results returned"
else
    echo "❌ Integer WHERE query: FAILED/TIMEOUT"
fi

echo ""
echo "Checking optimizer decisions..."
grep -i "optimizer.*chose\|executor.*where" server.log | head -5

echo ""
echo "Sample query results:"
echo "Test 1 results:"
cat test1.log | tail -5
echo ""
echo "Test 2 results:"
cat test2.log | tail -5

# Cleanup
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1
wait $SERVER_PID

cleanup
echo ""
echo "✅ WHERE clause testing completed"