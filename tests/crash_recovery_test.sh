#!/bin/bash

# MiniDB Crash Recovery Test
echo "Starting MiniDB Crash Recovery Test..."

# Clean up any existing test files
rm -f crash_test.db crash_test.db.wal

echo "Test 1: Normal operation with WAL logging"
./minidb_server 5436 crash_test.db &
SERVER_PID=$!
sleep 2

# Create table and insert data
echo "CREATE TABLE crash_test (id INT, name VARCHAR(50))" | timeout 5 ./minidb_client 127.0.0.1 5436
echo "INSERT INTO crash_test VALUES ('1', 'Before Crash')" | timeout 5 ./minidb_client 127.0.0.1 5436
echo "INSERT INTO crash_test VALUES ('2', 'Also Before Crash')" | timeout 5 ./minidb_client 127.0.0.1 5436

echo "Data before crash:"
echo "SELECT * FROM crash_test" | timeout 5 ./minidb_client 127.0.0.1 5436

echo ""
echo "Test 2: Simulating crash (killing server without clean shutdown)"
kill -9 $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Server crashed. WAL file should contain transaction logs."
ls -la crash_test.db*

echo ""
echo "Test 3: Recovery after crash"
echo "Restarting server - should perform crash recovery..."
./minidb_server 5436 crash_test.db &
SERVER_PID=$!
sleep 3

echo "Data after recovery:"
echo "SELECT * FROM crash_test" | timeout 5 ./minidb_client 127.0.0.1 5436

echo ""
echo "Test 4: Testing transaction rollback recovery"
echo "Starting uncommitted transaction..."
echo "INSERT INTO crash_test VALUES ('3', 'Uncommitted Data')" | timeout 5 ./minidb_client 127.0.0.1 5436

# Kill server before commit
kill -9 $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Server crashed with uncommitted transaction."

echo ""
echo "Test 5: Recovery should rollback uncommitted transaction"
./minidb_server 5436 crash_test.db &
SERVER_PID=$!
sleep 3

echo "Data after rollback recovery (should not show uncommitted data):"
echo "SELECT * FROM crash_test" | timeout 5 ./minidb_client 127.0.0.1 5436

echo ""
echo "Test 6: Testing committed transaction durability"
echo "INSERT INTO crash_test VALUES ('4', 'Committed Data')" | timeout 5 ./minidb_client 127.0.0.1 5436
echo "COMMIT" | timeout 5 ./minidb_client 127.0.0.1 5436

# Kill server after commit
kill -9 $SERVER_PID
wait $SERVER_PID 2>/dev/null

echo "Server crashed after commit."

echo ""
echo "Test 7: Recovery should preserve committed data"
./minidb_server 5436 crash_test.db &
SERVER_PID=$!
sleep 3

echo "Final data after recovery (should show committed data):"
echo "SELECT * FROM crash_test" | timeout 5 ./minidb_client 127.0.0.1 5436

# Clean shutdown
echo "QUIT" | timeout 5 ./minidb_client 127.0.0.1 5436
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "Crash recovery test completed!"
echo "WAL file size:"
ls -la crash_test.db.wal

# Cleanup
rm -f crash_test.db crash_test.db.wal

echo "Test files cleaned up."