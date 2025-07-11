#!/bin/bash

# Test both multi-process and multi-threaded modes

echo "🔧 Testing MiniDB Server Modes"
echo "==============================="

# Test multi-process mode
echo "Building multi-process server..."
make -C .. server-debug > /dev/null 2>&1

echo "Starting multi-process server..."
../server/minidb_server 8000 test_mp.db > mp_server.log 2>&1 &
MP_PID=$!
sleep 3

echo "Testing multi-process mode..."
echo "create table test (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 8000 > mp_result.log 2>&1

echo "Multi-process server log:"
grep -i "mode\|process\|thread" mp_server.log | head -3

# Cleanup multi-process
echo "shutdown" | ../client/minidb_client 127.0.0.1 8000 > /dev/null 2>&1
wait $MP_PID
rm -f test_mp.db* minidb.wal*

echo ""
echo "Building multi-threaded server..."
make -C .. server-threaded > /dev/null 2>&1

echo "Starting multi-threaded server..."
../server/minidb_server 8001 test_mt.db > mt_server.log 2>&1 &
MT_PID=$!
sleep 3

echo "Testing multi-threaded mode..."
echo "create table test (id int, name varchar(10))" | ../client/minidb_client 127.0.0.1 8001 > mt_result.log 2>&1

echo "Multi-threaded server log:"
grep -i "mode\|process\|thread" mt_server.log | head -3

# Cleanup multi-threaded
echo "shutdown" | ../client/minidb_client 127.0.0.1 8001 > /dev/null 2>&1
wait $MT_PID
rm -f test_mt.db* minidb.wal*

echo ""
echo "✅ Mode testing completed"
echo "Check mp_server.log and mt_server.log for detailed output"

# Cleanup
rm -f *.log