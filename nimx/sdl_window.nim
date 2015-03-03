import window
import sdl2
import logging
import view
import opengl
import context
import matrixes

import times

type SdlWindow* = ref object of Window
    impl: PWindow
    sdlGlContext: PGLContext
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
    w.sdlGlContext = w.impl.GL_CreateContext()
    if w.sdlGlContext == nil:
        log "Could not create context!"
    echo GL_SetSwapInterval(0)
    discard GL_MakeCurrent(w.impl, w.sdlGlContext)
    w.renderingContext = newGraphicsContext()
    w.font = my_stbtt_initfont()

    w.enableAnimation(true)
    allWindows.add(w)
    discard w.impl.SetData("__nimx_wnd", cast[pointer](w))

method initFullscreen*(w: SdlWindow) =
    var displayMode : TDisplayMode
    discard GetDesktopDisplayMode(0, displayMode)
    let flags = SDL_WINDOW_OPENGL or SDL_WINDOW_FULLSCREEN
    w.impl = CreateWindow(nil, 0, 0, displayMode.w, displayMode.h, flags)

    discard GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, 0x0004)
    discard GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)

    var width, height : cint
    w.impl.getSize(width, height)
    w.initCommon(newRect(0, 0, Coord(width), Coord(height)))

method init*(w: SdlWindow, r: view.Rect) =
    when defined(ios):
        w.initFullscreen()
    else:
        w.impl = CreateWindow(nil, cint(r.x), cint(r.y), cint(r.width), cint(r.height), SDL_WINDOW_OPENGL or SDL_WINDOW_RESIZABLE)
        w.initCommon(newRect(0, 0, r.width, r.height))

proc newFullscreenSdlWindow*(): SdlWindow =
    result.new()
    result.initFullscreen()

proc newSdlWindow*(r: view.Rect): SdlWindow =
    result.new()
    result.init(r)

method `title=`*(w: SdlWindow, t: string) =
    w.impl.SetTitle(t)

method title*(w: SdlWindow): string = $w.impl.GetTitle()

var lastTime = GetTicks()
var lastFrame = 0.0

proc fps(): int =
    let curTime = GetTicks()
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

    var pt = newPoint(300, 300)
    c.fillColor = newColor(0.5, 0, 0)
    c.my_stbtt_print(w.font, pt, $fps())
    c.testPoly()
 
    c.revertTransform(oldTransform)
    w.impl.GL_SwapWindow() # Swap the front and back frame buffers (double buffering)

proc waitOrPollEvent(evt: var TEvent): auto =
    when defined(ios):
        WaitEvent(evt)
    else:
        PollEvent(evt)

proc handleSdlEvent(w: SdlWindow, e: TWindowEvent): bool =
    case e.event:
        of WindowEvent_Resized:
            w.onResize(newSize(Coord(e.data1), Coord(e.data2)))
            return true
        else: discard
    return false

type EventHandler = proc (e: ptr TEvent): Bool32

var eventHandler: EventHandler

proc eventFilter(userdata: pointer; event: ptr TEvent): Bool32 {.cdecl.} =
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
            let wndEv = cast[PWindowEvent](event)
            let sdlWndId = wndEv.windowID
            let sdlWin = GetWindowFromID(sdlWndId)
            if sdlWin != nil:
                let wnd = cast[SdlWindow](sdlWin.GetData("__nimx_wnd"))
                if wnd != nil:
                    handled = wnd.handleSdlEvent(wndEv[])
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
    return eventHandler(event)

proc setEventHandler*(handler: EventHandler) =
    eventHandler = handler
    SetEventFilter(eventFilter, nil)

method onResize*(w: SdlWindow, newSize: Size) =
    glViewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    w.frame.size = newSize
    w.bounds.size = newSize

# Framerate limiter
let MAXFRAMERATE: uint32 = 20 # milli seconds
var frametime: uint32 

proc limitFramerate() =
    var now = GetTicks()
    if frametime > now:
        Delay(frametime - now)
    frametime = frametime + MAXFRAMERATE

proc nextEvent*(evt: var TEvent): bool =
    #PumpEvents()
    result = waitOrPollEvent(evt)

    when not defined(ios):
        if not result:
            for wnd in allWindows:
                wnd.drawWindow()
            #limitFramerate()

