# Promote.sh Tests

This directory contains automated tests for the `promote.sh` script.

## Test Structure

```
test/
├── fixtures/                          # Test data and mocks
│   ├── sample_pr_data.json           # Sample PR data for testing
│   └── mock_gh_responses.sh           # Mock GitHub CLI responses
├── test_promote_functions.bats        # Unit tests for individual functions
├── test_promote_integration.bats      # Integration tests
└── run_tests.sh                      # Test runner script
```

## Prerequisites

Install [bats-core](https://github.com/bats-core/bats-core) testing framework:

**macOS (Homebrew):**
```bash
brew install bats-core
```

**Ubuntu/Debian:**
```bash
sudo apt-get install bats
```

**Manual installation:**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Running Tests

### Run All Tests
```bash
./test/run_tests.sh
```

### Run Individual Test Files
```bash
# Unit tests only
bats test/test_promote_functions.bats

# Integration tests only  
bats test/test_promote_integration.bats
```

### Run Specific Tests
```bash
# Run tests matching a pattern
bats test/test_promote_functions.bats --filter "extract_linear_tickets"
```

## Test Coverage

### Unit Tests (`test_promote_functions.bats`)
- ✅ `get_repo_name()` - Repository name extraction from URLs
- ✅ `extract_linear_tickets()` - Linear ticket extraction and sorting
- ✅ `get_commit_type()` - Conventional commit type detection
- ✅ `get_pr_priority()` - Priority calculation for commit types
- ✅ `get_pr_category_name()` - Category name mapping
- ✅ `format_ticket_list()` - Ticket list formatting
- ✅ `validate_arguments()` - Argument validation
- ✅ `get_branch_mapping()` - Branch mapping logic

### Integration Tests (`test_promote_integration.bats`)
- ✅ Command line argument handling
- ✅ Git repository setup and branch detection
- ✅ GitHub CLI mocking and interaction
- ✅ End-to-end workflow testing
- ✅ Complex ticket extraction scenarios
- ✅ Priority resolution with multiple commit types

## Test Features

### Mock GitHub CLI
The tests include a comprehensive mock of the `gh` CLI tool that:
- Simulates PR listing, viewing, and creation
- Returns predictable responses for testing
- Handles different PR states and scenarios

### Temporary Git Repositories
Integration tests create isolated git repositories to:
- Test branch operations safely
- Simulate real git workflows
- Avoid affecting the actual repository

### Fixture Data
Sample data includes:
- Representative PR titles and bodies
- Various commit message formats
- Expected output formats
- Edge cases and error scenarios

## Writing New Tests

### Function Tests
```bash
@test "function_name: test description" {
    source "${BATS_TEST_DIRNAME}/../promote-functions.sh"
    
    result=$(function_name "input")
    [ "$result" = "expected_output" ]
}
```

### Integration Tests
```bash
@test "integration: test description" {
    cd "$TEST_TEMP_DIR"  # Use temporary directory
    
    # Set up test scenario
    # Run promote.sh
    # Verify results
}
```

## Debugging Tests

### Verbose Output
```bash
bats -t test/test_promote_functions.bats
```

### Print Variables
```bash
@test "debug test" {
    # Add debug output
    echo "Debug: variable=$variable" >&3
    
    # Your test logic here
}
```

### Manual Test Environment
```bash
# Set up the same environment as tests
export TEST_TEMP_DIR="$(mktemp -d)"
cd "$TEST_TEMP_DIR"
git init
# ... continue with manual testing
```

## Continuous Integration

These tests are designed to run in CI environments and will:
- Exit with appropriate status codes
- Provide clear failure messages
- Handle missing dependencies gracefully
- Clean up temporary resources

Run `./test/run_tests.sh` in your CI pipeline to validate the promote.sh script.