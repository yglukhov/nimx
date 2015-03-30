import window
import logging
import view
import context
import matrixes
import dom
import app
import portable_gl

type JSCanvasWindow* = ref object of Window
    renderingContext: GraphicsContext

export window

proc setupWebGL() =
    asm """
        window.requestAnimFrame = (function() {
            return window.requestAnimationFrame ||
                window.webkitRequestAnimationFrame ||
                window.mozRequestAnimationFrame ||
                window.oRequestAnimationFrame ||
                window.msRequestAnimationFrame ||
                function(/* function FrameRequestCallback */ callback, /* DOMElement Element */ element) {
                window.setTimeout(callback, 1000/60);
        };
    })();
    """

setupWebGL()

method initWithCanvasId*(w: JSCanvasWindow, id: cstring) =
    var width, height: Coord
    asm """
        var canvas = document.getElementById(`id`);
        `width` = canvas.width;
        `height` = canvas.height;
        """
    procCall w.Window.init(newRect(0, 0, width, height))
    w.renderingContext = newGraphicsContext(id)

    w.enableAnimation(true)
    mainApplication().addWindow(w)

proc newJSCanvasWindow*(canvasId: string): JSCanvasWindow =
    result.new()
    result.initWithCanvasId(canvasId)

method drawWindow*(w: JSCanvasWindow) =
    let c = w.renderingContext
    c.gl.clear(c.gl.COLOR_BUFFER_BIT)
    let oldContext = setCurrentContext(c)
    defer: setCurrentContext(oldContext)
    var transform : Transform3D
    transform.ortho(0, w.frame.width, w.frame.height, 0, -1, 1)
    c.withTransform transform:
        procCall w.Window.drawWindow()

method onResize*(w: JSCanvasWindow, newSize: Size) =
    #glViewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    procCall w.Window.onResize(newSize)

proc startAnimation*() =
    mainApplication().runAnimations()
    mainApplication().drawWindows()
    asm "requestAnimFrame(`startAnimation`);"

