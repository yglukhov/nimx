
import view

type Window* = ref object of View

method onResize*(w: Window, newSize: Size) =
    discard
