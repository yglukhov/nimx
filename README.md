# nimx [![Build Status](https://travis-ci.org/yglukhov/nimx.svg?branch=master)](https://travis-ci.org/yglukhov/nimx) [![nimble](https://img.shields.io/badge/nimble-black?logo=nim&style=flat&labelColor=171921&color=%23f3d400)](https://nimble.directory/pkg/nimx)

Cross-platform GUI framework in [Nim](https://github.com/nim-lang/nim).
This is a development (version 2) version, a lot of upcoming breaking changes are expected.
For the old version see `v1` branch.

[Live demo in WebGL](http://yglukhov.github.io/nimx/livedemo/main.html)

![Sample Screenshot](./doc/sample-screenshot.png)

---

## Usage

```nim
# File: main.nim
import nimx/window
import nimx/text_field

proc startApp() =
  # First create a window. Window is the root of view hierarchy.
  var wnd = newWindow(newRect(40, 40, 800, 600))

  # Create a static text field and add it to view hierarchy
  let label = newLabel(newRect(20, 20, 150, 20))
  label.text = "Hello, world!"
  wnd.addSubview(label)

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
