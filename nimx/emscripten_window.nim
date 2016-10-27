import abstract_window
import system_logger
import view
import opengl
import context
import event
import font
import unicode, times
import app
import linkage_details
import portable_gl
import screen
import jsbind, jsbind.emscripten

import private.js_vk_map

type EmscriptenWindow* = ref object of Window
    ctx: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
    renderingContext: GraphicsContext
    canvasId: string

method enableAnimation*(w: EmscriptenWindow, flag: bool) =
    discard

proc getCanvasDimensions(id: cstring, cssRect: var Rect, virtualSize: var Size) {.inline.} =
    discard EM_ASM_INT("""
        var c = document.getElementById(Pointer_stringify($0));
        var r = c.getBoundingClientRect();
        setValue($1, r.left, 'float');
        setValue($1 + 4, r.top, 'float');
        setValue($1 + 8, r.width, 'float');
        setValue($1 + 12, r.height, 'float');
        setValue($2, c.width, 'float');
        setValue($2 + 4, c.height, 'float');
        """, id, addr cssRect, addr virtualSize)

proc eventLocationFromJSEvent(mouseEvent: ptr EmscriptenMouseEvent, w: EmscriptenWindow, eventTargetIsCanvas: bool): Point =
    # `eventTargetIsCanvas` should be true if `mouseEvent.targetX` and `mouseEvent.targetY`
    # are relative to canvas.
    var cssRect: Rect
    var virtualSize: Size
    getCanvasDimensions(w.canvasId, cssRect, virtualSize)
    result.x = Coord(mouseEvent.targetX)
    result.y = Coord(mouseEvent.targetY)
    if not eventTargetIsCanvas: result -= cssRect.origin
    result.x = result.x / cssRect.width * virtualSize.width / w.pixelRatio
    result.y = result.y / cssRect.height * virtualSize.height / w.pixelRatio

proc onMouseButton(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer, bs: ButtonState): EM_BOOL =
    let w = cast[EmscriptenWindow](userData)
    template bcFromE(): VirtualKey =
        case mouseEvent.button:
        of 0: VirtualKey.MouseButtonPrimary
        of 2: VirtualKey.MouseButtonSecondary
        of 1: VirtualKey.MouseButtonMiddle
        else: VirtualKey.Unknown

    let point = eventLocationFromJSEvent(mouseEvent, w, false)
    var evt = newMouseButtonEvent(point, bcFromE(), bs, uint32(mouseEvent.timestamp))
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onMouseDown(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    result = onMouseButton(eventType, mouseEvent, userData, bsDown)
    # Preventing default behavior for mousedown may prevent our iframe to become
    # focused, if we're in an iframe. And that has bad consequenses such as
    # inability to handle keyboard events.
    result = 0

proc onMouseUp(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onMouseButton(eventType, mouseEvent, userData, bsUp)

proc onMouseMove(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    let point = eventLocationFromJSEvent(mouseEvent, w, false)
    var evt = newMouseMoveEvent(point, uint32(mouseEvent.timestamp))
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onMouseWheel(eventType: cint, wheelEvent: ptr EmscriptenWheelEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    let point = eventLocationFromJSEvent(addr wheelEvent.mouse, w, true)
    var evt = newEvent(etScroll, point)
    evt.window = w
    evt.offset.x = wheelEvent.deltaX.Coord
    evt.offset.y = wheelEvent.deltaY.Coord
    if mainApplication().handleEvent(evt): result = 1

proc onKey(keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer, buttonState: ButtonState): EM_BOOL =
    var e = newKeyboardEvent(virtualKeyFromNative(int(keyEvent.keyCode)), buttonState, bool(keyEvent.repeat))
    e.window = cast[EmscriptenWindow](userData)
    if mainApplication().handleEvent(e): result = 1

proc onKeyDown(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onKey(keyEvent, userData, bsDown)

proc onKeyUp(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onKey(keyEvent, userData, bsUp)

proc onFocus(eventType: cint, keyEvent: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    w.onFocusChange(true)

proc onBlur(eventType: cint, keyEvent: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    w.onFocusChange(false)

proc getDocumentSize(width, height: var float32) {.inline.} =
    discard EM_ASM_INT("""
        var w = window;
        var d = document;
        var e = d.documentElement;
        var g = d.getElementsByTagName('body')[0];
        var x = w.innerWidth || e.clientWidth || g.clientWidth;
        var y = w.innerHeight|| e.clientHeight|| g.clientHeight;
        setValue($0, x, 'float');
        setValue($1, y, 'float');
    """, addr width, addr height)

proc updateCanvasSize(w: EmscriptenWindow) =
    let aspectRatio = w.bounds.width / w.bounds.height

    const maxWidth = 1920
    const maxHeight = 1080

    var width, height: float32
    getDocumentSize(width, height)

    let screenAspect = width / height;

    var scaleFactor: Coord
    if (screenAspect > aspectRatio):
        scaleFactor = height / maxHeight;
    else:
        scaleFactor = width / maxWidth;

    width = maxWidth * scaleFactor
    height = maxHeight * scaleFactor

    w.pixelRatio = screenScaleFactor()

    if scaleFactor > 1: scaleFactor = 1
    let canvWidth = maxWidth * scaleFactor
    let canvHeight = maxHeight * scaleFactor

    discard EM_ASM_INT("""
    var c = document.getElementById(Pointer_stringify($0));
    c.width = $1;
    c.height = $2;
    """, cstring(w.canvasId), w.pixelRatio * canvWidth, w.pixelRatio * canvHeight)

    discard emscripten_set_element_css_size(w.canvasId, width, height)

    w.onResize(newSize(canvWidth, canvHeight))

proc onResize(eventType: cint, uiEvent: ptr EmscriptenUiEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    w.updateCanvasSize()
    result = 0

proc onContextLost(eventType: cint, reserved: pointer, userData: pointer): EM_BOOL {.cdecl.} =
    discard EM_ASM_INT("""
    alert("Context lost!");
    """)

proc initCommon(w: EmscriptenWindow, r: view.Rect) =
    procCall init(w.Window, r)

    let id = EM_ASM_INT("""
    if (window.__nimx_canvas_id === undefined) {
        window.__nimx_canvas_id = 0;
    } else {
        ++window.__nimx_canvas_id;
    }
    var canvas = document.createElement("canvas");
    canvas.id = "nimx_canvas" + window.__nimx_canvas_id;
    canvas.width = $0;
    canvas.height = $1;
    document.body.appendChild(canvas);
    return window.__nimx_canvas_id;
    """, r.width, r.height)

    w.canvasId = "nimx_canvas" & $id

    var attrs: EmscriptenWebGLContextAttributes
    emscripten_webgl_init_context_attributes(addr attrs)
    attrs.premultipliedAlpha = 0
    attrs.alpha = 0
    attrs.antialias = 0
    attrs.stencil = 1
    w.ctx = emscripten_webgl_create_context(w.canvasId, addr attrs)
    discard emscripten_webgl_make_context_current(w.ctx)
    w.renderingContext = newGraphicsContext()

    const docID = "#document"
    discard emscripten_set_mousedown_callback(docID, cast[pointer](w), 0, onMouseDown)
    discard emscripten_set_mouseup_callback(docID, cast[pointer](w), 0, onMouseUp)
    discard emscripten_set_mousemove_callback(docID, cast[pointer](w), 0, onMouseMove)
    discard emscripten_set_wheel_callback(w.canvasId, cast[pointer](w), 0, onMouseWheel)

    discard emscripten_set_keydown_callback(docID, cast[pointer](w), 1, onKeyDown)
    discard emscripten_set_keyup_callback(docID, cast[pointer](w), 1, onKeyUp)

    discard emscripten_set_blur_callback(nil, cast[pointer](w), 1, onBlur)
    discard emscripten_set_focus_callback(nil, cast[pointer](w), 1, onFocus)

    discard emscripten_set_webglcontextlost_callback(w.canvasId, cast[pointer](w), 0, onContextLost)

    discard emscripten_set_resize_callback(nil, cast[pointer](w), 0, onResize)

    #w.enableAnimation(true)
    mainApplication().addWindow(w)
    w.updateCanvasSize()

proc initFullscreen*(w: EmscriptenWindow) =
    w.initCommon(newRect(0, 0, 800, 600))

method init*(w: EmscriptenWindow, r: view.Rect) =
    w.initCommon(r)

proc newFullscreenEmscriptenWindow*(): EmscriptenWindow =
    result.new()
    result.initFullscreen()

proc newEmscriptenWindow*(r: view.Rect): EmscriptenWindow =
    result.new()
    result.init(r)

newWindow = proc(r: view.Rect): Window =
    result = newEmscriptenWindow(r)

newFullscreenWindow = proc(): Window =
    result = newFullscreenEmscriptenWindow()

method drawWindow(w: EmscriptenWindow) =
    let c = w.renderingContext
    let oldContext = setCurrentContext(c)

    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    setCurrentContext(oldContext)

method onResize*(w: EmscriptenWindow, newSize: Size) =
    w.pixelRatio = screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * w.pixelRatio), GLsizei(newSize.height * w.pixelRatio))
    procCall w.Window.onResize(newSize)

proc nimx_OnTextInput(wnd: pointer, text: cstring) {.EMSCRIPTEN_KEEPALIVE.} =
    var e = newEvent(etTextInput)
    e.window = cast[EmscriptenWindow](wnd)
    e.text = $text
    discard mainApplication().handleEvent(e)

method startTextInput*(wnd: EmscriptenWindow, r: Rect) =
    discard EM_ASM_INT("""
    if (window.__nimx_textinput === undefined) {
        var i = window.__nimx_textinput = document.createElement('input');
        i.type = 'text';
        i.style.position = 'absolute';
        i.style.top = '-99999px';
        document.body.appendChild(i);
    }
    window.__nimx_textinput.oninput = function() {
        var str = allocate(intArrayFromString(window.__nimx_textinput.value), 'i8', ALLOC_NORMAL);
        window.__nimx_textinput.value = "";
        _nimx_OnTextInput($0, str);
        _free(str);
    };
    setTimeout(function(){ window.__nimx_textinput.focus(); }, 1);
    """, cast[pointer](wnd))

method stopTextInput*(w: EmscriptenWindow) =
    discard EM_ASM_INT("""
    if (window.__nimx_textinput !== undefined) {
        window.__nimx_textinput.oninput = null;
        window.__nimx_textinput.blur();
    }
    """)

var lastFullCollectTime = 0.0
const fullCollectThreshold = 128 * 1024 * 1024 # 128 Megabytes

proc nimxMainLoopInner() {.EMSCRIPTEN_KEEPALIVE.} =
    mainApplication().runAnimations()
    mainApplication().drawWindows()

    let t = epochTime()
    if gcRequested or (t > lastFullCollectTime + 10 and getOccupiedMem() > fullCollectThreshold):
        GC_enable()
        when defined(useRealtimeGC):
            GC_setMaxPause(0)
        GC_fullCollect()
        GC_disable()
        lastFullCollectTime = t
        gcRequested = false
    else:
        when defined(useRealtimeGC):
            GC_step(1000, true)
        else:
            {.hint: "It is recommended to compile your project with -d:useRealtimeGC for emscripten".}

var initFunc : proc()

var initDone = false
proc mainLoopPreload() {.cdecl.} =
    if initDone:
        when defined(release):
            handleJSExceptions:
                nimxMainLoopInner()
        else:
            discard EM_ASM_INT """
            try {
                _nimxMainLoopInner();
            }
            catch(e) {
                _nimem_e(e);
            }
            """
    else:
        let r = EM_ASM_INT """
        if (document.readyState === 'complete') {
            return 1;
        }
        return 0;
        """
        if r == 1:
            GC_disable() # GC Should only be called close to the bottom of the stack on emscripten.
            initFunc()
            initFunc = nil
            initDone = true

template runApplication*(initCode: typed): stmt =
    initFunc = proc() =
        initCode
    emscripten_set_main_loop(mainLoopPreload, 0, 1)

method enterFullscreen*(w: EmscriptenWindow) =
    discard emscripten_request_fullscreen(w.canvasId, 0)

method exitFullscreen*(w: EmscriptenWindow) =
    discard emscripten_exit_fullscreen()

method isFullscreen*(w: EmscriptenWindow): bool =
    var s: EmscriptenFullscreenChangeEvent
    discard emscripten_get_fullscreen_status(addr s)
    result = s.isFullscreen != 0
