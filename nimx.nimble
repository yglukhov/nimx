[Package]
name = "nimx"
version = "0.1"
author = "Yuriy Glukhov"
description = "GUI framework"
license = "BSD"

[Dependencies]
Requires: "sdl2"
Requires: "opengl"
Requires: "nake"
Requires: "closure_compiler"

# Jester is required to run a web server from the nakefile to serve WebGL variant
Requires: "jester"
Requires: "https://github.com/yglukhov/ttf"
