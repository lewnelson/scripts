#!/bin/bash

function get_repo_name() {
    local repo_url="$1"
    echo "$repo_url" | sed -E 's/.*[\/:]([^\/]+\/[^\/]+)\.git$/\1/' 2>/dev/null || echo "$repo_url" | sed -r 's/.*[\/:]([^\/]+\/[^\/]+)\.git$/\1/'
}

function extract_linear_tickets() {
    local text="$1"
    local prefixes="$2"
    
    # Default to ENG if no prefixes specified
    if [ -z "$prefixes" ]; then
        prefixes="ENG"
    fi
    
    # Process each prefix and collect all matching tickets
    local all_tickets=""
    local IFS=' '
    for prefix in $prefixes; do
        # Convert to uppercase for pattern matching
        local upper_prefix=$(echo "$prefix" | tr '[:lower:]' '[:upper:]')
        
        # Extract tickets in both [PREFIX-XXX] and PREFIX-XXX formats (case-insensitive)
        local prefix_tickets=$(
            {
                echo "$text" | grep -ioE "\[$upper_prefix-[0-9]+\]" | sed 's/\[\(.*\)\]/\1/' | tr '[:lower:]' '[:upper:]'
                echo "$text" | grep -ioE "\b$upper_prefix-[0-9]+\b" | tr '[:lower:]' '[:upper:]'
            } | tr '\n' ' '
        )
        
        if [ -n "$prefix_tickets" ]; then
            if [ -z "$all_tickets" ]; then
                all_tickets="$prefix_tickets"
            else
                all_tickets="$all_tickets $prefix_tickets"
            fi
        fi
    done
    
    # Deduplicate, sort by prefix and number
    echo "$all_tickets" | tr ' ' '\n' | grep -v '^$' | sort -u -t'-' -k1,1 -k2,2n | tr '\n' ' ' | sed 's/ $//'
}

function get_commit_type() {
    local commit_msg="$1"
    
    if echo "$commit_msg" | grep -qE '^feat(\(.*\))?!?:'; then
        echo "feat"
    elif echo "$commit_msg" | grep -qE '^fix(\(.*\))?!?:'; then
        echo "fix"
    elif echo "$commit_msg" | grep -qE '^chore(\(.*\))?!?:'; then
        echo "chore"
    elif echo "$commit_msg" | grep -qE '^docs(\(.*\))?!?:'; then
        echo "docs"
    elif echo "$commit_msg" | grep -qE '^style(\(.*\))?!?:'; then
        echo "style"
    elif echo "$commit_msg" | grep -qE '^refactor(\(.*\))?!?:'; then
        echo "refactor"
    elif echo "$commit_msg" | grep -qE '^perf(\(.*\))?!?:'; then
        echo "perf"
    elif echo "$commit_msg" | grep -qE '^test(\(.*\))?!?:'; then
        echo "test"
    elif echo "$commit_msg" | grep -qE '^build(\(.*\))?!?:'; then
        echo "build"
    elif echo "$commit_msg" | grep -qE '^ci(\(.*\))?!?:'; then
        echo "ci"
    else
        echo "chore"
    fi
}

function get_pr_priority() {
    local type="$1"
    case "$type" in
        "feat") echo 1 ;;
        "fix") echo 2 ;;
        "perf") echo 3 ;;
        "refactor") echo 4 ;;
        "docs") echo 5 ;;
        "style") echo 6 ;;
        "test") echo 7 ;;
        "build") echo 8 ;;
        "ci") echo 9 ;;
        "chore") echo 10 ;;
        *) echo 10 ;;
    esac
}

function get_pr_category_name() {
    local type="$1"
    case "$type" in
        "feat") echo "Features" ;;
        "fix") echo "Fixes" ;;
        "perf") echo "Performance" ;;
        "refactor") echo "Refactoring" ;;
        "docs") echo "Documentation" ;;
        "style") echo "Style" ;;
        "test") echo "Tests" ;;
        "build") echo "Build" ;;
        "ci") echo "CI/CD" ;;
        "chore") echo "Chores" ;;
        *) echo "Chores" ;;
    esac
}

function format_ticket_list() {
    local tickets="$1"
    if [ -n "$tickets" ]; then
        local formatted=$(echo "$tickets" | tr ' ' '\n' | grep -v '^$' | sort -u -t'-' -k2,2n | tr '\n' ' ')
        formatted=$(echo "$formatted" | sed 's/^ *//;s/ *$//')
        if [ -n "$formatted" ]; then
            echo "[$formatted]"
        fi
    fi
}

function validate_arguments() {
    local target="$1"
    case "$target" in
        "stage"|"main")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function get_branch_mapping() {
    local target="$1"
    case "$target" in
        "stage")
            echo "develop stage"
            ;;
        "main")
            echo "stage main"
            ;;
    esac
}

function suggest_alternative_branches() {
    echo "🔍 Available branches in this repository:"
    echo "   Local branches:"
    git branch --format="      %(refname:short)" 2>/dev/null || echo "      (none found)"
    echo "   Remote branches:"
    git branch -r --format="      %(refname:short)" 2>/dev/null || echo "      (none found)"
    echo ""
    echo "💡 Common alternatives:"
    echo "   - For staging: develop → staging, feature → main, main → production"
    echo "   - For production: staging → main, staging → production, release → main"
    echo ""
    echo "🔧 To customize branch names, modify the get_branch_mapping() function in promote-functions.sh"
}

function check_branch_exists() {
    local branch="$1"
    local location="$2"  # "local" or "remote"
    
    if [ "$location" = "local" ]; then
        git show-ref --verify --quiet "refs/heads/$branch"
    else
        git show-ref --verify --quiet "refs/remotes/origin/$branch"
    fi
}

function ensure_remote_branch_available() {
    local branch="$1"
    
    # First check if we have it locally
    if check_branch_exists "$branch" "local"; then
        return 0
    fi
    
    # Try to fetch from remote
    if git fetch origin "$branch:$branch" 2>/dev/null; then
        return 0
    fi
    
    # Check if it exists on remote but we couldn't fetch
    if check_branch_exists "$branch" "remote"; then
        # Try to create local tracking branch
        git checkout -b "$branch" "origin/$branch" 2>/dev/null && git checkout - 2>/dev/null
        return $?
    fi
    
    return 1
}

function validate_promotion_branches() {
    local head_branch="$1"
    local target_branch="$2"
    local dry_run="$3"
    
    local missing_branches=""
    
    # Check head branch
    if ! ensure_remote_branch_available "$head_branch"; then
        missing_branches="$missing_branches $head_branch"
    fi
    
    # Check target branch
    if ! ensure_remote_branch_available "$target_branch"; then
        missing_branches="$missing_branches $target_branch"
    fi
    
    if [ -n "$missing_branches" ]; then
        echo "❌ Error: The following branches are missing:"
        for branch in $missing_branches; do
            echo "   - $branch (not found locally or on origin)"
        done
        echo ""
        suggest_alternative_branches
        echo "📝 To set up the required branches:"
        echo "   1. Create missing branches locally or on the remote"
        echo "   2. Push them to origin: git push origin <branch-name>"
        echo ""
        
        if [ "$dry_run" = "true" ]; then
            echo "🔍 [DRY RUN] Would abort due to missing branches"
        fi
        
        return 1
    fi
    
    return 0
}