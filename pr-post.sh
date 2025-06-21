# Author - Henry Black https://github.com/blackhaj

#!/bin/zsh

# Prerequisites:
# - fzf needs to be installed
# - gh needs to be installed
# - pr-post.js needs to be next to this script

# Fuzzy find git branch. Mostly stolen from: https://polothy.github.io/post/2019-08-19-fzf-git-checkout/
fzf-git-branch() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    git branch --color=always --sort=-committerdate |
        grep -v HEAD |
        fzf --height 50% --ansi --no-multi --preview-window right:65% \
            --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' |
        sed "s/.* //"
}

branch=$(fzf-git-branch)

if [[ "$branch" = "" ]]; then
    echo "No branches available. Run command from a valid github repo"
    return
fi

# Get the PR data from Github
pr_data=$(gh pr view --json title,body,files,comments,url $branch)

if [[ $pr_data = "" ]]; then
    echo "Exiting"
    return
fi

# Find current working directory as the node script should be next to it
cwd=(${${(%):-%x}:A:h})

formatted_message=$(node "$cwd/pr-post.js" "$pr_data")

echo "$formatted_message" | pbcopy
