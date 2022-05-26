for r in $(gh repo list salemove -L 300 --json name,isArchived,isFork,isPrivate -q '.[] | select( .isFork == false ) | select( .isArchived == false ) | .name'); do git clone --single-branch --no-tags --depth 1 git@github.com:salemove/$r; done
cloc .
