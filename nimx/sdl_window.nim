import window
import sdl2 except Event, Rect
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

export window

proc initSDLIfNeeded() =
    var sdlInitialized {.global.} = false
    if not sdlInitialized:
        sdl2.init(INIT_VIDEO)
        sdlInitialized = true
        let r = glSetAttribute(SDL_GL_STENCIL_SIZE, 8)
        if r != 0:
            logi "Error: could not set stencil size: ", r

        when defined(ios) or defined(android):
            discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, 0x0004)
            discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)


type SdlWindow* = ref object of Window
    impl: WindowPtr
    sdlGlContext: GlContextPtr
    renderingContext: GraphicsContext

var animationEnabled = 0

method enableAnimation*(w: SdlWindow, flag: bool) =
    if flag:
        inc animationEnabled
        when defined(ios):
            proc animationCallback(p: pointer) {.cdecl.} =
                let w = cast[SdlWindow](p)
                w.runAnimations()
                w.drawWindow()
            discard iPhoneSetAnimationCallback(w.impl, 0, animationCallback, cast[pointer](w))
    else:
        dec animationEnabled
        when defined(ios):
            discard iPhoneSetAnimationCallback(w.impl, 0, nil, nil)

method initCommon(w: SdlWindow, r: view.Rect) =
    if w.impl == nil:
        logi "Could not create window!"
        quit 1
    procCall init(w.Window, r)
    w.sdlGlContext = w.impl.glCreateContext()
    if w.sdlGlContext == nil:
        logi "Could not create context!"
    discard glMakeCurrent(w.impl, w.sdlGlContext)
    w.renderingContext = newGraphicsContext()

    #w.enableAnimation(true)
    mainApplication().addWindow(w)
    discard w.impl.setData("__nimx_wnd", cast[pointer](w))

method initFullscreen*(w: SdlWindow) =
    initSDLIfNeeded()
    var displayMode : DisplayMode
    discard getDesktopDisplayMode(0, displayMode)
    let flags = SDL_WINDOW_OPENGL or SDL_WINDOW_FULLSCREEN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_ALLOW_HIGHDPI
    w.impl = createWindow(nil, 0, 0, displayMode.w, displayMode.h, flags)

    var width, height : cint
    w.impl.getSize(width, height)
    w.initCommon(newRect(0, 0, Coord(width), Coord(height)))

method init*(w: SdlWindow, r: view.Rect) =
    when defined(ios):
        w.initFullscreen()
    else:
        initSDLIfNeeded()
        w.impl = createWindow(nil, cint(r.x), cint(r.y), cint(r.width), cint(r.height), SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE or SDL_WINDOW_ALLOW_HIGHDPI)
        w.initCommon(newRect(0, 0, r.width, r.height))

proc newFullscreenSdlWindow*(): SdlWindow =
    result.new()
    result.initFullscreen()

proc newSdlWindow*(r: view.Rect): SdlWindow =
    result.new()
    result.init(r)

method `title=`*(w: SdlWindow, t: string) =
    w.impl.setTitle(t)

method title*(w: SdlWindow): string = $w.impl.getTitle()


method drawWindow(w: SdlWindow) =
    let c = w.renderingContext
    #c.gl.viewport(0, 0, w.frame.width.GLsizei, w.frame.height.GLsizei)
    c.gl.stencilMask(0xFF) # Android requires setting stencil mask to clear
    c.gl.clear(c.gl.COLOR_BUFFER_BIT or c.gl.STENCIL_BUFFER_BIT or c.gl.DEPTH_BUFFER_BIT)
    c.gl.stencilMask(0x00)
    let oldContext = setCurrentContext(c)

    defer: setCurrentContext(oldContext)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    w.impl.glSwapWindow() # Swap the front and back frame buffers (double buffering)

proc windowFromSDLEvent[T](event: T): SdlWindow =
    let sdlWndId = event.windowID
    let sdlWin = getWindowFromID(sdlWndId)
    if sdlWin != nil:
        result = cast[SdlWindow](sdlWin.getData("__nimx_wnd"))

proc positionFromSDLEvent[T](event: T): auto =
    newPoint(event.x.Coord, event.y.Coord)

template buttonStateFromSDLState(s: KeyState): ButtonState =
    if s == KeyPressed:
        bsDown
    else:
        bsUp

proc eventWithSDLEvent(event: ptr sdl2.Event): Event =
    case event.kind:
        of FingerMotion:
            discard
            #logi("finger motion")
        of FingerDown:
            #logi("Finger down")
            discard
        of FingerUp:
            #logi("Finger up")
            discard
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
            let mouseEv = cast[MouseButtonEventPtr](event)
            let wnd = windowFromSDLEvent(mouseEv)
            let state = buttonStateFromSDLState(mouseEv.state.KeyState)
            let button = case mouseEv.button:
                of sdl2.BUTTON_LEFT: kcMouseButtonPrimary
                of sdl2.BUTTON_MIDDLE: kcMouseButtonMiddle
                of sdl2.BUTTON_RIGHT: kcMouseButtonSecondary
                else: kcUnknown
            let pos = positionFromSDLEvent(mouseEv)
            result = newMouseButtonEvent(pos, button, state)
            result.window = wnd

        of MouseMotion:
            let mouseEv = cast[MouseMotionEventPtr](event)
            let wnd = windowFromSDLEvent(mouseEv)
            if wnd != nil:
                let pos = positionFromSDLEvent(mouseEv)
                result = newMouseMoveEvent(pos)
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
            result = newKeyboardEvent(keyEv.keysym.sym, buttonStateFromSDLState(keyEv.state.KeyState), keyEv.repeat)
            result.rune = keyEv.keysym.unicode.Rune
            result.window = wnd

        of TextInput:
            let textEv = cast[TextInputEventPtr](event)
            result = newEvent(etTextInput)
            result.window = windowFromSDLEvent(textEv)
            result.text = $cast[cstring](addr textEv.text)

        of TextEditing:
            echo "Editing:"
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

# The following function may be called on a foreign thread.
{.push stack_trace: off.}
proc eventFilter(userdata: pointer; event: ptr sdl2.Event): Bool32 {.cdecl.} =
    if event.kind != UserEvent5: # Callback events should be passed to main thread.
        # This branch should never execute on a foreign thread!!!
        var e = eventWithSDLEvent(event)
        discard mainApplication().handleEvent(e)
    result = True32
{.pop.}

method onResize*(w: SdlWindow, newSize: Size) =
    let sf = screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * sf), GLsizei(newSize.height * sf))
    procCall w.Window.onResize(newSize)

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

proc nextEvent(evt: var sdl2.Event): bool =
    when defined(ios):
        result = waitEvent(evt)
    else:
        if animationEnabled > 0:
            result = pollEvent(evt)
        else:
            result = waitEvent(evt)

    if result == True32 and evt.kind == UserEvent5:
        handleCallbackEvent(cast[UserEventPtr](addr evt))

    animateAndDraw()

method startTextInput*(w: SdlWindow, r: Rect) =
    startTextInput()

method stopTextInput*(w: SdlWindow) =
    stopTextInput()

proc runUntilQuit*() =
    # Initialize fist dummy event. The kind should be any unused kind.
    var evt = sdl2.Event(kind: UserEvent1)
    setEventFilter(eventFilter, nil)
    animateAndDraw()

    # Main loop
    while true:
        discard nextEvent(evt)
        if evt.kind == QuitEvent:
            break

    discard quit(evt)
