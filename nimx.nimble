[Package]
name = "nimx"
version = "0.1"
author = "Yuriy Glukhov"
description = "GUI framework"
license = "BSD"

SkipDirs = "test/android/com.mycompany.MyGame"

[Dependencies]
Requires: "sdl2"
Requires: "opengl"
Requires: "nimsl"
Requires: "jnim" # For android target
Requires: "nake"
Requires: "closure_compiler"
Requires: "plists"

# Jester is required to run a web server from the nakefile to serve WebGL variant
Requires: "jester"
Requires: "https://github.com/yglukhov/ttf"
Requires: "https://github.com/yglukhov/async_http_request"
