#!/bin/sh

echo "deployGHPages called"

if [ "$GH_KEY" \!= "" ]
then
    echo "GH_KEY IS PRESENT"

    cd "$1"
    rm -rf ./.git

    echo "DOCS CONTENT: "
    ls -l
    echo "END"

    echo "TRAVIS_REPO_SLUG: $TRAVIS_REPO_SLUG"

    git init

    git config user.name "Travis CI"
    git config user.email "yuriy.glukhov@gmail.com"

    git add .

    git commit -m "Deploy to GitHub Pages"

    git push --force --quiet "https://$GH_KEY@github.com/$TRAVIS_REPO_SLUG" master:gh-pages > /dev/null 2>&1
fi
