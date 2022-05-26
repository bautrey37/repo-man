SALEMOVE=~/salemove

for dir in $SALEMOVE/*
do
  repo="$(basename $dir)"
  # echo "Repo $repo"

  archived=$(gh repo view salemove/${repo} --json isArchived | jq -r '.isArchived')

  if [[ $archived == 'true' ]]
  then
    echo "Repo $repo is archived"
    echo "Deleting repo..."
    $(rm -rf $SALEMOVE/$repo)
    echo "Done deleting"
  fi
done
