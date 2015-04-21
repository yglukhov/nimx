import window
import logging
import view
import context
import matrixes
import dom except Window
import app
import portable_gl
import event

type JSCanvasWindow* = ref object of Window
    renderingContext: GraphicsContext
    canvas: Element


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

proc buttonCodeFromJSEvent(e: ref TEvent): KeyCode =
    case e.button:
        of 1: kcMouseButtonPrimary
        of 2: kcMouseButtonSecondary
        of 3: kcMouseButtonMiddle
        else: kcUnknown

proc eventLocationFromJSEvent(e: ref TEvent, c: Element): Point =
    var offx, offy: Coord
    asm """
    var r = `c`.getBoundingClientRect();
    `offx` = r.left;
    `offy` = r.top;
    """
    result.x = e.clientX.Coord - offx
    result.y = e.clientY.Coord - offy

proc setupEventHandlersForCanvas(w: JSCanvasWindow, c: Element) =
    let onmousedown = proc (e: ref TEvent) =
        var evt = newMouseDownEvent(eventLocationFromJSEvent(e, c), buttonCodeFromJSEvent(e))
        evt.window = w
        discard mainApplication().handleEvent(evt)

    let onmouseup = proc (e: ref TEvent) =
        var evt = newMouseUpEvent(eventLocationFromJSEvent(e, c), buttonCodeFromJSEvent(e))
        evt.window = w
        discard mainApplication().handleEvent(evt)

    let onmousemove = proc (e: ref TEvent) =
        var evt = newMouseMoveEvent(eventLocationFromJSEvent(e, c))
        evt.window = w
        discard mainApplication().handleEvent(evt)

    let onscroll = proc (e: ref TEvent): bool =
        var evt = newEvent(etScroll, eventLocationFromJSEvent(e, c))
        var x, y: Coord
        asm """
        `x` = `e`.deltaX;
        `y` = `e`.deltaY;
        """
        evt.offset.x = x
        evt.offset.y = y
        evt.window = w
        result = not mainApplication().handleEvent(evt)

    # TODO: Remove this hack, when handlers definition in dom.nim fixed.
    asm """
    `c`.onmousedown = `onmousedown`;
    `c`.onmouseup = `onmouseup`;
    `c`.onmousemove = `onmousemove`;
    `c`.onwheel = `onscroll`;
    """

method initWithCanvasId*(w: JSCanvasWindow, id: cstring) =
    var width, height: Coord
    var canvas = document.getElementById(id)
    asm """
    `width` = `canvas`.width;
    `height` = `canvas`.height;
    """
    w.canvas = canvas
    procCall w.Window.init(newRect(0, 0, width, height))
    w.renderingContext = newGraphicsContext(id)

    w.setupEventHandlersForCanvas(canvas)

    w.enableAnimation(true)
    mainApplication().addWindow(w)

proc newJSCanvasWindow*(canvasId: string): JSCanvasWindow =
    result.new()
    result.initWithCanvasId(canvasId)

method drawWindow*(w: JSCanvasWindow) =
    let c = w.renderingContext
    c.gl.clear(c.gl.COLOR_BUFFER_BIT or c.gl.STENCIL_BUFFER_BIT)
    let oldContext = setCurrentContext(c)
    defer: setCurrentContext(oldContext)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()

method onResize*(w: JSCanvasWindow, newSize: Size) =
    #glViewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    procCall w.Window.onResize(newSize)

proc startAnimation*() =
    mainApplication().runAnimations()
    mainApplication().drawWindows()
    asm "window.requestAnimFrame(`startAnimation`);"

proc sendInputEvent(wnd: JSCanvasWindow, evt: ref TEvent) =
    var s: cstring
    asm """
    `s` = window.__nimx_textinput.value;
    window.__nimx_textinput.value = "";
    """
    var e = newEvent(etTextInput)
    e.window = wnd
    e.text = $s
    discard mainApplication().handleEvent(e)

method startTextInput*(wnd: JSCanvasWindow, r: Rect) =
    let canvas = wnd.canvas

    let oninput = proc(evt: ref TEvent) =
        wnd.sendInputEvent(evt)

    asm """
    if (typeof(window.__nimx_textinput) === 'undefined')
    {
        var i = window.__nimx_textinput = document.createElement('input');
        i.type = 'text';
    }
    window.__nimx_textinput.oninput = `oninput`;
    window.__nimx_textinput.style.position = 'absolute';
    window.__nimx_textinput.style.top = '-9999px';
    document.body.appendChild(window.__nimx_textinput);
    setTimeout(function(){ window.__nimx_textinput.focus(); }, 1);
    """

method stopTextInput*(w: JSCanvasWindow) =
    asm """
    if (typeof(window.__nimx_textinput) !== 'undefined')
    {
        window.__nimx_textinput.oninput = null;
        window.__nimx_textinput.blur();
    }
    """
