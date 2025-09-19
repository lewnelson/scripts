#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/promote-functions.sh"

function usage() {
    echo "Usage: $0 [--dry-run] [--linear-org=<org>] [--linear-identifier=<id>]... <stage|main>"
    echo "  --dry-run:                    Show what would be done without making changes"
    echo "  --linear-org=<org>:           Linear organization name for ticket links (required)"
    echo "  --linear-identifier=<id>:     Linear ticket identifier (e.g., ENG, DEV). Can be used multiple times (required)"
    echo "  stage:                        Promote from develop to stage"
    echo "  main:                         Promote from stage to main"
    exit 1
}

function get_repo_name() {
    local repo_url=$(git remote get-url origin)
    echo "$repo_url" | sed -E 's/.*[\/:]([^\/]+\/[^\/]+)\.git$/\1/'
}

# Parse arguments
DRY_RUN=false
LINEAR_ORG=""
LINEAR_IDENTIFIERS=""
target=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --linear-org=*)
            LINEAR_ORG="${1#*=}"
            shift
            ;;
        --linear-identifier=*)
            identifier="${1#*=}"
            if [ -n "$identifier" ]; then
                if [ -z "$LINEAR_IDENTIFIERS" ]; then
                    LINEAR_IDENTIFIERS="$identifier"
                else
                    LINEAR_IDENTIFIERS="$LINEAR_IDENTIFIERS $identifier"
                fi
            fi
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

if [ -z "$LINEAR_ORG" ]; then
    echo "Error: --linear-org is required"
    echo "Example: $0 --linear-org=mazedesignhq --linear-identifier=ENG stage"
    usage
fi

if [ -z "$LINEAR_IDENTIFIERS" ]; then
    echo "Error: At least one --linear-identifier is required"
    echo "Example: $0 --linear-org=mazedesignhq --linear-identifier=ENG --linear-identifier=DEV stage"
    usage
fi

# Deduplicate identifiers and convert to uppercase
LINEAR_IDENTIFIERS=$(echo "$LINEAR_IDENTIFIERS" | tr ' ' '\n' | tr '[:lower:]' '[:upper:]' | sort -u | tr '\n' ' ' | sed 's/ $//')

echo "Using Linear identifiers: $LINEAR_IDENTIFIERS"

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

echo "Finding merged PRs for promotion..."

# Create temporary files for PR data
pr_data_file=$(mktemp)
tickets_file=$(mktemp)

# Find all merged PRs in the commit range
while IFS= read -r line; do
    if [ -n "$line" ]; then
        commit_hash=$(echo "$line" | cut -d' ' -f1)
        
        # Find PR that contains this commit
        pr_number=$(gh pr list --repo "$repo_name" --search "$commit_hash" --state merged --json number --jq '.[0].number' 2>/dev/null || echo "")
        
        if [ -n "$pr_number" ] && ! grep -q "^$pr_number:" "$pr_data_file" 2>/dev/null; then
            echo "Processing PR #$pr_number..."
            
            # Get PR details
            pr_title=$(gh pr view "$pr_number" --repo "$repo_name" --json title --jq '.title')
            pr_body=$(gh pr view "$pr_number" --repo "$repo_name" --json body --jq '.body')
            
            # Get all commits from this PR to determine type
            pr_commits=$(gh pr view "$pr_number" --repo "$repo_name" --json commits --jq '.commits[].messageHeadline')
            
            # Determine PR type based on commits (highest priority wins)
            pr_type="chore"
            best_priority=100
            
            while IFS= read -r commit_msg; do
                if [ -n "$commit_msg" ]; then
                    commit_type=$(get_commit_type "$commit_msg")
                    commit_priority=$(get_pr_priority "$commit_type")
                    
                    if [ "$commit_priority" -lt "$best_priority" ]; then
                        pr_type="$commit_type"
                        best_priority="$commit_priority"
                    fi
                fi
            done <<< "$pr_commits"
            
            # Extract tickets from PR title, body, and commits
            all_pr_text="$pr_title $pr_body $pr_commits"
            pr_tickets=$(extract_linear_tickets "$all_pr_text" "$LINEAR_IDENTIFIERS")
            
            if [ -n "$pr_tickets" ]; then
                echo "$pr_tickets" >> "$tickets_file"
            fi
            
            # Store PR data: pr_number:type:tickets:title
            echo "$pr_number:$pr_type:$pr_tickets:$pr_title" >> "$pr_data_file"
        fi
    fi
done <<< "$commits_in_promotion"

# Check if we found any PRs
if [ ! -s "$pr_data_file" ]; then
    echo "No merged PRs found in commit range"
    exit 0
fi

echo "Found $(wc -l < "$pr_data_file" | tr -d ' ') merged PRs to promote"

# Remove duplicates and sort tickets
# Build regex pattern for all identifiers
identifier_pattern=""
for identifier in $LINEAR_IDENTIFIERS; do
    upper_identifier=$(echo "$identifier" | tr '[:lower:]' '[:upper:]')
    if [ -z "$identifier_pattern" ]; then
        identifier_pattern="^$upper_identifier-[0-9][0-9]*$"
    else
        identifier_pattern="$identifier_pattern|^$upper_identifier-[0-9][0-9]*$"
    fi
done

all_tickets=$(cat "$tickets_file" | tr ' ' '\n' | grep -E "$identifier_pattern" | sort -u -t'-' -k1,1 -k2,2n | tr '\n' ' ')
unique_tickets=$(echo "$all_tickets" | sed 's/^ *//;s/ *$//')

if [ -n "$unique_tickets" ]; then
    ticket_list="[$unique_tickets]"
else
    ticket_list=""
fi

pr_title="$head_branch -> $target_branch $ticket_list"

# Generate PR body categorized by type
pr_body_file=$(mktemp)

# Process each type in priority order
for type in feat fix perf refactor docs style test build ci chore; do
    # Check if this type has any PRs
    type_prs=$(grep "^[^:]*:$type:" "$pr_data_file" 2>/dev/null || echo "")
    
    if [ -n "$type_prs" ]; then
        category_name=$(get_pr_category_name "$type")
        echo "# $category_name" >> "$pr_body_file"
        echo "" >> "$pr_body_file"
        
        # Create temporary file for sorting this type's PRs
        type_prs_file=$(mktemp)
        
        echo "$type_prs" | while IFS=':' read -r pr_number pr_type pr_tickets pr_title_text; do
            if [ -n "$pr_tickets" ]; then
                # Sort by first ticket number
                first_ticket=$(echo "$pr_tickets" | cut -d' ' -f1)
                ticket_num=$(echo "$first_ticket" | sed 's/ENG-//')
                echo "$ticket_num:$pr_number:$pr_tickets:$pr_title_text" >> "$type_prs_file"
            else
                # PRs without tickets go at the end
                echo "99999:$pr_number::$pr_title_text" >> "$type_prs_file"
            fi
        done
        
        # Sort and format PRs for this type
        sorted_prs_file=$(mktemp)
        sort -t':' -k1,1n "$type_prs_file" > "$sorted_prs_file"
        
        counter=1
        while IFS=':' read -r sort_key pr_number pr_tickets pr_title_text; do
            if [ -n "$pr_tickets" ]; then
                # Format tickets as links
                ticket_links=""
                for ticket in $pr_tickets; do
                    if [ -n "$ticket_links" ]; then
                        ticket_links="$ticket_links, "
                    fi
                    ticket_links="$ticket_links[$ticket](https://linear.app/$LINEAR_ORG/issue/$ticket)"
                done
                echo "$counter. $ticket_links - $pr_title_text (#$pr_number)" >> "$pr_body_file"
            else
                echo "$counter. $pr_title_text (#$pr_number)" >> "$pr_body_file"
            fi
            counter=$((counter + 1))
        done < "$sorted_prs_file"
        
        rm -f "$sorted_prs_file"
        
        echo "" >> "$pr_body_file"
        rm -f "$type_prs_file"
    fi
done

# Read the generated PR body
pr_body=$(cat "$pr_body_file")
rm -f "$pr_body_file"

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
rm -f "$pr_data_file" "$tickets_file" 2>/dev/null || true
rm -f /tmp/promote_* 2>/dev/null || true