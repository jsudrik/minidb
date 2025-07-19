#!/bin/bash

# Script to generate expected output for new tests

MINIDB_SERVER="../../server/minidb_server"
MINIDB_CLIENT="../../client/minidb_client"
TEST_PORT=7777

# Function to run a test and generate expected output
run_test() {
    local test_dir=$1
    local test_sql="$test_dir/test.sql"
    local output="$test_dir/run.out"
    local expected="$test_dir/expected.out"
    
    echo "Running test: $test_dir"
    
    # Clean up any previous test data
    rm -f "$test_dir/test.db"* "$test_dir/minidb.wal"* "$output"
    
    # Start server
    $MINIDB_SERVER $TEST_PORT "$test_dir/test.db" > "$test_dir/server.log" 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 1
    
    # Run test
    cat "$test_sql" | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > "$output" 2>&1
    
    # Shutdown server
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    
    # Copy output to expected
    cp "$output" "$expected"
    
    echo "Generated expected output for: $test_dir"
}

# Run the new tests
run_test "queries/select_specific_columns"
run_test "queries/select_operators"
run_test "dml/update_operators"
run_test "dml/delete_operators"

echo "All test outputs generated!"
