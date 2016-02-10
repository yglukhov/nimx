====
Home
====

Welcome to nimx
--------------

**nimx** is a UI library written in `Nim<http://nim-lang.org>`_. Main features:

**Cross-platform**
    nimx can run on Windows, Linux, MacOS X, iOS, Android, and
    even `JavaScript<main.html>`_ in a web-browser!
**Pure**
    nimx does not require any non-Nim dependencies except SDL2_ when compiling
    to native target. Compiling to JavaScript requires no non-Nim dependencies.
    This means that in order to use nimx all you need is SDL2_ and
    ``requires nimx`` line in your `.nimble` file.
**Hardware accelerated**
    nimx utilizes **OpenGL** renderer under the hood. This means you can embed
    nimx into existing **OpenGL** application or use it as a platform for your
    application with low-level **OpenGL** rendering. nimx exposes a zero-cost
    abstraction over **OpenGL** context to abstract away the difference between
    native **OpenGL** and **WebGL**. Despite being efficient for graphics
    intensive tasks nimx remains battery-friendly for mobile devices. The screen
    is not refreshed constantly when there is nothing to redraw.
**Sleek**
    nimx provides instruments for hardware-accelerated resolution-independent
    vector graphics rendering which are used by nimx itself to
    render controls. Also nimx utilizes signed distance field TTF font rendering,
    resulting in better quality and resolution tolerance than conventional
    alpha-bitmap font rendering.

.. _SDL2: https://www.libsdl.org
