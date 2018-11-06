Building for different platforms
================================

1. Create a `nakefile.nim` in the root of your project with the following contents:
```nim
import nimx/naketools
# You can add build configuration later
```
Here we assume that your main file is called `main.nim` and is located in the root of the project. Next, use `nake` to build.

Nake usage
-----------------
Flags:
* `-d:release` - build in release mode
* `--norun` - don't run the project after build

Targets:
* `ios` - iOS
* `ios-sim` - iOS simulator
* `droid` - Android
* `js` - Nim JS backend
* `emscripten` - Emscripten + Asm.js
* `wasm` - Emscripten + Wasm
* else - build for current desktop platform (Linux, MacOS, Windows)

Examples:
```sh
nake # Build and run for current platform
nake --norun # Build for current platform
nake -d:release droid # Build in release mode and run on currently connected device
nake js # Build in debug mode and run in default browser
```
