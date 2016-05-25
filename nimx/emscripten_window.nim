import abstract_window
import system_logger
import view
import opengl
import context
import event
import font
import unicode
import app
import linkage_details
import portable_gl
import screen
import emscripten

type EmscriptenWindow* = ref object of Window
    ctx: EMSCRIPTEN_WEBGL_CONTEXT_HANDLE
    renderingContext: GraphicsContext

var animationEnabled = 0

method enableAnimation*(w: EmscriptenWindow, flag: bool) =
    discard

# SDL does not provide window id in touch event info, so we add this workaround
# assuming that touch devices may have only one window.
var defaultWindow: EmscriptenWindow

proc onMouseButton(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer, bs: ButtonState): EM_BOOL =
    let w = cast[EmscriptenWindow](userData)
    template bcFromE(): VirtualKey =
        case mouseEvent.button:
        of 0: VirtualKey.MouseButtonPrimary
        of 2: VirtualKey.MouseButtonSecondary
        of 1: VirtualKey.MouseButtonMiddle
        else: VirtualKey.Unknown

    var evt = newMouseButtonEvent(newPoint(Coord(mouseEvent.targetX), Coord(mouseEvent.targetY)), bcFromE(), bs, uint32(mouseEvent.timestamp))
    evt.window = w
    if mainApplication().handleEvent(evt): result = 1

proc onMouseDown(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onMouseButton(eventType, mouseEvent, userData, bsDown)

proc onMouseUp(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    onMouseButton(eventType, mouseEvent, userData, bsUp)

proc onMouseMove(eventType: cint, mouseEvent: ptr EmscriptenMouseEvent, userData: pointer): EM_BOOL {.cdecl.} =
    let w = cast[EmscriptenWindow](userData)
    var evt = newMouseMoveEvent(newPoint(Coord(mouseEvent.targetX), Coord(mouseEvent.targetY)), uint32(mouseEvent.timestamp))
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

    let canvId = "nimx_canvas" & $id

    var attrs: EmscriptenWebGLContextAttributes
    emscripten_webgl_init_context_attributes(addr attrs)
    attrs.premultipliedAlpha = 0
    attrs.alpha = 0
    w.ctx = emscripten_webgl_create_context(canvId, addr attrs)
    discard emscripten_webgl_make_context_current(w.ctx)
    w.renderingContext = newGraphicsContext()

    discard emscripten_set_mousedown_callback(canvId, cast[pointer](w), 0, onMouseDown)
    discard emscripten_set_mouseup_callback(canvId, cast[pointer](w), 0, onMouseUp)
    discard emscripten_set_mousemove_callback(canvId, cast[pointer](w), 0, onMouseMove)
    discard emscripten_set_wheel_callback(canvId, cast[pointer](w), 0, onMouseWheel)

    #w.enableAnimation(true)
    mainApplication().addWindow(w)
    w.onResize(r.size)

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

#[
proc windowFromSDLEvent[T](event: T): EmscriptenWindow =
    let sdlWndId = event.windowID
    let sdlWin = getWindowFromID(sdlWndId)
    if sdlWin != nil:
        result = cast[EmscriptenWindow](sdlWin.getData("__nimx_wnd"))

proc positionFromSDLEvent[T](event: T): auto =
    newPoint(event.x.Coord, event.y.Coord)

template buttonStateFromSDLState(s: KeyState): ButtonState =
    if s == KeyPressed:
        bsDown
    else:
        bsUp

var activeTouches = 0

proc eventWithSDLEvent(event: ptr sdl2.Event): Event =
    case event.kind:
        of FingerMotion, FingerDown, FingerUp:
            let bs = case event.kind
                of FingerDown: bsDown
                of FingerUp: bsUp
                else: bsUnknown
            let touchEv = cast[TouchFingerEventPtr](event)
            result = newTouchEvent(
                                   newPoint(touchEv.x * defaultWindow.frame.width, touchEv.y * defaultWindow.frame.height),
                                   bs, int(touchEv.fingerID), touchEv.timestamp
                                   )
            if bs == bsDown:
                inc activeTouches
                if activeTouches == 1:
                    result.pointerId = 0
            elif bs == bsUp:
                dec activeTouches
            #logi "EVENT: ", result.position, " ", result.buttonState
            result.window = defaultWindow
            result.kind = etUnknown # TODO: Fix apple trackpad problem

        of WindowEvent:
            let wndEv = cast[WindowEventPtr](event)
            let wnd = windowFromSDLEvent(wndEv)
            case wndEv.event:
                of WindowEvent_Resized:
                    result = newEvent(etWindowResized)
                    result.window = wnd
                    result.position.x = wndEv.data1.Coord
                    result.position.y = wndEv.data2.Coord
                else:
                    discard

        of MouseButtonDown, MouseButtonUp:
            when not defined(ios) and not defined(android):
                if event.kind == MouseButtonDown:
                    discard sdl2.captureMouse(True32)
                else:
                    discard sdl2.captureMouse(False32)

            let mouseEv = cast[MouseButtonEventPtr](event)
            if mouseEv.which != SDL_TOUCH_MOUSEID:
                let wnd = windowFromSDLEvent(mouseEv)
                let state = buttonStateFromSDLState(mouseEv.state.KeyState)
                let button = case mouseEv.button:
                    of sdl2.BUTTON_LEFT: VirtualKey.MouseButtonPrimary
                    of sdl2.BUTTON_MIDDLE: VirtualKey.MouseButtonMiddle
                    of sdl2.BUTTON_RIGHT: VirtualKey.MouseButtonSecondary
                    else: VirtualKey.Unknown
                let pos = positionFromSDLEvent(mouseEv)
                result = newMouseButtonEvent(pos, button, state, mouseEv.timestamp)
                result.window = wnd

        of MouseMotion:
            let mouseEv = cast[MouseMotionEventPtr](event)
            if mouseEv.which != SDL_TOUCH_MOUSEID:
                #logi("which: " & $mouseEv.which)
                let wnd = windowFromSDLEvent(mouseEv)
                if wnd != nil:
                    let pos = positionFromSDLEvent(mouseEv)
                    result = newMouseMoveEvent(pos, mouseEv.timestamp)
                    result.window = wnd

        of MouseWheel:
            let mouseEv = cast[MouseWheelEventPtr](event)
            let wnd = windowFromSDLEvent(mouseEv)
            if wnd != nil:
                var x, y: cint
                getMouseState(x, y)
                let pos = newPoint(x.Coord, y.Coord)
                result = newEvent(etScroll, pos)
                result.window = wnd
                result.offset.x = mouseEv.x.Coord
                result.offset.y = mouseEv.y.Coord

        of KeyDown, KeyUp:
            let keyEv = cast[KeyboardEventPtr](event)
            let wnd = windowFromSDLEvent(keyEv)
            result = newKeyboardEvent(virtualKeyFromNative(keyEv.keysym.sym), buttonStateFromSDLState(keyEv.state.KeyState), keyEv.repeat)
            result.rune = keyEv.keysym.unicode.Rune
            result.window = wnd

        of TextInput:
            let textEv = cast[TextInputEventPtr](event)
            result = newEvent(etTextInput)
            result.window = windowFromSDLEvent(textEv)
            result.text = $cast[cstring](addr textEv.text)

        of TextEditing:
            let textEv = cast[TextEditingEventPtr](event)
            result = newEvent(etTextInput)
            result.window = windowFromSDLEvent(textEv)
            result.text = $cast[cstring](addr textEv.text)

        of AppWillEnterBackground:
            result = newEvent(etAppWillEnterBackground)

        of AppWillEnterForeground:
            result = newEvent(etAppWillEnterForeground)

        else:
            #echo "Unknown event: ", event.kind
            discard

proc handleEvent(event: ptr sdl2.Event): Bool32 =
    if event.kind == UserEvent5:
        let evt = cast[UserEventPtr](event)
        let p = cast[proc (data: pointer) {.cdecl.}](evt.data1)
        if p.isNil:
            logi "WARNING: UserEvent5 with nil proc"
        else:
            p(evt.data2)
    else:
        # This branch should never execute on a foreign thread!!!
        var e = eventWithSDLEvent(event)
        if (e.kind != etUnknown):
            discard mainApplication().handleEvent(e)
    result = True32
]#
method onResize*(w: EmscriptenWindow, newSize: Size) =
    let sf = 1.0 #screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * sf), GLsizei(newSize.height * sf))
    procCall w.Window.onResize(newSize)
#[
# Framerate limiter
let MAXFRAMERATE: uint32 = 20 # milli seconds
var frametime: uint32

proc limitFramerate() =
    var now = getTicks()
    if frametime > now:
        delay(frametime - now)
    frametime = frametime + MAXFRAMERATE

proc animateAndDraw() =
    when not defined ios:
        mainApplication().runAnimations()
        mainApplication().drawWindows()
    else:
        if animationEnabled == 0:
            mainApplication().runAnimations()
            mainApplication().drawWindows()

proc handleCallbackEvent(evt: UserEventPtr) =
    let p = cast[proc (data: pointer) {.cdecl.}](evt.data1)
    if p.isNil:
        logi "WARNING: UserEvent5 with nil proc"
    else:
        p(evt.data2)

proc nextEvent(evt: var sdl2.Event) =
    when defined(ios):
        if waitEvent(evt):
            discard handleEvent(addr evt)
    else:
        var doPoll = false
        if animationEnabled > 0:
            doPoll = true
        elif waitEvent(evt):
            discard handleEvent(addr evt)
            doPoll = evt.kind != QuitEvent
        # TODO: This should be researched more carefully.
        # During animations we need to process more than one event
        if doPoll:
            while pollEvent(evt):
                discard handleEvent(addr evt)
                if evt.kind == QuitEvent:
                    break

    animateAndDraw()

method startTextInput*(w: EmscriptenWindow, r: Rect) =
    startTextInput()

method stopTextInput*(w: EmscriptenWindow) =
    stopTextInput()

proc runUntilQuit*() =
    # Initialize fist dummy event. The kind should be any unused kind.
    var evt = sdl2.Event(kind: UserEvent1)
    #setEventFilter(eventFilter, nil)
    animateAndDraw()

    # Main loop
    while true:
        nextEvent(evt)
        if evt.kind == QuitEvent:
            break

    discard quit(evt)
]#

proc mainLoop() {.cdecl.} =
    mainApplication().runAnimations()
    mainApplication().drawWindows()
    GC_fullCollect()

var initFunc : proc()

var initDone = false
proc mainLoopPreload() {.cdecl.} =
    if initDone:
        mainLoop()
    else:
        let r = EM_ASM_INT """
        if (document.readyState === 'complete') {
            return 1;
        }
        return 0;
        """
        if r == 1:
            GC_disable()
            initFunc()
            initDone = true

template runApplication*(initCode: typed): stmt =
    initFunc = proc() =
        initCode
    emscripten_set_main_loop(mainLoopPreload, 0, 1)
