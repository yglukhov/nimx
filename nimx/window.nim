
import view

export view

# Window type is defined in view module


#TODO: Window size has two notions. Think about it.

method init*(w: Window, frame: Rect) =
    procCall w.View.init(frame)
    w.window = w

method `title=`*(w: Window, t: string) = discard
method title*(w: Window): string = ""


method onResize*(w: Window, newSize: Size) =
    procCall w.View.setFrameSize(newSize)

method drawWindow*(w: Window) =
    w.recursiveDrawSubviews()

method enableAnimation*(w: Window, flag: bool) = discard

method startTextInput*(w: Window) = discard
method stopTextInput*(w: Window) = discard

