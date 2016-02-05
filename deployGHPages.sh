#!/bin/sh

if [ "$GH_KEY" \!= "" ]
then
    cd "$1"
    git init

    git config user.name "Travis CI"
    git config user.email "yuriy.glukhov@gmail.com"

    git add .
    git commit -m "Deploy to GitHub Pages"

    git push --force --quiet "https://$GH_KEY@github.com/$TRAVIS_REPO_SLUG" master:gh-pages > /dev/null 2>&1
fi
