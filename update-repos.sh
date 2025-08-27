#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

SALEMOVE=~/salemove

for dir in $SALEMOVE/*
do
  isGitRepo=$(git -C ${dir} rev-parse 2>/dev/null; echo $?)
  if [[ $isGitRepo != 0 ]]
  then
    echo -e "${GRAY}Ignore $repo${NC}"
    continue
  fi

  repo="$(basename $dir)"

  # status=$(gh repo view salemove/${repo} --json isArchived,updatedAt)
  # archived=$(${status} | jq -r '.isArchived')
  # updatedAt=$(date -d ${status} | jq -r '.updatedAt')
  branch=$(git -C ${dir} symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

  if [ "$branch" != 'master' ] && [ "$branch" != 'main' ]
  then
    echo -e "${YELLOW}Repo \"$repo\" current branch: \"$branch\"${NC}"
  else
    echo -e "${BLUE}Updating repo \"$repo\" on branch \"$branch\"...${NC}"

    # Get the current commit hash before pulling
    before_commit=$(git -C ${dir} rev-parse HEAD)

    # Perform the pull
    pull_output=$(git -C ${dir} pull 2>&1)
    pull_status=$?

    if [ $pull_status -eq 0 ]; then
      # Get the current commit hash after pulling
      after_commit=$(git -C ${dir} rev-parse HEAD)

      if [ "$before_commit" = "$after_commit" ]; then
        echo -e "${GRAY}Already up to date${NC}"
      else
        # Count the number of new commits
        commit_count=$(git -C ${dir} rev-list --count ${before_commit}..${after_commit})

        # Get a brief summary of changes
        if [ $commit_count -gt 0 ]; then
          echo -e "${GREEN}Updated: $commit_count new commit(s)${NC}"
          # Show the latest commit message
          latest_commit=$(git -C ${dir} log -1 --pretty=format:"  Latest: %s (%an)")
          echo -e "${CYAN}$latest_commit${NC}"
        fi
      fi
    else
      echo -e "${RED}Pull failed: $pull_output${NC}"
    fi

    echo -e "${PURPLE}Done updating${NC}"

    # todo: test is master is up to date, then do not update.
  fi
done
