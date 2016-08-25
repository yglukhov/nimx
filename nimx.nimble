# Package

version     = "0.1"
author      = "Yuriy Glukhov"
description = "GUI framework"
license     = "BSD"

# Directory configuration

skipDirs    = @["test/build", "build"]

# Dependencies

requires "sdl2"
requires "opengl"
requires "nimsl >= 0.2 & < 0.3"
requires "jnim" # For android target
requires "nake"
requires "closure_compiler >= 0.2 & < 0.3"
requires "plists"
requires "variant >= 0.2 & < 0.3"

requires "jester" # required to run a web server from the nakefile to serve WebGL variant
requires "https://github.com/yglukhov/ttf >= 0.2.1 & < 0.3"
requires "https://github.com/yglukhov/async_http_request"
requires "https://github.com/yglukhov/emscripten.nim"
