import abstract_window
import system_logger
import view
import context
import matrixes
import dom except Window
import app
import portable_gl
import opengl
import event
import private.js_vk_map

type JSCanvasWindow* = ref object of Window
    renderingContext: GraphicsContext
    canvas: Element


export abstract_window

template buttonStateFromKeyEvent(evt: dom.Event): ButtonState =
    if evt.`type` == "keyup": bsUp
    elif evt.`type` == "keydown": bsDown
    else: bsUnknown

proc setupWebGL() =
    {.emit: """
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

    window.__nimx_focused_canvas = null;

    document.addEventListener('mousedown', function(event) {
        window.__nimx_focused_canvas = event.target;
    }, false);

    window.__nimx_keys_down = {};
    """.}

    proc onkey(evt: dom.Event) =
        var wnd : JSCanvasWindow
        var repeat = false
        let bs = buttonStateFromKeyEvent(evt)
        if bs == bsDown:
            {.emit: """
            `repeat` = `evt`.keyCode in window.__nimx_keys_down;
            window.__nimx_keys_down[`evt`.keyCode] = true;
            """.}
        elif bs == bsUp:
            {.emit: """
            delete window.__nimx_keys_down[`evt`.keyCode];
            """.}

        {.emit: """
        if (window.__nimx_focused_canvas !== null && window.__nimx_focused_canvas.__nimx_window !== undefined) {
            `wnd` = window.__nimx_focused_canvas.__nimx_window;
        }
        """.}
        if not wnd.isNil:
            # TODO: Complete this!
            var e = newKeyboardEvent(virtualKeyFromNative(evt.keyCode), bs, repeat)

            #result.rune = keyEv.keysym.unicode.Rune
            e.window = wnd
            discard mainApplication().handleEvent(e)

    document.addEventListener("keydown", onkey, false)
    document.addEventListener("keyup", onkey, false)


setupWebGL()

proc buttonCodeFromJSEvent(e: dom.Event): VirtualKey =
    case e.button:
        of 1: VirtualKey.MouseButtonPrimary
        of 2: VirtualKey.MouseButtonSecondary
        of 3: VirtualKey.MouseButtonMiddle
        else: VirtualKey.Unknown

proc eventLocationFromJSEvent(e: dom.Event, c: Element): Point =
    var offx, offy: Coord
    {.emit: """
    var r = `c`.getBoundingClientRect();
    `offx` = r.left;
    `offy` = r.top;
    """.}
    result.x = e.clientX.Coord - offx
    result.y = e.clientY.Coord - offy

proc setupEventHandlersForCanvas(w: JSCanvasWindow, c: Element) =
    let onmousedown = proc (e: dom.Event) =
        var evt = newMouseDownEvent(eventLocationFromJSEvent(e, c), buttonCodeFromJSEvent(e))
        evt.window = w
        discard mainApplication().handleEvent(evt)

    let onmouseup = proc (e: dom.Event) =
        var evt = newMouseUpEvent(eventLocationFromJSEvent(e, c), buttonCodeFromJSEvent(e))
        evt.window = w
        discard mainApplication().handleEvent(evt)

    let onmousemove = proc (e: dom.Event) =
        var evt = newMouseMoveEvent(eventLocationFromJSEvent(e, c))
        evt.window = w
        discard mainApplication().handleEvent(evt)

    let onscroll = proc (e: dom.Event): bool =
        var evt = newEvent(etScroll, eventLocationFromJSEvent(e, c))
        var x, y: Coord
        {.emit: """
        `x` = `e`.deltaX;
        `y` = `e`.deltaY;
        """.}
        evt.offset.x = x
        evt.offset.y = y
        evt.window = w
        result = not mainApplication().handleEvent(evt)

    let onresize = proc (e: dom.Event): bool =
        var sizeChanged = false
        var newWidth, newHeight : Coord
        {.emit: """
        `newWidth` = `c`.width;
        `newHeight` = `c`.height;
        var r = `c`.getBoundingClientRect();
        if (r.width !== `c`.width) {
            `newWidth` = r.width;
            `c`.width = r.width;
            `sizeChanged` = true;
        }
        if (r.height !== `c`.height) {
            `newHeight` = r.height
            `c`.height = r.height;
            `sizeChanged` = true;
        }
        """.}
        if sizeChanged:
            var evt = newEvent(etWindowResized)
            evt.window = w
            evt.position.x = newWidth
            evt.position.y = newHeight
            discard mainApplication().handleEvent(evt)

    let onfocus = proc()=
        w.onFocusChange(true)

    let onblur = proc()=
        w.onFocusChange(false)

    # TODO: Remove this hack, when handlers definition in dom.nim fixed.
    {.emit: """
    `c`.onmousedown = `onmousedown`;
    `c`.onmouseup = `onmouseup`;
    `c`.onmousemove = `onmousemove`;
    `c`.onwheel = `onscroll`;
    window.onresize = `onresize`;
    window.onfocus = `onfocus`;
    window.onblur = `onblur`;
    """.}

proc requestAnimFrame(w: dom.Window, p: proc() {.nimcall.}) {.importcpp.}

proc animFrame() =
    mainApplication().runAnimations()
    mainApplication().drawWindows()
    dom.window.requestAnimFrame(animFrame)

proc initWithCanvas*(w: JSCanvasWindow, canvas: Element) =
    var width, height: Coord
    {.emit: """
    `width` = `canvas`.width;
    `height` = `canvas`.height;
    `canvas`.__nimx_window = `w`;
    var pixelRatio = 'devicePixelRatio' in window ? window.devicePixelRatio : 1;
    if (pixelRatio > 1 && !`canvas`.scaled) {
        `canvas`.style.width = `canvas`.width + 'px';
        `canvas`.width = `canvas`.width * pixelRatio;
        `canvas`.style.height = `canvas`.height + 'px';
        `canvas`.height = `canvas`.height * pixelRatio;
        `canvas`.scaled = true;
    }
    """.}
    w.canvas = canvas
    procCall w.Window.init(newRect(0, 0, width, height))
    w.renderingContext = newGraphicsContext(canvas)

    w.setupEventHandlersForCanvas(canvas)

    w.enableAnimation(true)
    mainApplication().addWindow(w)
    dom.window.requestAnimFrame(animFrame)

proc initWithCanvasId*(w: JSCanvasWindow, id: cstring) =
    w.initWithCanvas(document.getElementById(id))

proc initByFillingBrowserWindow*(w: JSCanvasWindow) =
    # This is glitchy sometimes
    let canvas = document.createElement("canvas")
    canvas.style.width = "100%"
    canvas.style.height = "100%"
    document.body.appendChild(canvas)

    {.emit: """
    var r = `canvas`.getBoundingClientRect();
    `canvas`.width = r.width;
    `canvas`.height = r.height;
    """.}

    w.initWithCanvas(canvas)

proc newJSCanvasWindow*(canvasId: string): JSCanvasWindow =
    result.new()
    result.initWithCanvasId(canvasId)

proc newJSCanvasWindow*(r: Rect): JSCanvasWindow =
    result.new()
    result.init(r)

proc newJSWindowByFillingBrowserWindow*(): JSCanvasWindow =
    result.new()
    result.initByFillingBrowserWindow()

newWindow = proc(r: view.Rect): Window =
    result = newJSCanvasWindow(r)

newFullscreenWindow = proc(): Window =
    result = newJSWindowByFillingBrowserWindow()

method init*(w: JSCanvasWindow, r: Rect) =
    let canvas = document.createElement("canvas")
    let width = r.width
    let height = r.height
    {.emit: """
    `canvas`.width = `width`;
    `canvas`.height = `height`;
    """.}
    document.body.appendChild(canvas)
    w.initWithCanvas(canvas)

method drawWindow*(w: JSCanvasWindow) =
    let c = w.renderingContext
    c.gl.clear(c.gl.COLOR_BUFFER_BIT or c.gl.STENCIL_BUFFER_BIT or c.gl.DEPTH_BUFFER_BIT)
    let oldContext = setCurrentContext(c)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    setCurrentContext(oldContext)

method onResize*(w: JSCanvasWindow, newSize: Size) =
    w.renderingContext.gl.viewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    procCall w.Window.onResize(newSize)

proc startAnimation*() {.deprecated.} = discard

proc sendInputEvent(wnd: JSCanvasWindow, evt: dom.Event) =
    var s: cstring
    {.emit: """
    `s` = window.__nimx_textinput.value;
    window.__nimx_textinput.value = "";
    """.}
    var e = newEvent(etTextInput)
    e.window = wnd
    e.text = $s
    discard mainApplication().handleEvent(e)

method startTextInput*(wnd: JSCanvasWindow, r: Rect) =
    let oninput = proc(evt: dom.Event) =
        wnd.sendInputEvent(evt)

    {.emit: """
    if (window.__nimx_textinput === undefined) {
        var i = window.__nimx_textinput = document.createElement('input');
        i.type = 'text';
        i.style.position = 'absolute';
        i.style.top = '-99999px';
        document.body.appendChild(i);
    }
    window.__nimx_textinput.oninput = `oninput`;
    setTimeout(function(){ window.__nimx_textinput.focus(); }, 1);
    """.}

method stopTextInput*(w: JSCanvasWindow) =
    {.emit: """
    if (window.__nimx_textinput !== undefined) {
        window.__nimx_textinput.oninput = null;
        window.__nimx_textinput.blur();
    }
    """.}

template runApplication*(code: typed): typed =
    dom.window.onload = proc (e: dom.Event) =
        code
