#!/bin/bash

# Simple script to verify the regression test framework

echo "MiniDB Regression Test Framework Verification"
echo "============================================="
echo

# Check directory structure
echo "Checking directory structure..."
for dir in dml ddl queries datatypes wal recovery; do
    if [ -d "$dir" ]; then
        echo "✓ $dir directory exists"
    else
        echo "✗ $dir directory missing"
    fi
done
echo

# Check main script
echo "Checking main test script..."
if [ -f "run_tests.sh" ] && [ -x "run_tests.sh" ]; then
    echo "✓ run_tests.sh exists and is executable"
else
    echo "✗ run_tests.sh missing or not executable"
fi
echo

# Count tests
echo "Counting tests..."
total_tests=0
for module in dml ddl queries datatypes wal recovery; do
    if [ -d "$module" ]; then
        test_count=$(find "$module" -type d -mindepth 1 | wc -l)
        echo "- $module: $test_count tests"
        total_tests=$((total_tests + test_count))
    fi
done
echo "Total: $total_tests tests"
echo

echo "Framework verification complete!"