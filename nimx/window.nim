# Platform specific implementations follow
import abstract_window
when defined(js):
    import js_canvas_window
    export startAnimation
else:
    import sdl_window
    export runUntilQuit
export abstract_window
