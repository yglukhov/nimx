version = "0.1"
author = "Yuriy Glukhov"
description = "GUI framework"
license = "BSD"

skipDirs.add "test/android/com.mycompany.MyGame"

# Dependencies
requires "sdl2"
requires "opengl"
requires "nimsl"
requires "jnim" # For android target
requires "nake"
requires "closure_compiler"

# Jester is required to run a web server from the nakefile to serve
# WebGL variant
requires "jester"
requires "https://github.com/yglukhov/ttf"
requires "https://github.com/yglukhov/async_http_request"

proc commonSetup() =
    --threads:on
    --noMain
    --run
    switch("path", ".") # because of Nimble bug

task example, "Built and run example":
    commonSetup()
    setCommand "c", "test/main.nim"

task tests, "Build and run tests":
    commonSetup()
    --d:runAutoTests
    setCommand "c", "test/main.nim"
