#!/bin/bash
# Quick WHERE test
../server/minidb_server 7700 test.db > srv.log 2>&1 &
PID=$!
sleep 2
echo "create table t (id int)" | ../client/minidb_client 127.0.0.1 7700 > /dev/null 2>&1
echo "insert into t values (1)" | ../client/minidb_client 127.0.0.1 7700 > /dev/null 2>&1
echo "select * from t where id = 1" | ../client/minidb_client 127.0.0.1 7700 > result.log 2>&1 &
CLIENT_PID=$!
sleep 3
kill $CLIENT_PID $PID 2>/dev/null
echo "Result:"
cat result.log 2>/dev/null || echo "No result"
rm -f test.db* srv.log result.log minidb.wal* 2>/dev/null