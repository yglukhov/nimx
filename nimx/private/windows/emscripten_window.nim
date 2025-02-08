import nimx/[ abstract_window, view, context, event, app, screen,
            portable_gl, linkage_details, notification_center ]
import opengl
import unicode, times, logging
import jsbind, jsbind/emscripten
import nimx/private/js_vk_map

import system, system/ansi_c

proc globalExceptionHandler(errorMsg: string) =
  cstderr.rawWrite(errorMsg)
  emscripten_cancel_main_loop()

onUnhandledException = globalExceptionHandler

type EmscriptenWindow* = ref object of Window
    ctx: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
    renderingContext: GraphicsContext
    canvasId: string
    textInputActive: bool

method fullscreenAvailable*(w: EmscriptenWindow): bool =
    return EM_ASM_INT("""
        var result = false;
        if (document.fullscreenEnabled !== undefined) {
            result = document.fullscreenEnabled;
        } else if (document.webkitFullscreenEnabled !== undefined) {
            result = document.webkitFullscreenEnabled;
        } else if (document.mozFullScreenEnabled !== undefined) {
            result = document.mozFullScreenEnabled;
        } else if (document.msFullscreenEnabled !== undefined) {
            result = document.msFullscreenEnabled;
        }
        return result ? 1 : 0;
    """) != 0

proc onFullscreenChange*(eventType: cint, fullscreenChangeEvent: ptr EmscriptenFullscreenChangeEvent, userData: pointer): EM_BOOL {.cdecl.} =
    sharedNotificationCenter().postNotification("WINDOW_FULLSCREEN_HAS_BEEN_CHANGED", newVariant((window: cast[Window](userData), fullscreen: bool(fullscreenChangeEvent.isFullscreen))))

method fullscreen*(w: EmscriptenWindow): bool =
    return EM_ASM_INT("""
        var result = false;
        if (document.fullscreenElement !== undefined) {
            result = document.fullscreenElement !== null;
        } else if (document.webkitFullscreenElement !== undefined) {
            result = document.webkitFullscreenElement !== null;
        } else if (document.mozFullScreenElement !== undefined) {
            result = document.mozFullScreenElement !== null;
        } else if (document.msFullscreenElement !== undefined) {
            result = document.msFullscreenElement !== null;
        }
        return result ? 1 : 0;
    """, w.canvasId.cstring) != 0

method `fullscreen=`*(w: EmscriptenWindow, v: bool) =
    let isFullscreen = w.fullscreen

    if not isFullscreen and v:
        discard EM_ASM_INT("""
            var c = document.getElementById(UTF8ToString($0));
            if (c.requestFullscreen) {
                c.requestFullscreen();
            } else if (c.webkitRequestFullscreen) {
                c.webkitRequestFullscreen();
            } else if (c.mozRequestFullScreen) {
                c.mozRequestFullScreen();
            } else if (c.msRequestFullscreen) {
                c.msRequestFullscreen();
            }
        """, w.canvasId.cstring)
    elif isFullscreen and not v:
        discard EM_ASM_INT("""
            if (document.exitFullscreen) {
                document.exitFullscreen();
            } else if (document.webkitExitFullscreen) {
                document.webkitExitFullscreen();
            } else if (document.mozCancelFullScreen) {
                document.mozCancelFullScreen();
            } else if (document.msExitFullscreen) {
                document.msExitFullscreen();
            }
        """)

method animationStateChanged*(w: EmscriptenWindow, flag: bool) =
    discard

template sdlNow():uint32 =
    let t = getTime()
    uint32(t.toUnix * 1000 + t.nanosecond div 1000000)

proc getCanvasDimensions(id: cstring, cssRect: var Rect, virtualSize: var Size) {.inline.} =
    discard EM_ASM_INT("""
        var c = document.getElementById(UTF8ToString($0));
        var r = c.getBoundingClientRect();
        setValue($1, r.left, 'float');
        setValue($1 + 4, r.top, 'float');
        setValue($1 + 8, r.width, 'float');
        setValue($1 + 12, r.height, 'float');
        setValue($2, c.width, 'float');
        setValue($2 + 4, c.height, 'float');
        """, id, addr cssRect, addr virtualSize)

proc eventLocationFromJSEventCoords(x, y: Coord, w: EmscriptenWindow, eventTargetIsCanvas: bool): Point =
    result = newPoint(x, y)
    var cssRect: Rect
    var virtualSize: Size
    getCanvasDimensions(w.canvasId, cssRect, virtualSize)
    if not eventTargetIsCanvas: result -= cssRect.origin
    result.x = result.x / cssRect.width * virtualSize.width / w.pixelRatio
    result.y = result.y / cssRect.height * virtualSize.height / w.pixelRatio

proc eventLocationFromJSEvent(evt: ptr EmscriptenMouseEvent | EmscriptenTouchPoint, w: EmscriptenWindow, eventTargetIsCanvas: bool): Point =
    # `eventTargetIsCanvas` should be true if `mouseEvent.targetX` and `mouseEvent.targetY`
    # are relative to canvas.
    eventLocationFromJSEventCoords(evt.targetX.Coord, evt.targetY.Coord, w, eventTargetIsCanvas)

proc onMouseButton(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer, bs: ButtonState): EM_BOOL =
    let w = cast[EmscriptenWindow](userData)
    template bcFromE(): VirtualKey =
        case mouseEvent.button:
        of 0: VirtualKey.MouseButtonPrimary
        of 2: VirtualKey.MouseButtonSecondary
        of 1: VirtualKey.MouseButtonMiddle
        else: VirtualKey.Unknown

    let point = eventLocationFromJSEvent(mouseEvent, w, false)
    var evt = newMouseButtonEvent(point, bcFromE(), bs, sdlNow())
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onTouchEvent(touchEvent: ptr EmscriptenTouchEvent, state: ButtonState, userData: pointer) =
    let w = cast[EmscriptenWindow](userData)
    let ts = uint32(epochTime() * 1000)
    for i in 0 ..< touchEvent.numTouches:
        if touchEvent.touches[i].isChanged == 0:
            continue

        let point = eventLocationFromJSEvent(touchEvent.touches[i], w, false)
        var evt = newTouchEvent(point, state, touchEvent.touches[i].identifier, ts)
        evt.window = w

        discard mainApplication().handleEvent(evt)

proc onMouseDown(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    result = onMouseButton(eventType, mouseEvent, userData, bsDown)
    # Preventing default behavior for mousedown may prevent our iframe to become
    # focused, if we're in an iframe. And that has bad consequenses such as
    # inability to handle keyboard events.
    result = 0

proc onTouchStart(eventType: cint, touchEvent: ptr EmscriptenTouchEvent, userData: pointer): EM_BOOL {.cdecl.} =
    touchEvent.onTouchEvent(bsDown, userData)
    # Treat Document Level Touch Event Listeners as Passive https://www.chromestatus.com/features/5093566007214080
    result = 0

proc onMouseUp(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onMouseButton(eventType, mouseEvent, userData, bsUp)

proc onTouchEnd(eventType: cint, touchEvent: ptr EmscriptenTouchEvent, userData: pointer): EM_BOOL {.cdecl.} =
    touchEvent.onTouchEvent(bsUp, userData)
    # Treat Document Level Touch Event Listeners as Passive https://www.chromestatus.com/features/5093566007214080
    result = 0

proc onMouseMove(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    let point = eventLocationFromJSEvent(mouseEvent, w, false)
    var evt = newMouseMoveEvent(point, sdlNow())
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onTouchMove(eventType: cint, touchEvent: ptr EmscriptenTouchEvent, userData: pointer): EM_BOOL {.cdecl.} =
    touchEvent.onTouchEvent(bsUnknown, userData)
    # Treat Document Level Touch Event Listeners as Passive https://www.chromestatus.com/features/5093566007214080
    result = 0

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
    let w = cast[EmscriptenWindow](userData)
    e.window = w
    if mainApplication().handleEvent(e) and not w.textInputActive: result = 1

proc onKeyDown(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onKey(keyEvent, userData, bsDown)

proc onKeyUp(eventType: cint, keyEvent: ptr EmscriptenKeyboardEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onKey(keyEvent, userData, bsUp)

proc c_strcmp(s1, s2: cstring): cint {.importc: "strcmp", nodecl.}

template isTargetWindow(event: ptr EmscriptenFocusEvent): bool = c_strcmp(cstring(addr event.nodeName[0]), "#window") == 0

proc onFocus(eventType: cint, event: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
    if event.isTargetWindow():
        let w = cast[EmscriptenWindow](userData)
        w.onFocusChange(true)

proc onBlur(eventType: cint, event: ptr EmscriptenFocusEvent, userData: pointer): EM_BOOL {.cdecl.} =
    if event.isTargetWindow():
        let w = cast[EmscriptenWindow](userData)
        w.onFocusChange(false)

template getDocumentSize(width, height: var float32) =
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

template setElementWidthHeight(elementName: cstring, w, h: float32) =
    discard EM_ASM_INT("""
    var c = document.getElementById(UTF8ToString($0));
    c.width = $1;
    c.height = $2;
    """, cstring(elementName), float32(w), float32(h))

proc updateCanvasSize(w: EmscriptenWindow) =
    w.pixelRatio = screenScaleFactor()

    let aspectRatio = w.bounds.width / w.bounds.height

    var width, height: float32
    getDocumentSize(width, height)

    when not defined(disableEmscriptenFixedRatio):
        const maxWidth = 1920
        const maxHeight = 1080

        let screenAspect = width / height

        var scaleFactor: Coord
        if (screenAspect > aspectRatio):
            scaleFactor = height / maxHeight
        else:
            scaleFactor = width / maxWidth

        width = maxWidth * scaleFactor
        height = maxHeight * scaleFactor

        if scaleFactor > 1: scaleFactor = 1
        let canvWidth = maxWidth * scaleFactor
        let canvHeight = maxHeight * scaleFactor
    else:
        let canvWidth = width
        let canvHeight = height

    setElementWidthHeight(w.canvasId, w.pixelRatio * canvWidth, w.pixelRatio * canvHeight)
    discard emscripten_set_element_css_size(w.canvasId, width, height)
    w.onResize(newSize(canvWidth, canvHeight))

proc onResize(eventType: cint, uiEvent: ptr EmscriptenUiEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    w.updateCanvasSize()
    result = 0

proc onOrientationChanged(eventType: cint, uiEvent: ptr EmscriptenOrientationChangeEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    w.updateCanvasSize()
    result = 0

proc onContextLost(eventType: cint, reserved: pointer, userData: pointer): EM_BOOL {.cdecl.} =
    error "WebGL context lost"
    discard EM_ASM_INT("""
    alert("WebGL context lost! Please try to restart or upgrade your browser.");
    """)

proc initCommon(w: EmscriptenWindow, r: view.Rect) =
    procCall init(w.Window, r)

    let id = EM_ASM_INT("""
    if (window.__nimx_canvas_id === undefined) {
        window.__nimx_canvas_id = 0;
    } else {
        ++window.__nimx_canvas_id;
    }
    let canvasId = UTF8ToString($2);
    var canvas;
    if(canvasId.length > 0){
        canvas = document.getElementById(canvasId);
    }
    else {
        canvas = document.createElement("canvas");
        canvas.width = $0;
        canvas.height = $1;
        canvas.id = "nimx_canvas" + window.__nimx_canvas_id;
        document.body.appendChild(canvas);
    }
    
    canvas.onclick = function() {
        if (window.__nimx_textinput && window.__nimx_textinput.oninput)
            window.__nimx_textinput.focus();
    };

    canvas.ontouchstart =
    canvas.oncontextmenu = function(e) {
        e.preventDefault();
        return false;
    };

    return window.__nimx_canvas_id;
    """, r.width, r.height, w.canvasId.cstring)

    if w.canvasId.len == 0:
        w.canvasId = "nimx_canvas" & $id

    var attrs: EmscriptenWebGLContextAttributes
    emscripten_webgl_init_context_attributes(addr attrs)
    attrs.premultipliedAlpha = 0
    attrs.alpha = 0
    attrs.antialias = 0
    attrs.stencil = 1
  
    # emscripten special selector, keep in sync with EMSCRIPTEN_EVENT_TARGET_DOCUMENT
    # and EMSCRIPTEN_EVENT_TARGET_WINDOW in emscripten html.h
    const documentSelector = "1"
    const windowSelector = "2"
    # regular css selector for the canvas
    let canvasSelector = "#" & w.canvasId

    w.ctx = emscripten_webgl_create_context(canvasSelector, addr attrs)
    if w.ctx <= 0:
        raise newException(Exception, "Could not create WebGL context: " & $w.ctx)
    discard emscripten_webgl_make_context_current(w.ctx)
    w.renderingContext = newGraphicsContext()

    discard emscripten_set_mousedown_callback(documentSelector, cast[pointer](w), 0, onMouseDown)
    discard emscripten_set_mouseup_callback(documentSelector, cast[pointer](w), 0, onMouseUp)
    discard emscripten_set_mousemove_callback(documentSelector, cast[pointer](w), 0, onMouseMove)
    discard emscripten_set_wheel_callback(documentSelector, cast[pointer](w), 0, onMouseWheel)

    discard emscripten_set_touchstart_callback(documentSelector, cast[pointer](w), 0, onTouchStart)
    discard emscripten_set_touchmove_callback(documentSelector, cast[pointer](w), 0, onTouchMove)
    discard emscripten_set_touchend_callback(documentSelector, cast[pointer](w), 0, onTouchEnd)
    discard emscripten_set_touchcancel_callback(documentSelector, cast[pointer](w), 0, onTouchEnd)

    discard emscripten_set_keydown_callback(documentSelector, cast[pointer](w), 1, onKeyDown)
    discard emscripten_set_keyup_callback(documentSelector, cast[pointer](w), 1, onKeyUp)

    discard emscripten_set_blur_callback(windowSelector, cast[pointer](w), 1, onBlur)
    discard emscripten_set_focus_callback(windowSelector, cast[pointer](w), 1, onFocus)

    discard emscripten_set_webglcontextlost_callback(canvasSelector, cast[pointer](w), 0, onContextLost)

    discard emscripten_set_fullscreenchange_callback(documentSelector, cast[pointer](w), 0, onFullscreenChange)

    discard emscripten_set_resize_callback(windowSelector, cast[pointer](w), 0, onResize)

    discard emscripten_set_orientationchange_callback(cast[pointer](w), 0, onOrientationChanged)

    mainApplication().addWindow(w)
    w.updateCanvasSize()

proc initFullscreen*(w: EmscriptenWindow) =
    var iw, ih: float
    getDocumentSize(iw, ih)
    w.initCommon(newRect(0, 0, iw, ih))

method init*(w: EmscriptenWindow, r: view.Rect) =
    w.initCommon(r)

proc newFullscreenEmscriptenWindow*(canvasId = ""): EmscriptenWindow =
    result.new()
    result.canvasId = canvasId
    result.initFullscreen()

proc newEmscriptenWindow*(r: view.Rect, canvasId = ""): EmscriptenWindow =
    result.new()
    result.canvasId = canvasId
    result.init(r)

newWindow = proc(r: view.Rect): Window =
    result = newEmscriptenWindow(r)

newFullscreenWindow = proc(): Window =
    result = newFullscreenEmscriptenWindow()

newWindowWithNative = proc(handle: pointer, r: Rect): Window =
    let canvasId = $cast[cstring](handle)
    result = newEmscriptenWindow(r, canvasId)

newFullscreenWindowWithNative = proc(handle: pointer): Window =
    let canvasId = $cast[cstring](handle)
    result = newFullscreenEmscriptenWindow(canvasId)

method drawWindow(w: EmscriptenWindow) =
    let c = w.renderingContext
    let oldContext = setCurrentContext(c)

    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    setCurrentContext(oldContext)

method onResize*(w: EmscriptenWindow, newSize: Size) =
    w.pixelRatio = screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * w.pixelRatio), GLsizei(newSize.height * w.pixelRatio))

    #TODO: figure out why info creates UTF8ToString() error and single char garbage output
    echo "EmscriptenWindow onResize viewport ", $(newSize.width * w.pixelRatio), " ", $(newSize.height * w.pixelRatio)
    procCall w.Window.onResize(newSize)

proc nimx_OnTextInput(wnd: pointer, text: cstring) {.EMSCRIPTEN_KEEPALIVE.} =
    var e = newEvent(etTextInput)
    e.window = cast[EmscriptenWindow](wnd)
    e.text = $text
    discard mainApplication().handleEvent(e)

method startTextInput*(w: EmscriptenWindow, r: Rect) =
    w.textInputActive = true
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
    """, cast[pointer](w))

method stopTextInput*(w: EmscriptenWindow) =
    w.textInputActive = false

    discard EM_ASM_INT("""
    if (window.__nimx_textinput !== undefined) {
        window.__nimx_textinput.oninput = null;
        window.__nimx_textinput.blur();
    }
    """)

var lastFullCollectTime = 0.0
const fullCollectThreshold = 128 * 1024 * 1024 # 128 Megabytes

proc nimxMainLoopInner() =
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
        nimxMainLoopInner()
    else:
        let r = EM_ASM_INT """
        return (document.readyState === 'complete') ? 1 : 0;
        """
        if r == 1:
            GC_disable() # GC Should only be called close to the bottom of the stack on emscripten.
            initFunc()
            initFunc = nil
            initDone = true

template runApplication*(initCode: typed) =
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
