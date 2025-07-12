#!/bin/bash

# Complete DML Durability Test
set -e

MINIDB_SERVER="../server/minidb_server"
MINIDB_CLIENT="../client/minidb_client"
TEST_DB="complete_dml.db"
TEST_PORT=6006

cleanup() {
    pkill -f "minidb_server $TEST_PORT" 2>/dev/null || true
    rm -f $TEST_DB* minidb.wal* *.log 2>/dev/null || true
}

run_test() {
    local test_name="$1"
    local sql_commands="$2"
    local expected_pattern="$3"
    
    echo "=== $test_name ==="
    
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server_${test_name// /_}.log 2>&1 &
    SERVER_PID=$!
    sleep 2
    
    echo "$sql_commands" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > ${test_name// /_}.log
    
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1 || true
    wait $SERVER_PID 2>/dev/null || true
    
    # Restart server for durability check
    $MINIDB_SERVER $TEST_PORT $TEST_DB > server_${test_name// /_}_recovery.log 2>&1 &
    SERVER_PID=$!
    sleep 3
    
    echo "select * from inventory" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > ${test_name// /_}_recovery.log
    
    echo "shutdown" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > /dev/null 2>&1 || true
    wait $SERVER_PID 2>/dev/null || true
    
    if grep -q "$expected_pattern" ${test_name// /_}_recovery.log; then
        echo "✅ $test_name: PASS"
        return 0
    else
        echo "❌ $test_name: FAIL"
        echo "Expected: $expected_pattern"
        echo "Got:"
        cat ${test_name// /_}_recovery.log
        return 1
    fi
}

echo "=== Complete DML Durability Test Suite ==="
cleanup

# Test 1: Initial setup and INSERT durability
SETUP_SQL="create table inventory (id int, item varchar(15), qty int)
insert into inventory values (1, 'Laptop', 10)
insert into inventory values (2, 'Mouse', 50)
insert into inventory values (3, 'Keyboard', 25)"

if run_test "INSERT Durability" "$SETUP_SQL" "Laptop"; then
    INSERT_RESULT="PASS"
else
    INSERT_RESULT="FAIL"
fi

# Test 2: UPDATE durability
UPDATE_SQL="update inventory set qty = 15 where id = 1"

if run_test "UPDATE Durability" "$UPDATE_SQL" "15"; then
    UPDATE_RESULT="PASS"
else
    UPDATE_RESULT="FAIL"
fi

# Test 3: DELETE durability
DELETE_SQL="delete from inventory where id = 3"

if run_test "DELETE Durability" "$DELETE_SQL" "Laptop"; then
    # Check that Keyboard is NOT present
    if ! grep -q "Keyboard" DELETE_Durability_recovery.log; then
        DELETE_RESULT="PASS"
    else
        DELETE_RESULT="FAIL - Keyboard still present"
    fi
else
    DELETE_RESULT="FAIL"
fi

# Test 4: Mixed operations durability
MIXED_SQL="insert into inventory values (4, 'Monitor', 8)
update inventory set qty = 12 where id = 1
delete from inventory where id = 2"

if run_test "Mixed Operations" "$MIXED_SQL" "Monitor"; then
    # Check complex conditions
    if grep -q "12" Mixed_Operations_recovery.log && ! grep -q "Mouse" Mixed_Operations_recovery.log; then
        MIXED_RESULT="PASS"
    else
        MIXED_RESULT="FAIL - Complex conditions not met"
    fi
else
    MIXED_RESULT="FAIL"
fi

echo ""
echo "=== FINAL TEST RESULTS ==="
echo "INSERT durability: $INSERT_RESULT"
echo "UPDATE durability: $UPDATE_RESULT"
echo "DELETE durability: $DELETE_RESULT"
echo "Mixed operations: $MIXED_RESULT"

echo ""
echo "=== FINAL DATABASE STATE ==="
cat Mixed_Operations_recovery.log

if [ "$INSERT_RESULT" = "PASS" ] && [ "$UPDATE_RESULT" = "PASS" ] && [ "$DELETE_RESULT" = "PASS" ] && [ "$MIXED_RESULT" = "PASS" ]; then
    echo ""
    echo "🎉 ALL DML DURABILITY TESTS PASSED!"
    cleanup
    exit 0
else
    echo ""
    echo "❌ SOME TESTS FAILED!"
    echo "Check individual test logs for details"
    exit 1
fi