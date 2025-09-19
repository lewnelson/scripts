#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/promote-functions.sh"

function usage() {
    echo "Usage: $0 [--dry-run] <stage|main>"
    echo "  --dry-run: Show what would be done without making changes"
    echo "  stage:     Promote from develop to stage"
    echo "  main:      Promote from stage to main"
    exit 1
}

function get_repo_name() {
    local repo_url=$(git remote get-url origin)
    echo "$repo_url" | sed -E 's/.*[\/:]([^\/]+\/[^\/]+)\.git$/\1/'
}

# Parse arguments
DRY_RUN=false
target=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        stage|main)
            target="$1"
            shift
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            ;;
    esac
done

# Validate arguments
if [ -z "$target" ]; then
    echo "Error: Target (stage|main) is required"
    usage
fi

case "$target" in
    "stage")
        head_branch="develop"
        target_branch="stage"
        ;;
    "main")
        head_branch="stage"
        target_branch="main"
        ;;
    *)
        echo "Error: Invalid target '$target'"
        usage
        ;;
esac

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN MODE - No changes will be made"
    echo "============================================"
fi

echo "Promoting from $head_branch to $target_branch..."

repo_name=$(get_repo_name)
echo "Repository: $repo_name"

echo "Fetching latest changes from origin..."
git fetch origin

echo "Validating branches..."
if ! validate_promotion_branches "$head_branch" "$target_branch" "$DRY_RUN"; then
    exit 1
fi

existing_pr=$(gh pr list --repo "$repo_name" --head "$head_branch" --base "$target_branch" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")

commits_in_promotion=$(git log "origin/$target_branch..origin/$head_branch" --oneline --format="%H %s" 2>/dev/null || echo "")

if [ -z "$commits_in_promotion" ]; then
    echo "No commits to promote from $head_branch to $target_branch"
    exit 0
fi

echo "Found $(echo "$commits_in_promotion" | wc -l | tr -d ' ') commits to promote"

# Extract all tickets from commit messages
all_tickets=""
while IFS= read -r line; do
    if [ -n "$line" ]; then
        commit_msg=$(echo "$line" | cut -d' ' -f2-)
        tickets=$(extract_linear_tickets "$commit_msg")
        if [ -n "$tickets" ]; then
            all_tickets="$all_tickets $tickets"
        fi
    fi
done <<< "$commits_in_promotion"

# Remove duplicates and sort
unique_tickets=$(echo "$all_tickets" | tr ' ' '\n' | grep -v '^$' | sort -u -t'-' -k2,2n | tr '\n' ' ')
unique_tickets=$(echo "$unique_tickets" | sed 's/^ *//;s/ *$//')

if [ -n "$unique_tickets" ]; then
    ticket_list="[$unique_tickets]"
else
    ticket_list=""
fi

pr_title="$head_branch -> $target_branch $ticket_list"

# Simple PR body with commit list
pr_body="# Changes"$'\n\n'
counter=1
while IFS= read -r line; do
    if [ -n "$line" ]; then
        commit_msg=$(echo "$line" | cut -d' ' -f2-)
        commit_hash=$(echo "$line" | cut -d' ' -f1 | cut -c1-7)
        pr_body="$pr_body$counter. $commit_msg ($commit_hash)"$'\n'
        counter=$((counter + 1))
    fi
done <<< "$commits_in_promotion"

if [ -n "$existing_pr" ]; then
    echo "Updating existing PR #$existing_pr..."
    echo "Title: $pr_title"
    echo ""
    echo "Body:"
    echo "$pr_body"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 [DRY RUN] Would execute: gh pr edit $existing_pr --repo $repo_name --title \"$pr_title\" --body <body>"
        echo "🔍 [DRY RUN] Would execute: gh pr view $existing_pr --repo $repo_name --web"
    else
        gh pr edit "$existing_pr" --repo "$repo_name" --title "$pr_title" --body "$pr_body"
        echo "Updated PR #$existing_pr"
        gh pr view "$existing_pr" --repo "$repo_name" --web
    fi
else
    echo "Creating new PR..."
    echo "Title: $pr_title"
    echo ""
    echo "Body:"
    echo "$pr_body"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo "🔍 [DRY RUN] Would execute: gh pr create --repo $repo_name --head $head_branch --base $target_branch --title \"$pr_title\" --body <body>"
        echo "🔍 [DRY RUN] Would execute: gh pr view <new-pr-url> --web"
        echo "🔍 [DRY RUN] New PR would be created at: https://github.com/$repo_name/compare/$target_branch...$head_branch"
    else
        new_pr=$(gh pr create --repo "$repo_name" --head "$head_branch" --base "$target_branch" --title "$pr_title" --body "$pr_body")
        echo "Created PR: $new_pr"
        echo "$new_pr" | xargs gh pr view --web
    fi
fi

# Cleanup
rm -f /tmp/promote_* 2>/dev/null || true