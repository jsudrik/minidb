#!/bin/bash

# MiniDB Regression Test Framework
# Usage: ./run_tests.sh [options] [module] [test_name]
# Options:
#   --clean          Clean up generated files without running tests
#   --clean-run      Clean up and then run tests (default for all test runs)
# Examples:
#   ./run_tests.sh                  # Run all tests with cleanup
#   ./run_tests.sh dml              # Run all DML tests with cleanup
#   ./run_tests.sh queries select   # Run specific test with cleanup
#   ./run_tests.sh --clean          # Only clean up generated files

MINIDB_SERVER="../../server/minidb_server"
MINIDB_CLIENT="../../client/minidb_client"
TEST_PORT=7000
TIMEOUT=5

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test modules
MODULES=("dml" "ddl" "queries" "datatypes" "wal" "recovery")

# Default options
CLEAN_BEFORE_RUN=true
CLEAN_ONLY=false

# Check if server and client exist
if [ ! -f "$MINIDB_SERVER" ] || [ ! -f "$MINIDB_CLIENT" ]; then
    echo -e "${RED}Error: MiniDB server or client not found. Please build them first.${NC}"
    exit 1
fi

# Function to clean up test files
cleanup_test() {
    local module=$1
    local test_name=$2
    local test_dir="$module/$test_name"
    local output="$test_dir/run.out"
    local db_file="$test_dir/test.db"
    
    # Check if test exists
    if [ ! -d "$test_dir" ]; then
        return 1
    fi
    
    # Clean up test data
    rm -f "$db_file" "$db_file-"* "$test_dir/minidb.wal"* "$output" "$output.normalized" "$test_dir/expected.out.normalized" "$test_dir/server.log" "$test_dir/test.dif"
    # Also clean up any old output.out files for backward compatibility
    rm -f "$test_dir/output.out" "$test_dir/output.out.normalized"
    return 0
}

# Function to clean up all tests
cleanup_all_tests() {
    echo -e "${YELLOW}Cleaning up all test files${NC}"
    
    for module in "${MODULES[@]}"; do
        if [ -d "$module" ]; then
            for test_dir in "$module"/*/; do
                if [ -d "$test_dir" ]; then
                    test_name=$(basename "$test_dir")
                    cleanup_test "$module" "$test_name"
                    echo -e "${GREEN}Cleaned: $module/$test_name${NC}"
                fi
            done
        fi
    done
    
    # Clean up any stray WAL files in the main directory
    rm -f minidb.wal*
    
    # Clean up report files
    rm -f test_report.txt *_test_report.txt test_progress_report.txt *_progress_report.txt
    
    echo -e "${GREEN}All test files cleaned up${NC}"
}

# Function to run a single test
run_test() {
    local module=$1
    local test_name=$2
    local test_dir="$module/$test_name"
    local test_sql="$test_dir/test.sql"
    local expected="$test_dir/expected.out"
    local output="$test_dir/run.out"
    local db_file="$test_dir/test.db"
    local test_port=$((TEST_PORT + RANDOM % 1000))
    
    # Check if test exists
    if [ ! -d "$test_dir" ] || [ ! -f "$test_sql" ] || [ ! -f "$expected" ]; then
        echo -e "${RED}Test $module/$test_name not found or incomplete${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running test: $module/$test_name${NC}"
    
    # Clean up any previous test data if requested
    if [ "$CLEAN_BEFORE_RUN" = true ]; then
        cleanup_test "$module" "$test_name"
    fi
    
    # Start server
    $MINIDB_SERVER $test_port "$db_file" > "$test_dir/server.log" 2>&1 &
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 1
    
    # Run test
    cat "$test_sql" | $MINIDB_CLIENT 127.0.0.1 $test_port > "$output" 2>&1
    
    # Shutdown server
    kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    
    # Compare output with expected (ignoring port numbers, memory addresses, and whitespace)
    # Strip port numbers, normalize whitespace, and replace memory addresses
    sed -E 's/127\.0\.0\.1:[0-9]+/127.0.0.1:PORT/g' "$output" | \
    sed -E 's/[0-9-]+  [a-z]/MEMORY_ADDR  X/g' | \
    tr -s '\n' > "${output}.normalized"
    
    sed -E 's/127\.0\.0\.1:[0-9]+/127.0.0.1:PORT/g' "$expected" | \
    sed -E 's/[0-9-]+  [a-z]/MEMORY_ADDR  X/g' | \
    tr -s '\n' > "${expected}.normalized"
    
    # Create a progress indicator (only if not part of a larger test run)
    if [ -z "$total_tests" ] || [ "$total_tests" -eq 0 ]; then
        echo -ne "${YELLOW}[RUNNING]${NC} $module/$test_name\r"
    fi
    
    if diff -w "${output}.normalized" "${expected}.normalized" > /dev/null; then
        echo -e "${GREEN}[PASSED]${NC} $module/$test_name "
        return 0
    else
        echo -e "${RED}[FAILED]${NC} $module/$test_name"
        echo -e "${YELLOW}Differences:${NC}"
        # Create a .dif file with the differences
        diff_file="$test_dir/test.dif"
        diff -w "${output}.normalized" "${expected}.normalized" > "$diff_file"
        # Show first few lines of differences
        head -n 10 "$diff_file"
        return 1
    fi
}

# Function to run all tests in a module
run_module_tests() {
    local module=$1
    local passed=0
    local failed=0
    local total=0
    local failed_tests=()
    local start_time=$(date +%s)
    local total_tests=0
    local completed_tests=0
    
    echo -e "${YELLOW}Running all tests in module: $module${NC}"
    
    # Count total tests first
    for test_dir in "$module"/*/; do
        if [ -d "$test_dir" ]; then
            total_tests=$((total_tests + 1))
        fi
    done
    
    # Create a report file
    local report_file="${module}_test_report.txt"
    echo "MiniDB Regression Test Report - Module: $module" > "$report_file"
    echo "=========================================" >> "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "Started at: $(date -r $start_time)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Create a progress report file
    local progress_file="${module}_progress_report.txt"
    echo "MiniDB Test Progress Report - Module: $module" > "$progress_file"
    echo "=========================================" >> "$progress_file"
    echo "Started: $(date)" >> "$progress_file"
    echo "Total tests to run: $total_tests" >> "$progress_file"
    echo "" >> "$progress_file"
    
    # Find all test directories in the module
    for test_dir in "$module"/*/; do
        if [ -d "$test_dir" ]; then
            test_name=$(basename "$test_dir")
            if run_test "$module" "$test_name"; then
                passed=$((passed + 1))
                echo "✓ PASS: $test_name" >> "$report_file"
            else
                failed=$((failed + 1))
                failed_tests+=("$test_name")
                echo "✗ FAIL: $test_name (see $module/$test_name/test.dif)" >> "$report_file"
            fi
            total=$((total + 1))
            
            # Update progress report
            completed_tests=$((completed_tests + 1))
            current_time=$(date +%s)
            elapsed=$((current_time - start_time))
            minutes=$((elapsed / 60))
            seconds=$((elapsed % 60))
            
            # Calculate estimated time remaining
            if [ $completed_tests -gt 0 ]; then
                avg_time_per_test=$(echo "scale=2; $elapsed / $completed_tests" | bc)
                remaining_tests=$((total_tests - completed_tests))
                est_remaining_time=$(echo "scale=0; $avg_time_per_test * $remaining_tests / 1" | bc)
                est_minutes=$((est_remaining_time / 60))
                est_seconds=$((est_remaining_time % 60))
            else
                est_minutes="?"
                est_seconds="?"
            fi
            
            # Calculate percentage
            percentage=$(echo "scale=1; $completed_tests * 100 / $total_tests" | bc)
            
            # Write to progress file
            echo -e "Progress: $completed_tests/$total_tests tests completed (${percentage}%)" > "$progress_file"
            echo -e "Time elapsed: ${minutes}m ${seconds}s" >> "$progress_file"
            echo -e "Estimated time remaining: ${est_minutes}m ${est_seconds}s" >> "$progress_file"
            echo -e "Passed: $passed, Failed: $failed" >> "$progress_file"
            
            # Also display progress on console
            echo -ne "\r${YELLOW}Progress: $completed_tests/$total_tests tests (${percentage}%) | Time: ${minutes}m ${seconds}s | Est. remaining: ${est_minutes}m ${est_seconds}s${NC}"
        fi
    done
    
    # Add execution time to report
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))
    
    echo "" >> "$report_file"
    echo "Summary" >> "$report_file"
    echo "-------" >> "$report_file"
    echo "Total execution time: ${minutes}m ${seconds}s" >> "$report_file"
    echo "Total tests: $total" >> "$report_file"
    echo "Passed: $passed" >> "$report_file"
    echo "Failed: $failed" >> "$report_file"
    
    if [ $failed -gt 0 ]; then
        echo "" >> "$report_file"
        echo "Failed Tests:" >> "$report_file"
        for test in "${failed_tests[@]}"; do
            echo "- $test" >> "$report_file"
        done
    fi
    
    # Final update to progress report
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))
    
    echo -e "\n\nTest Run Completed" >> "$progress_file"
    echo -e "------------------" >> "$progress_file"
    echo -e "Total time: ${minutes}m ${seconds}s" >> "$progress_file"
    echo -e "Tests run: $total" >> "$progress_file"
    echo -e "Passed: $passed" >> "$progress_file"
    echo -e "Failed: $failed" >> "$progress_file"
    
    # Clear progress line and print final summary
    echo -e "\r                                                                                                  "
    echo -e "${YELLOW}Module $module: $passed passed, $failed failed, $total total${NC}"
    echo -e "${YELLOW}Total time: ${minutes}m ${seconds}s${NC}"
    echo -e "${YELLOW}Test report saved to: $report_file${NC}"
    echo -e "${YELLOW}Progress report saved to: $progress_file${NC}"
    
    if [ $failed -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    local passed=0
    local failed=0
    local total=0
    local failed_tests=()
    local start_time=$(date +%s)
    local total_tests=0
    local completed_tests=0
    
    echo -e "${YELLOW}Running all regression tests${NC}"
    
    # Count total tests first
    for module in "${MODULES[@]}"; do
        if [ -d "$module" ]; then
            for test_dir in "$module"/*/; do
                if [ -d "$test_dir" ]; then
                    total_tests=$((total_tests + 1))
                fi
            done
        fi
    done
    
    # Create a report file
    local report_file="test_report.txt"
    echo "MiniDB Regression Test Report" > "$report_file"
    echo "===========================" >> "$report_file"
    echo "Generated: $(date)" >> "$report_file"
    echo "Started at: $(date -r $start_time)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Create a progress report file
    local progress_file="test_progress_report.txt"
    echo "MiniDB Test Progress Report" > "$progress_file"
    echo "========================" >> "$progress_file"
    echo "Started: $(date)" >> "$progress_file"
    echo "Total tests to run: $total_tests" >> "$progress_file"
    echo "" >> "$progress_file"
    
    for module in "${MODULES[@]}"; do
        if [ -d "$module" ]; then
            module_passed=0
            module_failed=0
            module_total=0
            
            echo "Module: $module" >> "$report_file"
            echo "-------------------" >> "$report_file"
            
            # Find all test directories in the module
            for test_dir in "$module"/*/; do
                if [ -d "$test_dir" ]; then
                    test_name=$(basename "$test_dir")
                    if run_test "$module" "$test_name"; then
                        passed=$((passed + 1))
                        module_passed=$((module_passed + 1))
                        echo "✓ PASS: $test_name" >> "$report_file"
                    else
                        failed=$((failed + 1))
                        module_failed=$((module_failed + 1))
                        failed_tests+=("$module/$test_name")
                        echo "✗ FAIL: $test_name (see $module/$test_name/test.dif)" >> "$report_file"
                    fi
                    total=$((total + 1))
                    module_total=$((module_total + 1))
                    
                    # Update progress report
                    completed_tests=$((completed_tests + 1))
                    current_time=$(date +%s)
                    elapsed=$((current_time - start_time))
                    minutes=$((elapsed / 60))
                    seconds=$((elapsed % 60))
                    
                    # Calculate estimated time remaining
                    if [ $completed_tests -gt 0 ]; then
                        avg_time_per_test=$(echo "scale=2; $elapsed / $completed_tests" | bc)
                        remaining_tests=$((total_tests - completed_tests))
                        est_remaining_time=$(echo "scale=0; $avg_time_per_test * $remaining_tests / 1" | bc)
                        est_minutes=$((est_remaining_time / 60))
                        est_seconds=$((est_remaining_time % 60))
                    else
                        est_minutes="?"
                        est_seconds="?"
                    fi
                    
                    # Write to progress file
                    percentage=$(echo "scale=1; $completed_tests * 100 / $total_tests" | bc)
                    echo -e "Progress: $completed_tests/$total_tests tests completed (${percentage}%)" > "$progress_file"
                    echo -e "Time elapsed: ${minutes}m ${seconds}s" >> "$progress_file"
                    echo -e "Estimated time remaining: ${est_minutes}m ${est_seconds}s" >> "$progress_file"
                    echo -e "Passed: $passed, Failed: $failed" >> "$progress_file"
                    
                    # Also display progress on console
                    echo -ne "\r${YELLOW}Progress: $completed_tests/$total_tests tests (${percentage}%) | Time: ${minutes}m ${seconds}s | Est. remaining: ${est_minutes}m ${est_seconds}s${NC}"
                fi
            done
            
            echo "" >> "$report_file"
            echo "Summary: $module_passed passed, $module_failed failed, $module_total total" >> "$report_file"
            echo "" >> "$report_file"
            
            echo -e "${YELLOW}Module $module: $module_passed passed, $module_failed failed, $module_total total${NC}"
        fi
    done
    
    # Add execution time to report
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))
    
    echo "" >> "$report_file"
    echo "Overall Summary" >> "$report_file"
    echo "---------------" >> "$report_file"
    echo "Total execution time: ${minutes}m ${seconds}s" >> "$report_file"
    echo "Total tests: $total" >> "$report_file"
    echo "Passed: $passed" >> "$report_file"
    echo "Failed: $failed" >> "$report_file"
    
    if [ $failed -gt 0 ]; then
        echo "" >> "$report_file"
        echo "Failed Tests:" >> "$report_file"
        for test in "${failed_tests[@]}"; do
            echo "- $test" >> "$report_file"
        done
    fi
    
    # Final update to progress report
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))
    
    echo -e "\n\nTest Run Completed" >> "$progress_file"
    echo -e "------------------" >> "$progress_file"
    echo -e "Total time: ${minutes}m ${seconds}s" >> "$progress_file"
    echo -e "Tests run: $total" >> "$progress_file"
    echo -e "Passed: $passed" >> "$progress_file"
    echo -e "Failed: $failed" >> "$progress_file"
    
    # Clear progress line and print final summary
    echo -e "\r                                                                                                  "
    echo -e "${YELLOW}All tests: $passed passed, $failed failed, $total total${NC}"
    echo -e "${YELLOW}Total time: ${minutes}m ${seconds}s${NC}"
    echo -e "${YELLOW}Test report saved to: $report_file${NC}"
    echo -e "${YELLOW}Progress report saved to: $progress_file${NC}"
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed! See $report_file for details${NC}"
        return 1
    fi
}

# Main execution
cd "$(dirname "$0")"

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_ONLY=true
            shift
            ;;
        --clean-run)
            CLEAN_BEFORE_RUN=true
            shift
            ;;
        --no-clean)
            CLEAN_BEFORE_RUN=false
            shift
            ;;
        *)
            break
            ;;
    esac
done

# Handle clean-only mode
if [ "$CLEAN_ONLY" = true ]; then
    cleanup_all_tests
    exit 0
fi

if [ $# -eq 0 ]; then
    # Run all tests
    run_all_tests
elif [ $# -eq 1 ]; then
    # Run all tests in a module
    if [[ " ${MODULES[@]} " =~ " $1 " ]]; then
        run_module_tests "$1"
    else
        echo -e "${RED}Invalid module: $1${NC}"
        echo -e "${YELLOW}Available modules: ${MODULES[@]}${NC}"
        exit 1
    fi
elif [ $# -eq 2 ]; then
    # Run a specific test
    if [[ " ${MODULES[@]} " =~ " $1 " ]]; then
        run_test "$1" "$2"
    else
        echo -e "${RED}Invalid module: $1${NC}"
        echo -e "${YELLOW}Available modules: ${MODULES[@]}${NC}"
        exit 1
    fi
else
    echo "Usage: $0 [options] [module] [test_name]"
    echo "Options:"
    echo "  --clean          Clean up generated files without running tests"
    echo "  --clean-run      Clean up and then run tests (default)"
    echo "  --no-clean       Run tests without cleaning up first"
    echo "Examples:"
    echo "  $0                  # Run all tests with cleanup"
    echo "  $0 dml              # Run all DML tests with cleanup"
    echo "  $0 queries select   # Run specific test with cleanup"
    echo "  $0 --clean          # Only clean up generated files"
    echo "  $0 --no-clean dml   # Run DML tests without cleanup"
    exit 1
fi