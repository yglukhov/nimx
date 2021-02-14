===========
nimx |travis| |nimble|
===========

.. |travis| image:: https://travis-ci.org/yglukhov/nimx.svg?branch=master
    :target: https://travis-ci.org/yglukhov/nimx

.. |nimble| image:: https://raw.githubusercontent.com/yglukhov/nimble-tag/master/nimble_js.png
    :target: https://github.com/yglukhov/nimble-tag

Cross-platform GUI framework in `Nim <https://github.com/nim-lang/nim>`_.

`Live demo in WebGL <http://yglukhov.github.io/nimx/livedemo/main.html>`_


.. image:: ./doc/sample-screenshot.png

Usage
------------
.. code-block:: nim

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

Running
------------

.. code-block:: sh

    nim c -r --threads:on main.nim

Supported target platforms
------------
Nimx officially supports Linux, MacOS, Windows, Android, iOS, Javascript (with Nim JS backend) and Asm.js/WebAssembly (with Nim C backend and `Emscripten <http://emscripten.org>`_).

Troubleshooting
------------
Nimx is tested only against the latest devel version of Nim compiler. Before reporting any issues please verify that your Nim is as fresh as possible.

Running nimx samples
====================
.. code-block:: sh

    git clone https://github.com/yglukhov/nimx
    cd nimx
    nimble install -dy
    nake # Build and run on the current platform
    # or
    nake js # Build and run in default web browser

Reference
====================
See `the docs <./doc>`_ for more information.
