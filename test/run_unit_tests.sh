#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Running promote.sh unit tests (no external dependencies)..."
echo "============================================================"

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo "❌ bats is not installed. Please install it first:"
    echo ""
    echo "# macOS (with Homebrew):"
    echo "brew install bats-core"
    echo ""
    exit 1
fi

echo "✅ bats found: $(which bats)"
echo ""

# Function to run tests with proper error handling
run_test_file() {
    local test_file="$1"
    local test_name="$2"
    
    echo "🔍 Running $test_name..."
    echo "   File: $test_file"
    
    if bats "$test_file"; then
        echo "✅ $test_name: PASSED"
        return 0
    else
        echo "❌ $test_name: FAILED"
        return 1
    fi
    echo ""
}

# Track overall test results
FAILED_TESTS=0

# Run unit tests for functions (original comprehensive tests)
if ! run_test_file "$SCRIPT_DIR/test_promote_functions.bats" "Function Unit Tests"; then
    ((FAILED_TESTS++))
fi

# Run standalone unit tests (no git setup required)
if ! run_test_file "$SCRIPT_DIR/test_promote_unit_only.bats" "Standalone Unit Tests"; then
    ((FAILED_TESTS++))
fi

echo "============================================================"
echo "📊 Unit Test Summary"
echo "============================================================"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 All unit tests passed!"
    echo ""
    echo "📋 Test Coverage:"
    echo "  ✅ Function unit tests (32 tests)"
    echo "  ✅ Standalone unit tests (10 tests)"
    echo "  ✅ Edge case handling"
    echo "  ✅ No external dependencies required"
    echo ""
    echo "The promote.sh functions are working correctly!"
    echo ""
    echo "To run integration tests (requires git setup):"
    echo "  ./test/run_tests.sh"
    exit 0
else
    echo "💥 $FAILED_TESTS test suite(s) failed!"
    echo ""
    echo "Please check the error messages above and fix any issues."
    exit 1
fi