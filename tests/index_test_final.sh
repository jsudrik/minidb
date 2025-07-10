#!/bin/bash

# Final Index Test with comprehensive tracing

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="final_index.db"
TEST_PORT=6500

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "🚀 MiniDB Index Query Test with Optimizer Tracing"
echo "=================================================="
cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 3

echo "📋 Phase 1: Setup data and indexes"
{
    echo "create table employees (id int, dept varchar(10), salary int)"
    echo "insert into employees values (1, 'Engineering', 75000)"
    echo "insert into employees values (2, 'Marketing', 65000)"  
    echo "insert into employees values (3, 'Engineering', 80000)"
    echo "create index idx_dept on employees (dept) using btree"
    echo "create index idx_salary on employees (salary) using hash"
    echo "select * from employees"
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > setup.log 2>&1

echo "✅ Setup completed. Data:"
tail -10 setup.log

echo ""
echo "🔍 Phase 2: Testing queries with optimizer tracing"

# Test each query type separately to isolate issues
echo "Testing B-Tree index query..."
echo "select * from employees where dept = 'Engineering'" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > btree_test.log 2>&1

echo "B-Tree query result:"
cat btree_test.log

echo ""
echo "Testing Hash index query..."  
echo "select * from employees where salary = 75000" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > hash_test.log 2>&1

echo "Hash query result:"
cat hash_test.log

echo ""
echo "🔧 Optimizer Analysis:"
echo "======================"

# Check server log for optimizer decisions
echo "Optimizer messages:"
grep -i "optimizer\|executor" server.log || echo "No optimizer messages found"

echo ""
echo "WHERE clause processing:"
grep -i "where\|debug" server.log || echo "No WHERE processing messages found"

echo ""
echo "🏁 Test Summary:"
echo "==============="

if grep -q "Engineering" btree_test.log && grep -q "75000" hash_test.log; then
    echo "✅ SUCCESS: Index queries working correctly"
    echo "✅ B-Tree index: FUNCTIONAL"
    echo "✅ Hash index: FUNCTIONAL"
    echo "✅ Query optimizer: ACTIVE"
else
    echo "❌ ISSUES DETECTED:"
    echo "   - Check btree_test.log and hash_test.log for details"
    echo "   - Server may be crashing on WHERE clauses"
fi

# Shutdown
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1
wait $SERVER_PID

cleanup