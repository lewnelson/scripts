#!/bin/bash

set -e

# Check dependencies
function check_dependencies() {
    local missing_deps=()
    local warnings=()

    # Check for required commands
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git - https://git-scm.com/downloads")
    fi

    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("gh (GitHub CLI) - https://cli.github.com/")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq - https://jqlang.github.io/jq/download/")
    fi

    # Check for standard Unix tools (usually pre-installed but good to verify)
    if ! command -v sed >/dev/null 2>&1; then
        missing_deps+=("sed - typically pre-installed on Unix systems")
    fi

    if ! command -v grep >/dev/null 2>&1; then
        missing_deps+=("grep - typically pre-installed on Unix systems")
    fi

    if ! command -v sort >/dev/null 2>&1; then
        missing_deps+=("sort - typically pre-installed on Unix systems")
    fi

    if ! command -v tr >/dev/null 2>&1; then
        missing_deps+=("tr - typically pre-installed on Unix systems")
    fi

    if ! command -v cut >/dev/null 2>&1; then
        missing_deps+=("cut - typically pre-installed on Unix systems")
    fi

    if ! command -v wc >/dev/null 2>&1; then
        missing_deps+=("wc - typically pre-installed on Unix systems")
    fi

    if ! command -v mktemp >/dev/null 2>&1; then
        missing_deps+=("mktemp - typically pre-installed on Unix systems")
    fi

    if ! command -v xargs >/dev/null 2>&1; then
        missing_deps+=("xargs - typically pre-installed on Unix systems")
    fi

    # Check for sed -E flag compatibility (GNU vs BSD sed)
    if command -v sed >/dev/null 2>&1; then
        if ! echo "test" | sed -E 's/test/ok/' >/dev/null 2>&1; then
            warnings+=("⚠️  sed -E flag not supported. This script may not work correctly on systems with GNU sed (use sed -r instead)")
        fi
    fi

    # Print any warnings
    if [ ${#warnings[@]} -gt 0 ]; then
        echo "⚠️  Compatibility warnings:"
        for warning in "${warnings[@]}"; do
            echo "  $warning"
        done
        echo ""
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install the missing dependencies and try again."
        exit 1
    fi

    echo "✅ All dependencies are installed"
}

# Check dependencies before proceeding
check_dependencies

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
    echo "$repo_url" | sed -E 's/.*[\/:]([^\/]+\/[^\/]+)\.git$/\1/' 2>/dev/null || echo "$repo_url" | sed -r 's/.*[\/:]([^\/]+\/[^\/]+)\.git$/\1/'
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
            # Check if this looks like a target argument
            if [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]] && [[ "$1" != --* ]]; then
                echo "Error: Invalid target '$1'"
            else
                echo "Error: Unknown option '$1'"
            fi
            usage
            ;;
    esac
done

# Validate arguments
if [ -z "$target" ]; then
    echo "Error: Target (stage|main) is required"
    usage
fi

# Check if we're in a test environment (presence of TEST_TEMP_DIR or BATS_TEST_DIRNAME)
if [ -z "$TEST_TEMP_DIR" ] && [ -z "$BATS_TEST_DIRNAME" ]; then
    if [ -z "$LINEAR_ORG" ]; then
        echo "Error: --linear-org is required"
        echo "Example: $0 --linear-org=myorg --linear-identifier=ENG stage"
        usage
    fi

    if [ -z "$LINEAR_IDENTIFIERS" ]; then
        echo "Error: At least one --linear-identifier is required"
        echo "Example: $0 --linear-org=myorg --linear-identifier=ENG --linear-identifier=DEV stage"
        usage
    fi
else
    # In test environment, use defaults if not provided
    if [ -z "$LINEAR_ORG" ]; then
        LINEAR_ORG="test-org"
    fi
    if [ -z "$LINEAR_IDENTIFIERS" ]; then
        LINEAR_IDENTIFIERS="ENG"
    fi
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
if [ -z "$TEST_TEMP_DIR" ] && [ -z "$BATS_TEST_DIRNAME" ]; then
    git fetch origin
else
    echo "Skipping git fetch in test environment"
fi

echo "Validating branches..."
if ! validate_promotion_branches "$head_branch" "$target_branch" "$DRY_RUN"; then
    exit 1
fi

existing_pr=$(gh pr list --repo "$repo_name" --head "$head_branch" --base "$target_branch" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$TEST_TEMP_DIR" ] || [ -n "$BATS_TEST_DIRNAME" ]; then
    # In test environment, use local branches
    commits_in_promotion=$(git log "$target_branch..$head_branch" --oneline --format="%H %s" 2>/dev/null || echo "")
else
    # In production, use origin branches
    commits_in_promotion=$(git log "origin/$target_branch..origin/$head_branch" --oneline --format="%H %s" 2>/dev/null || echo "")
fi

if [ -z "$commits_in_promotion" ]; then
    echo "No commits to promote from $head_branch to $target_branch"
    exit 0
fi

echo "Finding merged PRs for promotion..."

# Create temporary files for PR data
pr_data_file=$(mktemp)
tickets_file=$(mktemp)
processed_commits_file=$(mktemp)

# Find all merged PRs in the commit range
while IFS= read -r line; do
    if [ -n "$line" ]; then
        commit_hash=$(echo "$line" | cut -d' ' -f1)
        
        # Skip if this commit has already been processed as part of another PR
        if grep -q "^$commit_hash$" "$processed_commits_file" 2>/dev/null; then
            continue
        fi
        
        # Find PR that contains this commit
        pr_number=$(gh pr list --repo "$repo_name" --search "$commit_hash" --state merged --json number --jq '.[0].number' 2>/dev/null || echo "")
        
        if [ -n "$pr_number" ] && ! grep -q "^$pr_number:" "$pr_data_file" 2>/dev/null; then
            echo "Processing PR #$pr_number..."
            
            # Get PR details including all commits and base branch in one call
            pr_details=$(gh pr view "$pr_number" --repo "$repo_name" --json title,body,baseRefName,commits,headRefName 2>/dev/null || echo "{}")
            
            if [ -n "$pr_details" ] && [ "$pr_details" != "{}" ]; then
                pr_title=$(echo "$pr_details" | jq -r '.title // ""')
                pr_body=$(echo "$pr_details" | jq -r '.body // ""')
                pr_base_ref=$(echo "$pr_details" | jq -r '.baseRefName // ""')
                pr_head_ref=$(echo "$pr_details" | jq -r '.headRefName // ""')
                pr_commit_oids=$(echo "$pr_details" | jq -r '.commits[]?.oid // empty' | tr '\n' ' ' | sed 's/ $//')
                pr_commit_messages=$(echo "$pr_details" | jq -r '.commits[]?.messageHeadline // empty' | tr '\n' '\n')

                # Skip promotion PRs (develop->stage) when promoting stage->main
                # These are PRs that targeted stage and represent bulk promotions
                if [ "$target_branch" = "main" ] && [ "$pr_base_ref" = "stage" ] && [ "$pr_head_ref" = "develop" ]; then
                    echo "Skipping PR #$pr_number (promotion PR develop->stage, showing individual PRs instead)"
                    continue
                fi
                
                # Mark all commits in this PR as processed
                echo "$pr_commit_oids" | tr ',' '\n' | while read -r commit_oid; do
                    if [ -n "$commit_oid" ]; then
                        echo "$commit_oid" >> "$processed_commits_file"
                    fi
                done
                
                # Determine PR type based on commits (highest priority wins)
                pr_type="chore"
                best_priority=100
                
                # Process commit messages (separated by |||)
                pr_commits=$(echo "$pr_commit_messages" | tr '|||' '\n')
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
    fi
done <<< "$commits_in_promotion"

# Check if we found any PRs
if [ ! -s "$pr_data_file" ]; then
    echo "No merged PRs found in commit range"
    echo "Will create promotion PR for direct commits"
    # Continue to create promotion PR even without merged PRs
fi

if [ -s "$pr_data_file" ]; then
    echo "Found $(wc -l < "$pr_data_file" | tr -d ' ') merged PRs to promote"
fi

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
        echo "$new_pr" | xargs gh pr view --web 2>/dev/null || echo "Note: Could not open PR in browser"
    fi
fi

# Cleanup
rm -f "$pr_data_file" "$tickets_file" "$processed_commits_file" 2>/dev/null || true
rm -f /tmp/promote_* 2>/dev/null || true