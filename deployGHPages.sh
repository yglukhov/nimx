#!/bin/sh

if [ "$GH_KEY" \!= "" ]
then
    cd "$1"
    git init

    git config user.name "Travis CI"
    git config user.email "yuriy.glukhov@gmail.com"

    echo ls
    ls -la

    git add .
    git add livedemo

    echo ls livedemo
    ls -la livedemo

    git commit -m "Deploy to GitHub Pages"

    git push --force --quiet "https://$GH_KEY@github.com/$TRAVIS_REPO_SLUG" master:gh-pages > /dev/null 2>&1
fi
