import oswalkdir, strutils
import nimx.buildtools

task jsTests, "Build and run autotests in firefox":
    exec "nim js -d:runAutoTests ./test/main.nim"
    exec "./run_test_firefox.sh ./test/main.html"

task samples, "Build samples":
    commonBuild("test/main.nim")

task tests, "Build and run autotests for current platform":
    --d:runAutoTests
    commonBuild("test/main.nim")

task docs, "Build documentation":
    withDir "./doc":
        for t, f in walkDir "../nimx":
            if f.endsWith(".nim"):
                try:
                    exec "nim doc2 -d:js " & f
                except:
                    discard

        for t, f in walkDir ".":
            if f.endsWith(".rst"):
                try:
                    exec "nim rst2html " & f
                except:
                    discard

        mkDir "./livedemo"
        cpDir "../test/build/js", "./livedemo"
