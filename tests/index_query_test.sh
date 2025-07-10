#!/bin/bash

# MiniDB Index Query Test
# Tests query optimization and execution with B-Tree and Hash indexes

set -e

MINIDB_SERVER="../minidb_server"
MINIDB_CLIENT="../minidb_client"
TEST_DB="index_test.db"
TEST_PORT=6100

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* 2>/dev/null || true
}

echo "=== MiniDB Index Query Test ==="
cleanup

# Start server
$MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
SERVER_PID=$!
sleep 2

# Test Phase 1: Setup data and indexes
echo "Phase 1: Creating table, data, and indexes..."
{
    echo "create table employees (id int, name varchar(20), dept varchar(15), salary int)"
    
    # Insert test data
    echo "insert into employees values (1, 'Alice', 'Engineering', 75000)"
    echo "insert into employees values (2, 'Bob', 'Marketing', 65000)"
    echo "insert into employees values (3, 'Carol', 'Engineering', 80000)"
    echo "insert into employees values (4, 'David', 'Sales', 70000)"
    echo "insert into employees values (5, 'Eve', 'Marketing', 68000)"
    echo "insert into employees values (6, 'Frank', 'Engineering', 85000)"
    
    # Create indexes
    echo "create index idx_dept on employees (dept) using btree"
    echo "create index idx_salary on employees (salary) using hash"
    
    # Verify data insertion
    echo "select * from employees"
    
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > setup_result.log

# Check setup success
if grep -q "Alice" setup_result.log && grep -q "Index.*created" setup_result.log; then
    echo "✅ Phase 1 PASS: Data and indexes created successfully"
else
    echo "❌ Phase 1 FAIL: Setup failed"
    cat setup_result.log
    kill $SERVER_PID
    cleanup
    exit 1
fi

# Test Phase 2: Index-based queries
echo "Phase 2: Testing index-based queries..."
{
    # Test B-Tree index query (dept column)
    echo "select * from employees where dept = 'Engineering'"
    echo "select * from employees where dept = 'Marketing'"
    
    # Test Hash index query (salary column)  
    echo "select * from employees where salary = 75000"
    echo "select * from employees where salary = 65000"
    
    # Test non-indexed column (should use table scan)
    echo "select * from employees where name = 'Alice'"
    
} | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > query_result.log

# Test Phase 3: Verify query results
echo "Phase 3: Verifying query results..."

# Check B-Tree index results
if grep -A5 "dept = 'Engineering'" query_result.log | grep -q "Alice.*Engineering" && \
   grep -A5 "dept = 'Engineering'" query_result.log | grep -q "Carol.*Engineering" && \
   grep -A5 "dept = 'Engineering'" query_result.log | grep -q "Frank.*Engineering"; then
    echo "✅ B-Tree Index Query: PASS (Engineering dept)"
    BTREE_RESULT="PASS"
else
    echo "❌ B-Tree Index Query: FAIL (Engineering dept)"
    BTREE_RESULT="FAIL"
fi

if grep -A5 "dept = 'Marketing'" query_result.log | grep -q "Bob.*Marketing" && \
   grep -A5 "dept = 'Marketing'" query_result.log | grep -q "Eve.*Marketing"; then
    echo "✅ B-Tree Index Query: PASS (Marketing dept)"
    BTREE_RESULT2="PASS"
else
    echo "❌ B-Tree Index Query: FAIL (Marketing dept)"
    BTREE_RESULT2="FAIL"
fi

# Check Hash index results
if grep -A3 "salary = 75000" query_result.log | grep -q "Alice.*75000"; then
    echo "✅ Hash Index Query: PASS (salary 75000)"
    HASH_RESULT="PASS"
else
    echo "❌ Hash Index Query: FAIL (salary 75000)"
    HASH_RESULT="FAIL"
fi

if grep -A3 "salary = 65000" query_result.log | grep -q "Bob.*65000"; then
    echo "✅ Hash Index Query: PASS (salary 65000)"
    HASH_RESULT2="PASS"
else
    echo "❌ Hash Index Query: FAIL (salary 65000)"
    HASH_RESULT2="FAIL"
fi

# Check table scan (non-indexed)
if grep -A3 "name = 'Alice'" query_result.log | grep -q "Alice.*Engineering"; then
    echo "✅ Table Scan Query: PASS (name Alice)"
    SCAN_RESULT="PASS"
else
    echo "❌ Table Scan Query: FAIL (name Alice)"
    SCAN_RESULT="FAIL"
fi

# Shutdown server
echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null
wait $SERVER_PID

echo ""
echo "=== INDEX QUERY TEST SUMMARY ==="
echo "B-Tree Index (Engineering): $BTREE_RESULT"
echo "B-Tree Index (Marketing):   $BTREE_RESULT2"
echo "Hash Index (75000):         $HASH_RESULT"
echo "Hash Index (65000):         $HASH_RESULT2"
echo "Table Scan (Alice):         $SCAN_RESULT"

# Check for optimizer messages in server log
echo ""
echo "=== QUERY OPTIMIZER ANALYSIS ==="
if grep -q "optimizer\|index.*scan\|table.*scan" server.log; then
    echo "Optimizer decisions:"
    grep -i "optimizer\|index.*scan\|table.*scan" server.log || echo "No optimizer messages found"
else
    echo "⚠️  No optimizer debug messages found in server log"
fi

# Overall result
if [ "$BTREE_RESULT" = "PASS" ] && [ "$BTREE_RESULT2" = "PASS" ] && \
   [ "$HASH_RESULT" = "PASS" ] && [ "$HASH_RESULT2" = "PASS" ] && \
   [ "$SCAN_RESULT" = "PASS" ]; then
    echo ""
    echo "🎉 ALL INDEX QUERY TESTS PASSED!"
    echo "✅ B-Tree indexes working correctly"
    echo "✅ Hash indexes working correctly"
    echo "✅ Table scans working correctly"
    cleanup
    exit 0
else
    echo ""
    echo "❌ SOME INDEX QUERY TESTS FAILED!"
    echo "Check query_result.log and server.log for details"
    echo ""
    echo "Query Results:"
    cat query_result.log
    cleanup
    exit 1
fi