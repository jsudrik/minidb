#!/bin/bash

# Special test script for crash recovery
MINIDB_SERVER="../../../server/minidb_server"
MINIDB_CLIENT="../../../client/minidb_client"
TEST_PORT=7100
DB_FILE="test.db"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running crash recovery test${NC}"

# Clean up any previous test data
rm -f "$DB_FILE" "$DB_FILE-*" minidb.wal*

# Step 1: Start server and create data
$MINIDB_SERVER $TEST_PORT "$DB_FILE" > server1.log 2>&1 &
SERVER_PID=$!
sleep 1

# Run initial setup
cat test.sql | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > output.out 2>&1

# Step 2: Simulate crash by killing server
kill -9 $SERVER_PID
echo -e "${YELLOW}Simulated server crash${NC}"
sleep 1

# Step 3: Restart server (should recover from WAL)
$MINIDB_SERVER $TEST_PORT "$DB_FILE" > server2.log 2>&1 &
SERVER_PID=$!
sleep 1

# Step 4: Verify data is recovered
cat verify.sql | $MINIDB_CLIENT 127.0.0.1 $TEST_PORT > verify_output.out 2>&1

# Step 5: Shutdown server
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

# Compare output with expected
if diff -w verify_output.out verify_expected.out > /dev/null; then
    echo -e "${GREEN}✓ Recovery test passed${NC}"
    exit 0
else
    echo -e "${RED}✗ Recovery test failed${NC}"
    echo -e "${YELLOW}Differences:${NC}"
    diff -w verify_output.out verify_expected.out
    exit 1
fi