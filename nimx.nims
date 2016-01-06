import nimx.buildtools

task tests, "Build and run examples for current platform":
    --d:runAutoTests
    commonBuild("test/main.nim")
