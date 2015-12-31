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

task tests, "Build and run tests for":
    setCommand "c", "test/main.nim"
