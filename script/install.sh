#!/bin/sh

set -e
# set -x # for debug

parse_git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1) /'
}
parse_commit_hash() {
  git log -1 | head -1
}
sync_folders() {
  rsync -rP --delete --exclude=modules --exclude=.git $1/ $2/ >/dev/null
}

COMMIT_LOG="`parse_git_branch`: `parse_commit_hash`"

# dev installation
dev_installation=`pwd`
git pull
git push


installer=/var/tmp/infocoin-installer
cd $installer

# sync w github
cd github
git pull

# heroku
cd ../heroku
#git pull

echo "Prepare backend"
cd ../github
sync_folders Backend ../heroku

#echo "Prepare frontend"
#cd Frontend
#npm install
#npm run build
#cd ..
#sync_folders Frontend/dist ../heroku/public

echo "Commit & push"
cd ../heroku
git add .
git commit -m "$COMMIT_LOG"
git push
