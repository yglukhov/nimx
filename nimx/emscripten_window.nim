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

proc getClientRectDimension(id, dim: cstring): int =
    let r = EM_ASM_INT("""
        return document.getElementById(Pointer_stringify($0)).getBoundingClientRect()[Pointer_stringify($1)];
        """, id, dim)
    result = r

proc eventLocationFromJSEvent(mouseEvent: ptr EmscriptenMouseEvent, w: EmscriptenWindow): Point =
    let canvasX = getClientRectDimension(w.canvasId, "left")
    let canvasY = getClientRectDimension(w.canvasId, "top")
    result = newPoint(Coord(mouseEvent.targetX - canvasX), Coord(mouseEvent.targetY - canvasY))

proc onMouseButton(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer, bs: ButtonState): EM_BOOL =
    let w = cast[EmscriptenWindow](userData)
    template bcFromE(): VirtualKey =
        case mouseEvent.button:
        of 0: VirtualKey.MouseButtonPrimary
        of 2: VirtualKey.MouseButtonSecondary
        of 1: VirtualKey.MouseButtonMiddle
        else: VirtualKey.Unknown

    let point = eventLocationFromJSEvent(mouseEvent, w)
    var evt = newMouseButtonEvent(point, bcFromE(), bs, uint32(mouseEvent.timestamp))
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onMouseDown(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onMouseButton(eventType, mouseEvent, userData, bsDown)

proc onMouseUp(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onMouseButton(eventType, mouseEvent, userData, bsUp)

proc onMouseMove(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    let point = eventLocationFromJSEvent(mouseEvent, w)
    var evt = newMouseMoveEvent(point, uint32(mouseEvent.timestamp))
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onMouseWheel(eventType: cint, wheelEvent: ptr EmscriptenWheelEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    let pos = newPoint(Coord(wheelEvent.mouse.targetX), Coord(wheelEvent.mouse.targetY))
    var evt = newEvent(etScroll, pos)
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
    result = 0

proc onBlur(eventType: cint, keyEvent: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    w.onFocusChange(false)
    result = 0

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

    const maxWidth = 1280
    const maxHeight = 720

    var width, height: float32
    getDocumentSize(width, height)

    let screenAspect = width / height;

    var scaleFactor: Coord
    if (screenAspect > aspectRatio):
        scaleFactor = height / maxHeight;
    else:
        scaleFactor = width / maxWidth;

    if scaleFactor > 1: scaleFactor = 1

    width = maxWidth * scaleFactor
    height = maxHeight * scaleFactor

    discard emscripten_set_element_css_size(w.canvasId, width, height)
    discard EM_ASM_INT("""
    var c = document.getElementById(Pointer_stringify($0));
    c.width = $1;
    c.height = $2;
    """, cstring(w.canvasId), width, height)

    w.onResize(newSize(width, height))

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

    discard emscripten_set_keydown_callback(nil, cast[pointer](w), 1, onKeyDown)
    discard emscripten_set_keyup_callback(nil, cast[pointer](w), 1, onKeyUp)

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
    c.gl.viewport(0, 0, w.frame.width.GLsizei, w.frame.height.GLsizei)
    c.gl.clear(c.gl.COLOR_BUFFER_BIT or c.gl.STENCIL_BUFFER_BIT or c.gl.DEPTH_BUFFER_BIT)
    let oldContext = setCurrentContext(c)

    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    setCurrentContext(oldContext)

method onResize*(w: EmscriptenWindow, newSize: Size) =
    let sf = 1.0 #screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * sf), GLsizei(newSize.height * sf))
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
    if t > lastFullCollectTime + 10 and getOccupiedMem() > fullCollectThreshold:
        GC_enable()
        GC_fullCollect()
        GC_disable()
        lastFullCollectTime = t
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
            initDone = true

template runApplication*(initCode: typed): stmt =
    initFunc = proc() =
        initCode
    emscripten_set_main_loop(mainLoopPreload, 0, 1)
