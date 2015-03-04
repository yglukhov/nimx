
import view

type Window* = ref object of View

method onResize*(w: Window, newSize: Size) =
    procCall w.View.setSize(newSize)

