# Package

version     = "0.1"
author      = "Yuriy Glukhov"
description = "GUI framework"
license     = "BSD"

# Directory configuration

skipDirs    = @["test/build"]

# Dependencies

requires "sdl2"
requires "opengl"
requires "nimsl"
requires "jnim" # For android target
requires "nake"
requires "closure_compiler"
requires "plists"

# Jester is required to run a web server from the nakefile to serve WebGL variant

requires "jester"
requires "https://github.com/yglukhov/ttf"
requires "https://github.com/yglukhov/async_http_request"
