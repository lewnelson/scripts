#!/bin/bash

# Mock GitHub CLI responses for testing

function mock_gh_pr_list_empty() {
    echo ""
}

function mock_gh_pr_list_existing() {
    echo "456"
}

function mock_gh_pr_view_title() {
    local pr_number="$1"
    case "$pr_number" in
        "123") echo "feat: add user authentication [ENG-456]" ;;
        "124") echo "fix: resolve memory leak in auth module" ;;
        "125") echo "chore: update dependencies" ;;
        "126") echo "refactor: restructure auth components [ENG-789]" ;;
        *) echo "Unknown PR: $pr_number" ;;
    esac
}

function mock_gh_pr_view_body() {
    local pr_number="$1"
    case "$pr_number" in
        "123") echo "This PR implements user authentication functionality.

Includes:
- Login form
- JWT token handling  
- Session management

Related to [ENG-456]" ;;
        "124") echo "Fixes memory leak that was causing performance issues.

Fixes [ENG-123]" ;;
        "125") echo "Updates various dependencies to latest versions.

No specific ticket associated." ;;
        "126") echo "Refactors authentication components for better maintainability.

See [ENG-789] for details." ;;
        *) echo "Unknown PR: $pr_number" ;;
    esac
}

function mock_gh_pr_search() {
    local commit_hash="$1"
    case "$commit_hash" in
        "abc123"|"def456") echo "123" ;;
        "ghi789") echo "124" ;;
        "jkl012") echo "125" ;;
        "mno345"|"pqr678") echo "126" ;;
        *) echo "" ;;
    esac
}

function mock_gh_pr_create() {
    echo "https://github.com/test/repo/pull/789"
}

# Export functions for use in tests
export -f mock_gh_pr_list_empty
export -f mock_gh_pr_list_existing
export -f mock_gh_pr_view_title
export -f mock_gh_pr_view_body
export -f mock_gh_pr_search
export -f mock_gh_pr_create