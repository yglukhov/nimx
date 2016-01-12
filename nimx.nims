import nimx.buildtools

task jsTests, "Build and run autotests in firefox":
    exec "nim js -d:runAutoTests ./test/main.nim"
    exec "./run_test_firefox.sh ./test/main.html"

task tests, "Build and run autotests for current platform":
    --d:runAutoTests
    commonBuild("test/main.nim")
