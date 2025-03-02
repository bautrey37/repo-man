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

  if [[ $archived == 'true' ]]
  then
    echo "Repo $repo is archived"
  fi

  if [[ $branch != 'master' ]]
  then
    echo "Repo \"$repo\" current branch: \"$branch\""
  fi

  # if [[ $updatedAt < $(date ) ]]
  # then
  #   echo "Repo $repo is archived"
  # fi

done
