import window
import sdl2 except Event, Rect
import logging
import view
import opengl
import context
import event
import font
import unicode
import app

export window

type SdlWindow* = ref object of Window
    impl: WindowPtr
    sdlGlContext: GlContextPtr
    renderingContext: GraphicsContext


method enableAnimation*(w: SdlWindow, flag: bool) =
    when defined(ios):
        if flag:
            proc animationCallback(p: pointer) {.cdecl.} =
                cast[SdlWindow](p).drawWindow()
            discard iPhoneSetAnimationCallback(w.impl, 0, animationCallback, cast[pointer](w))
        else:
            discard iPhoneSetAnimationCallback(w.impl, 0, nil, nil)
    discard # Seems like a Nim bug. Empty method will result in a link error.

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

    w.enableAnimation(true)
    mainApplication().addWindow(w)
    discard w.impl.setData("__nimx_wnd", cast[pointer](w))

method initFullscreen*(w: SdlWindow) =
    var displayMode : DisplayMode
    discard getDesktopDisplayMode(0, displayMode)
    let flags = SDL_WINDOW_OPENGL or SDL_WINDOW_FULLSCREEN or SDL_WINDOW_RESIZABLE
    w.impl = createWindow(nil, 0, 0, displayMode.w, displayMode.h, flags)

    discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, 0x0004)
    discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)

    var width, height : cint
    w.impl.getSize(width, height)
    w.initCommon(newRect(0, 0, Coord(width), Coord(height)))

method init*(w: SdlWindow, r: view.Rect) =
    when defined(ios):
        w.initFullscreen()
    else:
        w.impl = createWindow(nil, cint(r.x), cint(r.y), cint(r.width), cint(r.height), SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE)
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
    glViewport(0, 0, GLsizei(w.frame.width), GLsizei(w.frame.height))

    glClear(GL_COLOR_BUFFER_BIT) # Clear color and depth buffers

    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    defer: setCurrentContext(oldContext)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    w.impl.glSwapWindow() # Swap the front and back frame buffers (double buffering)

proc waitOrPollEvent(evt: var sdl2.Event): auto =
    when defined(ios):
        waitEvent(evt)
    else:
        pollEvent(evt)

proc windowFromSDLEvent[T](event: T): SdlWindow =
    let sdlWndId = event.windowID
    let sdlWin = getWindowFromID(sdlWndId)
    if sdlWin != nil:
        result = cast[SdlWindow](sdlWin.getData("__nimx_wnd"))

proc positionFromSDLEvent[T](event: T): auto =
    newPoint(event.x.Coord, event.y.Coord)

proc buttonStateFromSDLState(s: KeyState): ButtonState =
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
            logi("Finger down")
        of FingerUp:
            logi("Finger up")
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
                of 0: kcMouseButtonPrimary
                of 1: kcMouseButtonMiddle
                of 2: kcMouseButtonSecondary
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

proc eventFilter(userdata: pointer; event: ptr sdl2.Event): Bool32 {.cdecl.} =
    var e = eventWithSDLEvent(event)
    var handled = mainApplication().handleEvent(e)
    result = if handled: False32 else: True32

method onResize*(w: SdlWindow, newSize: Size) =
    glViewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    procCall w.Window.onResize(newSize)

# Framerate limiter
let MAXFRAMERATE: uint32 = 20 # milli seconds
var frametime: uint32

proc limitFramerate() =
    var now = getTicks()
    if frametime > now:
        delay(frametime - now)
    frametime = frametime + MAXFRAMERATE

proc nextEvent*(evt: var sdl2.Event): bool =
    #PumpEvents()
    result = waitOrPollEvent(evt)

    when not defined(ios):
        if not result:
            mainApplication().runAnimations()
            mainApplication().drawWindows()
            #limitFramerate()

method startTextInput*(w: SdlWindow, r: Rect) =
    startTextInput()

method stopTextInput*(w: SdlWindow) =
    stopTextInput()

proc runUntilQuit*() =
    var isRunning = true

    # Initialize fist dummy event. The kind should be any unused kind.
    var evt = sdl2.Event(kind: UserEvent1)
    setEventFilter(eventFilter, nil)

    # Main loop
    while isRunning:
        discard nextEvent(evt)
        if evt.kind == QuitEvent:
          isRunning = false
          break
 
    discard quit(evt)

