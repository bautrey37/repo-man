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

# Parse command line arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run|-n)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--dry-run|-n] [--help|-h]"
      echo "  --dry-run, -n    Show what would be deleted without actually deleting"
      echo "  --help, -h       Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

SALEMOVE=~/salemove

if [[ $DRY_RUN == true ]]; then
  echo -e "${YELLOW}DRY RUN MODE - No repositories will be deleted${NC}"
  echo -e "${YELLOW}==============================================${NC}"
fi

for dir in $SALEMOVE/*
do
  repo="$(basename $dir)"

  archived=$(gh repo view salemove/${repo} --json isArchived | jq -r '.isArchived')

  if [[ $archived == 'true' ]]
  then
    echo -e "${BLUE}Repo $repo is archived${NC}"
    if [[ $DRY_RUN == true ]]; then
      echo -e "${CYAN}DRY RUN: Would delete repo at $SALEMOVE/$repo${NC}"
    else
      echo -e "${PURPLE}Deleting repo...${NC}"
      $(rm -rf $SALEMOVE/$repo)
      echo -e "${GREEN}Done deleting${NC}"
    fi
  fi
done

if [[ $DRY_RUN == true ]]; then
  echo -e "${YELLOW}==============================================${NC}"
  echo -e "${YELLOW}DRY RUN MODE - No repositories were deleted${NC}"
fi
