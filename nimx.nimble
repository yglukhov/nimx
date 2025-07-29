# Package

version     = "0.3"
author      = "Yuriy Glukhov"
description = "GUI framework"
license     = "MIT"

# Directory configuration
installDirs = @["nimx", "assets"]

# Dependencies

requires "sdl2"
requires "opengl"
requires "winim"
requires "nimsl >= 0.3"
requires "jnim" # For android target
requires "nake"
requires "plists"
requires "variant >= 0.3"
requires "kiwi"
requires "https://github.com/yglukhov/ttf >= 0.2.9"
requires "https://github.com/yglukhov/async_http_request"
requires "jsbind"
requires "rect_packer"
requires "android"
requires "darwin"
requires "os_files"
requires "https://github.com/tormund/nester"
requires "nimwebp"
requires "https://github.com/yglukhov/clipboard"
