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

Quick start
===========

Installation
------------
.. code-block:: sh

    nimble install nimx

Please note that nimx is tested only against the latest devel version of Nim compiler.

Usage
------------
.. code-block:: nim

    # File: main.nim
    import nimx.window
    import nimx.text_field

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
Unix:

.. code-block:: sh

    nim c -r --noMain --threads:on main.nim

Windows:

.. code-block:: sh

    nim c -r --threads:on main.nim


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
