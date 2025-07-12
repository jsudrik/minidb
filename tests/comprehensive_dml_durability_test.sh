#!/bin/bash

# Comprehensive DML Durability Test
# Tests INSERT, UPDATE, DELETE operations and their persistence

set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="dml_durability_test.db"
TEST_PORT=6002

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

start_server() {
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server.log 2>&1 &
    SERVER_PID=$!
    sleep 2
}

stop_server() {
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1 || true
    wait $SERVER_PID 2>/dev/null || true
}

run_sql() {
    echo "$1" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT
}

echo "=== Comprehensive DML Durability Test ==="
cleanup

# Phase 1: Initial data setup
echo "Phase 1: Setting up initial data..."
start_server

run_sql "create table products (id int, name varchar(20), price int, category varchar(15))" > setup.log
run_sql "insert into products values (1, 'Laptop', 1200, 'Electronics')" >> setup.log
run_sql "insert into products values (2, 'Mouse', 25, 'Electronics')" >> setup.log
run_sql "insert into products values (3, 'Book', 15, 'Education')" >> setup.log
run_sql "insert into products values (4, 'Pen', 2, 'Office')" >> setup.log
run_sql "insert into products values (5, 'Chair', 150, 'Furniture')" >> setup.log

echo "Initial data inserted. Verifying..."
run_sql "select * from products" > initial_data.log

if grep -q "Laptop" initial_data.log && grep -q "Mouse" initial_data.log; then
    echo "✅ Phase 1 PASS: Initial data inserted"
else
    echo "❌ Phase 1 FAIL: Initial data insertion failed"
    cat setup.log
    cleanup
    exit 1
fi

stop_server

# Phase 2: Test INSERT durability
echo "Phase 2: Testing INSERT durability..."
start_server

run_sql "insert into products values (6, 'Tablet', 300, 'Electronics')" > insert_test.log
run_sql "insert into products values (7, 'Desk', 200, 'Furniture')" >> insert_test.log

stop_server
start_server

run_sql "select * from products where id >= 6" > insert_recovery.log

if grep -q "Tablet" insert_recovery.log && grep -q "Desk" insert_recovery.log; then
    echo "✅ Phase 2 PASS: INSERT operations are durable"
else
    echo "❌ Phase 2 FAIL: INSERT durability failed"
    cat insert_recovery.log
    cleanup
    exit 1
fi

# Phase 3: Test UPDATE durability
echo "Phase 3: Testing UPDATE durability..."
run_sql "update products set price = 1100 where id = 1" > update_test.log
run_sql "update products set category = 'Tech' where category = 'Electronics'" >> update_test.log

stop_server
start_server

run_sql "select * from products where id = 1" > update_recovery1.log
run_sql "select * from products where category = 'Tech'" > update_recovery2.log

if grep -q "1100" update_recovery1.log && grep -q "Tech" update_recovery2.log; then
    echo "✅ Phase 3 PASS: UPDATE operations are durable"
else
    echo "❌ Phase 3 FAIL: UPDATE durability failed"
    echo "Update recovery 1:"
    cat update_recovery1.log
    echo "Update recovery 2:"
    cat update_recovery2.log
    cleanup
    exit 1
fi

# Phase 4: Test DELETE durability
echo "Phase 4: Testing DELETE durability..."
run_sql "delete from products where category = 'Office'" > delete_test.log
run_sql "delete from products where price < 20" >> delete_test.log

stop_server
start_server

run_sql "select * from products" > delete_recovery.log

if ! grep -q "Pen" delete_recovery.log && ! grep -q "Book" delete_recovery.log; then
    echo "✅ Phase 4 PASS: DELETE operations are durable"
else
    echo "❌ Phase 4 FAIL: DELETE durability failed"
    echo "Items should be deleted but found:"
    cat delete_recovery.log
    cleanup
    exit 1
fi

# Phase 5: Mixed operations durability
echo "Phase 5: Testing mixed DML operations durability..."
run_sql "insert into products values (8, 'Monitor', 250, 'Tech')" > mixed_test.log
run_sql "update products set price = 280 where id = 8" >> mixed_test.log
run_sql "delete from products where id = 7" >> mixed_test.log

stop_server
start_server

run_sql "select * from products where id = 8" > mixed_recovery1.log
run_sql "select * from products where id = 7" > mixed_recovery2.log

if grep -q "280" mixed_recovery1.log && ! grep -q "Desk" mixed_recovery2.log; then
    echo "✅ Phase 5 PASS: Mixed DML operations are durable"
else
    echo "❌ Phase 5 FAIL: Mixed DML durability failed"
    cleanup
    exit 1
fi

# Final verification
echo "Final verification: Checking complete data state..."
run_sql "select * from products" > final_state.log

stop_server

echo ""
echo "=== FINAL DATA STATE ==="
cat final_state.log

echo ""
echo "=== DML DURABILITY TEST SUMMARY ==="
echo "✅ INSERT durability: PASS"
echo "✅ UPDATE durability: PASS" 
echo "✅ DELETE durability: PASS"
echo "✅ Mixed operations durability: PASS"
echo ""
echo "🎉 ALL DML DURABILITY TESTS PASSED!"

cleanup
exit 0