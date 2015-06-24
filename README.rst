===========
nimx
===========

Cross-platform GUI framework in `Nim <https://github.com/nim-lang/nim>`_.

.. image:: ./doc/sample-screenshot.png

Quick start
===========

Installation
------------
.. code-block:: sh

    nimble install nimx

Usage
------------
.. code-block:: nim

    # File: main.nim
    import nimx.sdl_window
    import nimx.text_field

    # First create a window. Window is the root of view hierarchy.
    # Currently there are two types of windows. SdlWindow should be used
    # with native targets, JSCanvasWindow should be used for WebGL target
    var wnd : SdlWindow
    wnd.new()
    wnd.init(newRect(40, 40, 800, 600))

    # Create a static text field and add it to view hierarchy
    let label = newLabel(newRect(20, 20, 150, 20))
    label.text = "Hello, world!"
    wnd.addSubview(label)

    # Run the main loop
    runUntilQuit()

Running
------------
.. code-block:: sh

    nim c -r --noMain main.nim


Running nimx samples
====================
.. code-block:: sh

    cd $(nimble path nimx)/test
    nake # Build and run on the current platform
    # or
    nake js # Build and run in default web browser

Reference
====================
TODO
