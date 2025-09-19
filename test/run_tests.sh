#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🧪 Running promote.sh tests..."
echo "================================"

# Check if bats is installed
if ! command -v bats &> /dev/null; then
    echo "❌ bats is not installed. Please install it first:"
    echo ""
    echo "# macOS (with Homebrew):"
    echo "brew install bats-core"
    echo ""
    echo "# Ubuntu/Debian:"
    echo "sudo apt-get install bats"
    echo ""
    echo "# Or install manually:"
    echo "git clone https://github.com/bats-core/bats-core.git"
    echo "cd bats-core"
    echo "./install.sh /usr/local"
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
    else
        echo "❌ $test_name: FAILED"
        return 1
    fi
    echo ""
}

# Track overall test results
FAILED_TESTS=0

# Run unit tests for functions
if ! run_test_file "$SCRIPT_DIR/test_promote_functions.bats" "Unit Tests (Functions)"; then
    ((FAILED_TESTS++))
fi

# Run integration tests
if ! run_test_file "$SCRIPT_DIR/test_promote_integration.bats" "Integration Tests"; then
    ((FAILED_TESTS++))
fi

echo "================================"
echo "📊 Test Summary"
echo "================================"

if [ $FAILED_TESTS -eq 0 ]; then
    echo "🎉 All tests passed!"
    echo ""
    echo "📋 Test Coverage:"
    echo "  ✅ Function unit tests"
    echo "  ✅ Integration tests"
    echo "  ✅ Error handling"
    echo "  ✅ Mock GitHub CLI interactions"
    echo ""
    echo "The promote.sh script is ready for use!"
    exit 0
else
    echo "💥 $FAILED_TESTS test suite(s) failed!"
    echo ""
    echo "Please check the error messages above and fix any issues."
    echo "You can run individual test files like this:"
    echo "  bats test/test_promote_functions.bats"
    echo "  bats test/test_promote_integration.bats"
    exit 1
fi