#!/bin/sh

# This script requires GH_KEY environment variable to be set to Github access
# token. The token may be generated at https://github.com/settings/tokens and
# has to have permissions to commit (e.g. public_repo)

# The variable itself then has to be set in travis-ci project settings.

if [ "$GH_KEY" \!= "" ]
then
    export GIT_DIR=/tmp/gh-pages.tmp
    rm -rf "$GIT_DIR"
    mkdir -p "$GIT_DIR"

    cd "$1"
    export GIT_WORK_TREE=$(pwd)
    git init

    git config user.name "Travis CI"
    git config user.email "autodocgen@example.com"

    git add .

    git commit -m "Deploy to GitHub Pages"

    git push --force --quiet "https://$GH_KEY@github.com/$TRAVIS_REPO_SLUG" master:gh-pages > /dev/null 2>&1
fi
