#!/bin/bash

# Simple build verification test

echo "🔧 MiniDB Build Mode Verification"
echo "=================================="

cd ..

echo "Testing multi-process build..."
make server-debug > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Multi-process debug build: SUCCESS"
else
    echo "❌ Multi-process debug build: FAILED"
fi

echo "Testing multi-threaded build..."
make server-threaded > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Multi-threaded debug build: SUCCESS"
else
    echo "❌ Multi-threaded debug build: FAILED"
fi

echo "Testing optimized builds..."
make server-optimized > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Multi-process optimized build: SUCCESS"
else
    echo "❌ Multi-process optimized build: FAILED"
fi

make server-threaded-optimized > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Multi-threaded optimized build: SUCCESS"
else
    echo "❌ Multi-threaded optimized build: FAILED"
fi

echo ""
echo "Checking build artifacts..."
if [ -f server/minidb_server ]; then
    echo "✅ Server binary created"
    
    # Check for threading symbols
    if nm server/minidb_server | grep -q pthread; then
        echo "✅ Threading support detected"
    else
        echo "⚠️ Threading support not detected"
    fi
else
    echo "❌ Server binary not found"
fi

echo ""
echo "Build verification completed"