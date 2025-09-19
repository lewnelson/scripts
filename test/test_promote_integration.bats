#!/usr/bin/env bats

setup() {
    # Create a temporary directory for test workspace
    export TEST_TEMP_DIR="$(mktemp -d)"
    export ORIGINAL_DIR="$(pwd)"
    
    # Create mock git repository
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create mock remote
    git remote add origin "https://github.com/test/repo.git"
    
    # Create initial commit
    echo "initial" > README.md
    git add README.md
    git commit -m "initial commit" --quiet
    
    # Set default branch to main if it doesn't exist
    if ! git show-ref --verify --quiet refs/heads/main; then
        git branch -m master main 2>/dev/null || git checkout -b main --quiet
    fi
    
    # Create branches
    git checkout -b develop --quiet 2>/dev/null || git checkout develop --quiet
    git checkout -b stage --quiet 2>/dev/null || git checkout stage --quiet
    git checkout develop --quiet
    
    # Create mock gh command using our comprehensive mock
    export PATH="$TEST_TEMP_DIR/bin:$PATH"
    mkdir -p "$TEST_TEMP_DIR/bin"
    
    # Copy our comprehensive mock and make it the gh command
    cp "${BATS_TEST_DIRNAME}/fixtures/mock_gh.sh" "$TEST_TEMP_DIR/bin/gh"
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Verify mock is working
    if ! "$TEST_TEMP_DIR/bin/gh" pr list --repo test/repo --head develop --base stage --state open --json number --jq '.[0].number' >/dev/null 2>&1; then
        echo "Mock gh command not working properly" >&2
        exit 1
    fi
}

teardown() {
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_TEMP_DIR"
}

@test "promote.sh: shows usage when no arguments provided" {
    cd "$ORIGINAL_DIR"
    run "${BATS_TEST_DIRNAME}/../promote.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "promote.sh: shows usage for invalid argument" {
    cd "$ORIGINAL_DIR"
    run "${BATS_TEST_DIRNAME}/../promote.sh" invalid
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Invalid target 'invalid'"* ]]
}

@test "promote.sh: handles no commits to promote" {
    # Make sure we're in our test git repo
    cd "$TEST_TEMP_DIR"
    
    # Copy the promote script to test directory and modify to use our test functions
    cp "${BATS_TEST_DIRNAME}/../promote.sh" ./promote.sh
    cp "${BATS_TEST_DIRNAME}/../promote-functions.sh" ./promote-functions.sh
    
    # Run with stage (develop -> stage), should have no commits
    run ./promote.sh stage
    [ "$status" -eq 0 ]
    [[ "$output" == *"No commits to promote from develop to stage"* ]]
}

@test "promote.sh: handles commits with PRs" {
    cd "$TEST_TEMP_DIR"
    
    # Create some commits on develop
    echo "feature1" > feature1.txt
    git add feature1.txt
    git commit -m "feat: add feature1 [ENG-123]" --quiet
    
    echo "feature2" > feature2.txt
    git add feature2.txt
    git commit -m "fix: fix issue [ENG-456]" --quiet
    
    # Copy scripts
    cp "${BATS_TEST_DIRNAME}/../promote.sh" ./promote.sh
    cp "${BATS_TEST_DIRNAME}/../promote-functions.sh" ./promote-functions.sh
    
    # Run promote script
    run ./promote.sh stage
    [ "$status" -eq 0 ]
    [[ "$output" == *"Promoting from develop to stage"* ]]
    [[ "$output" == *"Repository: test/repo"* ]]
}

@test "integration: ticket extraction from complex commit messages" {
    source "${BATS_TEST_DIRNAME}/../promote-functions.sh"
    
    # Test complex scenarios
    tickets=$(extract_linear_tickets "feat: implement auth [ENG-123] and fix bug [ENG-456]
    
    This commit also references [ENG-789] in the body")
    
    [ "$tickets" = "ENG-123 ENG-456 ENG-789" ]
}

@test "integration: commit type resolution with priority" {
    source "${BATS_TEST_DIRNAME}/../promote-functions.sh"
    
    # feat should take priority over fix
    feat_priority=$(get_pr_priority "feat")
    fix_priority=$(get_pr_priority "fix")
    
    [ "$feat_priority" -lt "$fix_priority" ]
}

@test "integration: end-to-end ticket formatting" {
    source "${BATS_TEST_DIRNAME}/../promote-functions.sh"
    
    # Extract tickets and format them
    raw_tickets=$(extract_linear_tickets "feat: [ENG-456] fix: [ENG-123] chore: [ENG-789]")
    formatted=$(format_ticket_list "$raw_tickets")
    
    [ "$formatted" = "[ENG-123 ENG-456 ENG-789]" ]
}

@test "integration: dry-run mode with commits" {
    cd "$TEST_TEMP_DIR"
    
    # Create some commits on develop
    echo "feature1" > feature1.txt
    git add feature1.txt
    git commit -m "feat: add feature1 [ENG-123]" --quiet
    
    echo "feature2" > feature2.txt
    git add feature2.txt
    git commit -m "fix: fix issue [ENG-456]" --quiet
    
    # Copy scripts
    cp "${BATS_TEST_DIRNAME}/../promote.sh" ./promote.sh
    cp "${BATS_TEST_DIRNAME}/../promote-functions.sh" ./promote-functions.sh
    
    # Run promote script in dry-run mode
    run ./promote.sh --dry-run stage
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY RUN MODE"* ]]
    [[ "$output" == *"Would execute: gh pr create"* ]]
    [[ "$output" == *"develop -> stage"* ]]
}