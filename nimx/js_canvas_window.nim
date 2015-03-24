import window
import logging
import view
import context
import matrixes
import dom
import app

type JSCanvasWindow* = ref object of Window
    renderingContext: GraphicsContext

export window


method enableAnimation(w: JSCanvasWindow, flag: bool) =
    discard

method initWithCanvasId*(w: JSCanvasWindow, id: string) =
    var width, height: Coord
    var rawCanvasId = id.cstring
    asm """
        var canvas = document.getElementById(`rawCanvasId`);
        `width` = canvas.width;
        `height` = canvas.height;
        """
    procCall w.Window.init(newRect(0, 0, width, height))
    logi "Self frame: ", w.frame
    w.renderingContext = newGraphicsContext(id)

    w.enableAnimation(true)
    mainApplication().addWindow(w)

proc newJSCanvasWindow*(canvasId: string): JSCanvasWindow =
    result.new()
    result.initWithCanvasId(canvasId)

method drawWindow*(w: JSCanvasWindow) =
    #glViewport(0, 0, GLsizei(w.frame.width), GLsizei(w.frame.height))

    #glClear(GL_COLOR_BUFFER_BIT) # Clear color and depth buffers

    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    defer: setCurrentContext(oldContext)
    var transform : Transform3D
    transform.ortho(0, w.frame.width, 0, w.frame.height, -1, 1)
    let oldTransform = c.setScopeTransform(transform)

    procCall w.Window.drawWindow()

    c.revertTransform(oldTransform)
    #w.impl.GL_SwapWindow() # Swap the front and back frame buffers (double buffering)

method onResize*(w: JSCanvasWindow, newSize: Size) =
    #glViewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    procCall w.Window.onResize(newSize)

