#!/bin/sh

CUR_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "Current branch: $CUR_BRANCH"

if [ "$CUR_BRANCH" = "master" -a "$GH_KEY" = "" ]
then
    echo "Error: GH_KEY not set"
    exit 1
fi

if [ "$GH_KEY" \!= "" ]
then
    echo "GH_KEY is present"

    cd "$1"
    git init

    git config user.name "Travis CI"
    git config user.email "yuriy.glukhov@gmail.com"

    git add .

    git commit -m "Deploy to GitHub Pages"

    git push --force --quiet "https://$GH_KEY@github.com/$TRAVIS_REPO_SLUG" master:gh-pages > /dev/null 2>&1
fi
