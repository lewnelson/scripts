#!/usr/bin/env bats

# Standalone unit tests that don't require git setup or external dependencies

setup() {
    # Load functions to test
    source "${BATS_TEST_DIRNAME}/../promote-functions.sh"
}

@test "unit: extract tickets from complex commit message" {
    input="feat: implement auth [ENG-123] and fix bug [ENG-456]

This commit also references [ENG-789] in the body
And duplicate [ENG-123] should be ignored"
    
    result=$(extract_linear_tickets "$input")
    [ "$result" = "ENG-123 ENG-456 ENG-789" ]
}

@test "unit: ticket formatting with sorting" {
    result=$(format_ticket_list "ENG-456 ENG-123 ENG-789")
    [ "$result" = "[ENG-123 ENG-456 ENG-789]" ]
}

@test "unit: commit type priority resolution" {
    feat_priority=$(get_pr_priority "feat")
    fix_priority=$(get_pr_priority "fix")
    chore_priority=$(get_pr_priority "chore")
    
    # feat should have highest priority (lowest number)
    [ "$feat_priority" -lt "$fix_priority" ]
    [ "$fix_priority" -lt "$chore_priority" ]
}

@test "unit: branch mapping logic" {
    stage_mapping=$(get_branch_mapping "stage")
    main_mapping=$(get_branch_mapping "main")
    
    [ "$stage_mapping" = "develop stage" ]
    [ "$main_mapping" = "stage main" ]
}

@test "unit: argument validation" {
    # Test valid arguments
    validate_arguments "stage"
    [ $? -eq 0 ]
    
    validate_arguments "main"
    [ $? -eq 0 ]
    
    # Test invalid argument
    run validate_arguments "invalid"
    [ $status -eq 1 ]
}

@test "unit: category name mapping" {
    [ "$(get_pr_category_name "feat")" = "Features" ]
    [ "$(get_pr_category_name "fix")" = "Fixes" ]
    [ "$(get_pr_category_name "chore")" = "Chores" ]
    [ "$(get_pr_category_name "unknown")" = "Chores" ]
}

@test "unit: repo name extraction" {
    https_result=$(get_repo_name "https://github.com/user/repo.git")
    ssh_result=$(get_repo_name "git@github.com:user/repo.git")
    
    [ "$https_result" = "user/repo" ]
    [ "$ssh_result" = "user/repo" ]
}

@test "unit: edge cases for ticket extraction" {
    # No tickets
    result=$(extract_linear_tickets "No tickets here")
    [ "$result" = "" ]
    
    # Malformed tickets should be ignored
    result=$(extract_linear_tickets "Invalid [ENG-] and [ENG-abc] but valid [ENG-123]")
    [ "$result" = "ENG-123" ]
}

@test "unit: ticket extraction supports both bracket and non-bracket formats" {
    # Both formats together
    result=$(extract_linear_tickets "[ENG-143] added feature and ENG-12 fix")
    [ "$result" = "ENG-12 ENG-143" ]
    
    # Non-bracket format only
    result=$(extract_linear_tickets "Fix ENG-456 issue")
    [ "$result" = "ENG-456" ]
    
    # Mixed with other text
    result=$(extract_linear_tickets "Fix(promote script) ENG-12 Fixes the promote script")
    [ "$result" = "ENG-12" ]
}

@test "unit: ticket extraction is case-insensitive" {
    # Mixed case tickets
    result=$(extract_linear_tickets "Fix eng-123 and [ENG-456] and Eng-789")
    [ "$result" = "ENG-123 ENG-456 ENG-789" ]
    
    # All lowercase
    result=$(extract_linear_tickets "Fix [eng-123] issue")
    [ "$result" = "ENG-123" ]
}

@test "unit: ticket extraction supports custom prefixes" {
    # Custom prefix ABC
    result=$(extract_linear_tickets "Fix ABC-123 and [ABC-456] issues" "ABC")
    [ "$result" = "ABC-123 ABC-456" ]
    
    # Custom prefix with different case
    result=$(extract_linear_tickets "Fix abc-123 and [ABC-456] issues" "abc")
    [ "$result" = "ABC-123 ABC-456" ]
    
    # Ignore wrong prefix
    result=$(extract_linear_tickets "Fix ENG-123 and ABC-456 issues" "ABC")
    [ "$result" = "ABC-456" ]
}

@test "unit: ticket extraction supports multiple prefixes" {
    # Multiple prefixes
    result=$(extract_linear_tickets "Fix ENG-123 and DEV-456 issues" "ENG DEV")
    [ "$result" = "DEV-456 ENG-123" ]
    
    # Mixed case with multiple prefixes
    result=$(extract_linear_tickets "Fix eng-123 and [DEV-456] and abc-789" "ENG DEV ABC")
    [ "$result" = "ABC-789 DEV-456 ENG-123" ]
    
    # Duplicate tickets across prefixes should be deduplicated
    result=$(extract_linear_tickets "Fix ENG-123 and [ENG-123] and DEV-456" "ENG DEV")
    [ "$result" = "DEV-456 ENG-123" ]
}

@test "unit: ticket extraction defaults to ENG when no prefix specified" {
    result=$(extract_linear_tickets "Fix ENG-123 and ABC-456 issues")
    [ "$result" = "ENG-123" ]
}

@test "unit: commit type detection edge cases" {
    # With scope and breaking change
    [ "$(get_commit_type "feat(auth)!: breaking change")" = "feat" ]
    [ "$(get_commit_type "fix(ui): resolve issue")" = "fix" ]
    
    # Non-conventional commits default to chore
    [ "$(get_commit_type "random commit message")" = "chore" ]
    [ "$(get_commit_type "WIP: work in progress")" = "chore" ]
}

@test "unit: dry-run argument parsing" {
    # Test that the script recognizes dry-run flag by checking usage
    cd "${BATS_TEST_DIRNAME}/.."
    
    run ./promote.sh --dry-run 2>/dev/null || true
    [[ "$output" == *"Target (stage|main) is required"* ]]
    
    run ./promote.sh --invalid-option 2>/dev/null || true
    [[ "$output" == *"Unknown option"* ]]
}

@test "unit: multiple linear identifiers argument parsing" {
    cd "${BATS_TEST_DIRNAME}/.."
    
    # Test that multiple --linear-identifier arguments are required
    run ./promote.sh --linear-org=test stage 2>/dev/null || true
    [[ "$output" == *"At least one --linear-identifier is required"* ]]
    
    # Test that script recognizes multiple identifiers
    run ./promote.sh --dry-run --linear-org=test --linear-identifier=ENG --linear-identifier=DEV stage 2>/dev/null || true
    [[ "$output" == *"Using Linear identifiers: DEV ENG"* ]]
}

@test "unit: usage shows dry-run option" {
    cd "${BATS_TEST_DIRNAME}/.."
    
    run ./promote.sh --help 2>/dev/null || true
    [[ "$output" == *"--dry-run"* ]]
    [[ "$output" == *"Show what would be done without making changes"* ]]
    [[ "$output" == *"--linear-identifier"* ]]
    [[ "$output" == *"Can be used multiple times"* ]]
}