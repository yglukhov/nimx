# Platform specific implementations follow
import window.abstract_window
when defined(js):
    import window.js_canvas_window
    export startAnimation
elif defined(emscripten):
    import window.emscripten_window
elif defined(macosx) and not defined(ios) and defined(nimxAvoidSDL):
    import window.appkit_window
else:
    import window.sdl_window
    export runUntilQuit

export runApplication

export abstract_window
