# Platform specific implementations follow
import abstract_window
when defined(js):
    import js_canvas_window
    export startAnimation
elif defined(emscripten):
    import emscripten_window
else:
    import sdl_window
    export runUntilQuit

export runApplication

export abstract_window
