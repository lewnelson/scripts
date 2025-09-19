#!/usr/bin/env bats

setup() {
    # Load functions to test
    source "${BATS_TEST_DIRNAME}/../promote-functions.sh"
}

@test "get_repo_name: extracts repo name from HTTPS URL" {
    result=$(get_repo_name "https://github.com/user/repo.git")
    [ "$result" = "user/repo" ]
}

@test "get_repo_name: extracts repo name from SSH URL" {
    result=$(get_repo_name "git@github.com:user/repo.git")
    [ "$result" = "user/repo" ]
}

@test "extract_linear_tickets: extracts single ticket" {
    result=$(extract_linear_tickets "This is a commit [ENG-123] fixing something")
    [ "$result" = "ENG-123" ]
}

@test "extract_linear_tickets: extracts multiple tickets and sorts them" {
    result=$(extract_linear_tickets "Fix [ENG-456] and [ENG-123] issues")
    [ "$result" = "ENG-123 ENG-456" ]
}

@test "extract_linear_tickets: deduplicates tickets" {
    result=$(extract_linear_tickets "Fix [ENG-123] and [ENG-123] again")
    [ "$result" = "ENG-123" ]
}

@test "extract_linear_tickets: handles no tickets" {
    result=$(extract_linear_tickets "No tickets here")
    [ "$result" = "" ]
}

@test "extract_linear_tickets: sorts tickets numerically" {
    result=$(extract_linear_tickets "[ENG-2] [ENG-10] [ENG-1]")
    [ "$result" = "ENG-1 ENG-2 ENG-10" ]
}

@test "get_commit_type: identifies feat commits" {
    result=$(get_commit_type "feat: add new feature")
    [ "$result" = "feat" ]
}

@test "get_commit_type: identifies feat commits with scope" {
    result=$(get_commit_type "feat(auth): add login functionality")
    [ "$result" = "feat" ]
}

@test "get_commit_type: identifies feat commits with breaking change" {
    result=$(get_commit_type "feat!: breaking change")
    [ "$result" = "feat" ]
}

@test "get_commit_type: identifies fix commits" {
    result=$(get_commit_type "fix: resolve login issue")
    [ "$result" = "fix" ]
}

@test "get_commit_type: identifies chore commits" {
    result=$(get_commit_type "chore: update dependencies")
    [ "$result" = "chore" ]
}

@test "get_commit_type: defaults to chore for non-conventional commits" {
    result=$(get_commit_type "random commit message")
    [ "$result" = "chore" ]
}

@test "get_commit_type: identifies docs commits" {
    result=$(get_commit_type "docs: update README")
    [ "$result" = "docs" ]
}

@test "get_commit_type: identifies refactor commits" {
    result=$(get_commit_type "refactor: restructure auth module")
    [ "$result" = "refactor" ]
}

@test "get_pr_priority: feat has highest priority" {
    result=$(get_pr_priority "feat")
    [ "$result" = "1" ]
}

@test "get_pr_priority: fix has second priority" {
    result=$(get_pr_priority "fix")
    [ "$result" = "2" ]
}

@test "get_pr_priority: chore has lowest priority" {
    result=$(get_pr_priority "chore")
    [ "$result" = "10" ]
}

@test "get_pr_priority: unknown type defaults to chore priority" {
    result=$(get_pr_priority "unknown")
    [ "$result" = "10" ]
}

@test "get_pr_category_name: maps feat to Features" {
    result=$(get_pr_category_name "feat")
    [ "$result" = "Features" ]
}

@test "get_pr_category_name: maps fix to Fixes" {
    result=$(get_pr_category_name "fix")
    [ "$result" = "Fixes" ]
}

@test "get_pr_category_name: maps chore to Chores" {
    result=$(get_pr_category_name "chore")
    [ "$result" = "Chores" ]
}

@test "get_pr_category_name: unknown type defaults to Chores" {
    result=$(get_pr_category_name "unknown")
    [ "$result" = "Chores" ]
}

@test "format_ticket_list: formats single ticket" {
    result=$(format_ticket_list "ENG-123")
    [ "$result" = "[ENG-123]" ]
}

@test "format_ticket_list: formats multiple tickets" {
    result=$(format_ticket_list "ENG-123 ENG-456")
    [ "$result" = "[ENG-123 ENG-456]" ]
}

@test "format_ticket_list: handles empty input" {
    result=$(format_ticket_list "")
    [ "$result" = "" ]
}

@test "format_ticket_list: sorts tickets numerically" {
    result=$(format_ticket_list "ENG-456 ENG-123")
    [ "$result" = "[ENG-123 ENG-456]" ]
}

@test "validate_arguments: accepts stage" {
    validate_arguments "stage"
    [ $? -eq 0 ]
}

@test "validate_arguments: accepts main" {
    validate_arguments "main"
    [ $? -eq 0 ]
}

@test "validate_arguments: rejects invalid argument" {
    run validate_arguments "invalid"
    [ $status -eq 1 ]
}

@test "get_branch_mapping: returns correct mapping for stage" {
    result=$(get_branch_mapping "stage")
    [ "$result" = "develop stage" ]
}

@test "get_branch_mapping: returns correct mapping for main" {
    result=$(get_branch_mapping "main")
    [ "$result" = "stage main" ]
}