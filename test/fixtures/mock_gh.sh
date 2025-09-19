#!/bin/bash

# Comprehensive mock for GitHub CLI
# This script simulates gh commands for testing without requiring actual GitHub access

case "$*" in
    # PR list commands - check for existing PRs
    "pr list --repo test/repo --head develop --base stage --state open --json number --jq .[0].number")
        echo ""  # No existing PR
        ;;
    "pr list --repo test/repo --head stage --base main --state open --json number --jq .[0].number")
        echo ""  # No existing PR
        ;;
    "pr list --repo"*"--head"*"--base"*"--state open --json number --jq .[0].number")
        echo ""  # Generic: no existing PR
        ;;
    
    # PR search commands - find PRs by commit hash
    "pr list --repo test/repo --search abc123"*"--state merged --json number --jq .[0].number")
        echo "123"
        ;;
    "pr list --repo test/repo --search def456"*"--state merged --json number --jq .[0].number")
        echo "123"
        ;;
    "pr list --repo test/repo --search ghi789"*"--state merged --json number --jq .[0].number")
        echo "124"
        ;;
    "pr list --repo test/repo --search jkl012"*"--state merged --json number --jq .[0].number")
        echo "125"
        ;;
    "pr list --repo test/repo --search mno345"*"--state merged --json number --jq .[0].number")
        echo "126"
        ;;
    "pr list --repo test/repo --search pqr678"*"--state merged --json number --jq .[0].number")
        echo "126"
        ;;
    "pr list --repo"*"--search"*"--state merged --json number --jq .[0].number")
        echo ""  # Generic: no PR found for unknown commits
        ;;
    
    # PR view commands - get PR details
    "pr view 123 --repo test/repo --json title --jq .title")
        echo "feat: add user authentication [ENG-456]"
        ;;
    "pr view 123 --repo test/repo --json body --jq .body")
        echo "This PR implements user authentication functionality.

Includes:
- Login form
- JWT token handling
- Session management

Related to [ENG-456]"
        ;;
    "pr view 124 --repo test/repo --json title --jq .title")
        echo "fix: resolve memory leak in auth module"
        ;;
    "pr view 124 --repo test/repo --json body --jq .body")
        echo "Fixes memory leak that was causing performance issues.

Fixes [ENG-123]"
        ;;
    "pr view 125 --repo test/repo --json title --jq .title")
        echo "chore: update dependencies"
        ;;
    "pr view 125 --repo test/repo --json body --jq .body")
        echo "Updates various dependencies to latest versions.

No specific ticket associated."
        ;;
    "pr view 126 --repo test/repo --json title --jq .title")
        echo "refactor: restructure auth components [ENG-789]"
        ;;
    "pr view 126 --repo test/repo --json body --jq .body")
        echo "Refactors authentication components for better maintainability.

See [ENG-789] for details."
        ;;
    
    # PR creation
    "pr create --repo test/repo"*)
        echo "https://github.com/test/repo/pull/999"
        ;;
    
    # PR editing
    "pr edit"*"--repo test/repo"*)
        echo "✓ Pull request #456 edited"
        ;;
    
    # PR view web - just succeed silently
    "pr view"*"--web")
        # Do nothing, just succeed
        ;;
    
    # Catch-all for debugging
    *)
        echo "Mock gh: Unknown command pattern: $*" >&2
        echo "Args: $@" >&2
        exit 1
        ;;
esac

exit 0