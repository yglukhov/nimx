What is nimx
============


**nimx** is a UI library written in [Nim](http://nim-lang.org). It provides all the needed layers to create a UI application from scratch. Nimx notable features:

- Cross-platform. Nimx can run on Windows, Linux, MacOS X, iOS, Android, [JavaScript](main.html), Asm.js, WebAssembly, and more.
- Hardware accelerated. Nimx uses OpenGL for the graphics. When no animation is running nimx will redraw the windows only when needed to be power efficient. It can also be switched to high FPS mode so it could be used as a porting layer for games.
- Nimx drawing algorithms are designed to be resolution independent. Shapes are drawn with distance functions, fonts utilize signed distance fields and provide subpixel antialiasing.
- nimx utilizes [kiwi](https://github.com/yglukhov/kiwi) constraint solving algorithm for its layout system allowing for sophisticated layouts defined with an easy to use DSL.
- nimx provides extensible abstractions for cross-platform asset management so that your code looks and works the same regardless you're compiling for a desktop OS, Android or JavaScript.
- nimx provides some essential set of controls and views and makes it easy to implement new ones in separate packages.
