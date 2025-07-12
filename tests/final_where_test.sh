#!/bin/bash
echo "Testing WHERE clause fix..."
../server/minidb_server 8000 test.db &
sleep 2
echo "select * from test where id = 1" | ../client/minidb_client 127.0.0.1 8000
pkill minidb_server
rm -f test.db*