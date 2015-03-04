import window
import sdl2
import logging
import view
import opengl
import context
import matrixes
import event

import times

type SdlWindow* = ref object of Window
    impl: WindowPtr
    sdlGlContext: GlContextPtr
    renderingContext: GraphicsContext
    font: FontData

var allWindows : seq[SdlWindow] = @[]

method drawWindow(w: SdlWindow)

proc animationCallback(p: pointer) {.cdecl.} =
    cast[SdlWindow](p).drawWindow()

proc enableAnimation(w: SdlWindow, flag: bool) =
    when defined(ios):
        if flag:
            discard iPhoneSetAnimationCallback(w.impl, 0, animationCallback, cast[pointer](w))
        else:
            discard iPhoneSetAnimationCallback(w.impl, 0, nil, nil)

method initCommon(w: SdlWindow, r: view.Rect) =
    if w.impl == nil:
        log("Could not create window!")
        quit 1
    procCall init(cast[Window](w), r)
    w.sdlGlContext = w.impl.glCreateContext()
    if w.sdlGlContext == nil:
        log "Could not create context!"
    discard glMakeCurrent(w.impl, w.sdlGlContext)
    w.renderingContext = newGraphicsContext()
    w.font = my_stbtt_initfont()

    w.enableAnimation(true)
    allWindows.add(w)
    discard w.impl.setData("__nimx_wnd", cast[pointer](w))

method initFullscreen*(w: SdlWindow) =
    var displayMode : DisplayMode
    discard getDesktopDisplayMode(0, displayMode)
    let flags = SDL_WINDOW_OPENGL or SDL_WINDOW_FULLSCREEN
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

var lastTime = getTicks()
var lastFrame = 0.0

proc fps(): int =
    let curTime = getTicks()
    let thisFrame = curTime - lastTime
    lastFrame = (lastFrame * 0.9 + thisFrame.float * 0.1)
    result = (1.0 / lastFrame * 1000.0).int
    lastTime = curTime

method drawWindow(w: SdlWindow) =
    glViewport(0, 0, GLsizei(w.frame.width), GLsizei(w.frame.height))

    glClear(GL_COLOR_BUFFER_BIT) # Clear color and depth buffers

    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    defer: setCurrentContext(oldContext)
    var transform : Transform3D
    transform.ortho(0, w.frame.width, w.frame.height, 0, -1, 1)
    let oldTransform = c.setScopeTransform(transform)

    w.recursiveDrawSubviews()

    var pt = newPoint(w.frame.width - 130, 25)
    c.fillColor = newColor(0.5, 0, 0)
    c.my_stbtt_print(w.font, pt, "FPS: " & $fps())
    c.testPoly()
 
    c.revertTransform(oldTransform)
    w.impl.glSwapWindow() # Swap the front and back frame buffers (double buffering)

proc waitOrPollEvent(evt: var sdl2.Event): auto =
    when defined(ios):
        waitEvent(evt)
    else:
        pollEvent(evt)

proc handleSdlEvent(w: SdlWindow, e: WindowEventObj): bool =
    case e.event:
        of WindowEvent_Resized:
            w.onResize(newSize(Coord(e.data1), Coord(e.data2)))
            return true
        else: discard
    return false

type EventHandler = proc (e: ptr sdl2.Event): Bool32

var eventHandler: EventHandler = nil

proc windowFromSDLEvent[T](event: T): SdlWindow =
    let sdlWndId = event.windowID
    let sdlWin = getWindowFromID(sdlWndId)
    if sdlWin != nil:
        result = cast[SdlWindow](sdlWin.getData("__nimx_wnd"))

proc positionFromSDLEvent[T](event: T): auto =
    newPoint(event.x.Coord, event.y.Coord)


proc eventFilter(userdata: pointer; event: ptr sdl2.Event): Bool32 {.cdecl.} =
    var handled = false
    case event.kind:
        of FingerMotion:
            #log("finger motion")
            handled = true
        of FingerDown:
            log("Finger down")
            handled = true
        of FingerUp:
            log("Finger up")
            handled = true
        of WindowEvent:
            let wndEv = cast[WindowEventPtr](event)
            let wnd = windowFromSDLEvent(wndEv)
            if wnd != nil:
                handled = wnd.handleSdlEvent(wndEv[])

        of MouseButtonDown, MouseButtonUp:
            let mouseEv = cast[MouseButtonEventPtr](event)
            let wnd = windowFromSDLEvent(mouseEv)
            let state = if mouseEv.state == 1: bsDown else: bsUp
            let button = case mouseEv.button:
                of 0: kcMouseButtonPrimary
                of 1: kcMouseButtonMiddle
                of 2: kcMouseButtonSecondary
                else: kcUnknown
            if wnd != nil:
                let pos = positionFromSDLEvent(mouseEv)
                var evt = newMouseButtonEvent(pos, button, state)
                handled = wnd.recursiveHandleMouseEvent(evt)
        
        of MouseMotion:
            let mouseEv = cast[MouseMotionEventPtr](event)
            let wnd = windowFromSDLEvent(mouseEv)
            if wnd != nil:
                let pos = positionFromSDLEvent(mouseEv)
                var evt = newMouseMoveEvent(pos)
                handled = wnd.recursiveHandleMouseEvent(evt)

        of AppWillEnterBackground:
            log "will enter back"
            for wnd in allWindows:
                wnd.enableAnimation(false)

        of AppWillEnterForeground:
            log "will enter fore"
            for wnd in allWindows:
                wnd.enableAnimation(true)

        else: discard
    #log "Event: ", $event.kind
    if handled:
        return False32
    if eventHandler != nil:
        return eventHandler(event)
    return True32

proc setEventHandler*(handler: EventHandler) =
    eventHandler = handler

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
            for wnd in allWindows:
                wnd.drawWindow()
            #limitFramerate()

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

