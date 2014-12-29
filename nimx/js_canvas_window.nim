import window
import logging
import view
#import patched_temp_stuff.opengl
import context
import matrixes
import dom

type JSCanvasWindow* = ref object of Window
    impl: PWindow
    renderingContext: GraphicsContext


method drawWindow(w: JSCanvasWindow)

proc enableAnimation(w: SdlWindow, flag: bool) =
    when defined(ios):
        if flag:
            discard iPhoneSetAnimationCallback(w.impl, 0, animationCallback, cast[pointer](w))
        else:
            discard iPhoneSetAnimationCallback(w.impl, 0, nil, nil)

method initWithCanvasId(w: JSCanvasWindow, id: string) =
    let canvas = document.getElementById(id)

    procCall init(cast[Window](w), r)
    w.sdlGlContext = w.impl.GL_CreateContext()
    if w.sdlGlContext == nil:
        log "Could not create context!"
    discard GL_MakeCurrent(w.impl, w.sdlGlContext)
    w.renderingContext = newGraphicsContext()

    w.enableAnimation(true)
    allWindows.add(w)
    discard w.impl.SetData("__nimx_wnd", cast[pointer](w))

proc newJSCanvasWindow(canvasId: string): JSCanvasWindow =
    result.new()
    result.initWithCanvasId(canvasId)

method drawWindow(w: SdlWindow) =
    glViewport(0, 0, GLsizei(w.frame.width), GLsizei(w.frame.height))

    glClear(GL_COLOR_BUFFER_BIT) # Clear color and depth buffers

    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    defer: setCurrentContext(oldContext)
    var transform : Transform3D
    transform.ortho(0, w.frame.width, 0, w.frame.height, -1, 1)
    let oldTransform = c.setScopeTransform(transform)

    w.recursiveDrawSubviews()
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
    PumpEvents()
    result = waitOrPollEvent(evt)

    when not defined(ios):
        if not result:
            for wnd in allWindows:
                wnd.drawWindow()
            limitFramerate()

