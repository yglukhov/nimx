#!/bin/sh

FIREFOX_BIN=firefox
if [ $(uname) = "Darwin" ]
then
    FIREFOX_BIN=/Applications/Firefox.app/Contents/MacOS/firefox
fi

mkdir ./tempprofile
echo 'pref("browser.shell.checkDefaultBrowser", false);' >> ./tempprofile/user.js
echo 'pref("browser.dom.window.dump.enabled", true);' >> ./tempprofile/user.js

run_firefox()
{
    "$FIREFOX_BIN" -profile ./tempprofile $1
}

process_output()
{
    echo 0 > /tmp/auto-test-result
    while read LINE
    do
        if [ "$LINE" = "---AUTO-TEST-QUIT---" ]
        then
            echo "Quitting auto test"
            break
        else
            if [ "$LINE" = "---AUTO-TEST-FAIL---" ]
            then
                echo 1 > /tmp/auto-test-result
            else
                echo $LINE
            fi
        fi
    done

    killall firefox
    rm -rf ./tempprofile
}

run_firefox $1 | process_output
rm -rf ./tempprofile

RESULT=$(cat /tmp/auto-test-result)
rm /tmp/auto-test-result

exit $RESULT
