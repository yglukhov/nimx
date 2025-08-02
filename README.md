# nimx [![Build Status](https://github.com/yglukhov/nimx/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/yglukhov/nimx/actions?query=branch%3Amaster) [![nimble](https://img.shields.io/badge/nimble-black?logo=nim&style=flat&labelColor=171921&color=%23f3d400)](https://nimble.directory/pkg/nimx)

Cross-platform GUI framework in [Nim](https://github.com/nim-lang/nim).
This is a development (version 2) version, a lot of upcoming breaking changes are expected.
For the old version see `v1` branch.

[Live demo in WebGL](http://yglukhov.github.io/nimx/demo.html)

![Sample Screenshot](./doc/sample-screenshot.png)

---

## Usage

```nim
# File: main.nim
import nimx/[window, text_field, layout]

proc startApp() =
  # First create a window. Window is the root of view hierarchy.
  var wnd = newWindow(newRect(40, 40, 800, 600))
  wnd.makeLayout:
    # Create a static text field, that occupies all the window
    - Label:
      frame == super
      text: "Hello, world!"

# Run the app
runApplication:
  startApp()
```

## Running

```nim
nim c -r --threads:on main.nim
```

## Supported target platforms

Nimx officially supports Linux, MacOS, Windows, Android, iOS and WebAssembly.

## Troubleshooting

Nimx is tested only against the latest devel version of Nim compiler. Before reporting any issues please verify that your Nim is as fresh as possible.

## Running nimx samples

```nim
  git clone https://github.com/yglukhov/nimx
  cd nimx
  nimble install -dy
  nake # Build and run on the current platform
```

## Reference

See [the docs](./doc) for more information.
