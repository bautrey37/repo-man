SALEMOVE=~/salemove

for dir in $SALEMOVE/*
do
  isGitRepo=$(git -C ${dir} rev-parse 2>/dev/null; echo $?)
  if [[ $isGitRepo != 0 ]]
  then
    echo "Ignore $repo"
    continue
  fi

  repo="$(basename $dir)"

  # status=$(gh repo view salemove/${repo} --json isArchived,updatedAt)
  # archived=$(${status} | jq -r '.isArchived')
  # updatedAt=$(date -d ${status} | jq -r '.updatedAt')
  branch=$(git -C ${dir} symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

  if [[ $branch != 'master' ]]
  then
    echo "Repo \"$repo\" current branch: \"$branch\""
  else
    echo "Updating repo \"$repo\" master branch..."
    git -C ${dir} pull
    echo "Done updating"

    # todo: test is master is up to date, then do not update.
    # todo: provide shortened summary of update, like number of commits. 
  fi
done
