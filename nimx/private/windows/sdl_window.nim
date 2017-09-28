import sdl2 except Event, Rect

import nimx/[ abstract_window, system_logger, view, context, event, app, screen,
                linkage_details, portable_gl ]
import nimx.private.sdl_vk_map
import opengl


export abstract_window

proc initSDLIfNeeded() =
    var sdlInitialized {.global.} = false
    if not sdlInitialized:
        if sdl2.init(INIT_VIDEO) != SdlSuccess:
            logi "Error: sdl2.init(INIT_VIDEO): ", getError()
        sdlInitialized = true
        if glSetAttribute(SDL_GL_STENCIL_SIZE, 8) != 0:
            logi "Error: could not set stencil size: ", getError()

        when defined(ios) or defined(android):
            discard glSetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, 0x0004)
            discard glSetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2)

type SdlWindow* = ref object of Window
    impl: WindowPtr
    sdlGlContext: GlContextPtr
    renderingContext: GraphicsContext
    isFullscreen: bool

when defined(ios) or defined(android):
    method fullscreen*(w: SdlWindow): bool = true
else:
    method fullscreenAvailable*(w: SdlWindow): bool = true
    method fullscreen*(w: SdlWindow): bool = w.isFullscreen
    method `fullscreen=`*(w: SdlWindow, v: bool) =
        var res: SDL_Return = SdlError

        if v and not w.isFullscreen:
            res = w.impl.setFullscreen(SDL_WINDOW_FULLSCREEN_DESKTOP)
        elif not v and w.isFullscreen:
            res = w.impl.setFullscreen(0)

        if res == SdlSuccess:
            w.isFullscreen = v

when defined(macosx) and not defined(ios):
    import darwin.app_kit.nswindow
    proc scaleFactor(w: SdlWindow): float32 =
        var wminfo: WMInfo
        discard w.impl.getWMInfo(wminfo)
        let nsWindow = cast[ptr NSWindow](addr wminfo.padding[0])[]
        assert(not nsWindow.isNil)
        result = nsWindow.scaleFactor

proc getSDLWindow*(wnd: SdlWindow): WindowPtr = wnd.impl

var animationEnabled = 0

method enableAnimation*(w: SdlWindow, flag: bool) =
    doAssert( (animationEnabled == 0 and flag) or (animationEnabled != 0 and not flag) , "animationEnabled: " & $animationEnabled & " flag: " & $flag)
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

# SDL does not provide window id in touch event info, so we add this workaround
# assuming that touch devices may have only one window.
var defaultWindow: SdlWindow

proc initCommon(w: SdlWindow, r: view.Rect) =
    if w.impl == nil:
        logi "Could not create window!"
        quit 1
    if defaultWindow.isNil:
        defaultWindow = w
    procCall init(w.Window, r)
    discard glSetAttribute(SDL_GL_SHARE_WITH_CURRENT_CONTEXT, 1)
    w.sdlGlContext = w.impl.glCreateContext()
    if w.sdlGlContext == nil:
        logi "Could not create context!"
    discard glMakeCurrent(w.impl, w.sdlGlContext)
    w.renderingContext = newGraphicsContext()

    mainApplication().addWindow(w)
    discard w.impl.setData("__nimx_wnd", cast[pointer](w))
    w.onResize(r.size)

proc initFullscreen*(w: SdlWindow) =
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

newWindow = proc(r: view.Rect): Window =
    result = newSdlWindow(r)

newFullscreenWindow = proc(): Window =
    result = newFullscreenSdlWindow()

method `title=`*(w: SdlWindow, t: string) =
    w.impl.setTitle(t)

method title*(w: SdlWindow): string = $w.impl.getTitle()

method draw*(w: SdlWindow, r: Rect) =
    let c = currentContext()
    let gl = c.gl
    if w.mActiveBgColor != w.backgroundColor:
        gl.clearColor(w.backgroundColor.r, w.backgroundColor.g, w.backgroundColor.b, w.backgroundColor.a)
        w.mActiveBgColor = w.backgroundColor
    gl.stencilMask(0xFF) # Android requires setting stencil mask to clear
    gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)
    gl.stencilMask(0x00)

method drawWindow(w: SdlWindow) =
    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    w.impl.glSwapWindow() # Swap the front and back frame buffers (double buffering)
    setCurrentContext(oldContext)

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
            result.window = defaultWindow
            when defined(macosx) and not defined(ios):
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
                of WindowEvent_FocusGained:
                    wnd.onFocusChange(true)
                of WindowEvent_FocusLost:
                    wnd.onFocusChange(false)
                of WindowEvent_Exposed:
                    wnd.setNeedsDisplay()
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
                const multiplierX = when not defined(macosx): 30.0 else: 1.0
                const multiplierY = when not defined(macosx): -30.0 else: 1.0
                result.offset.x = mouseEv.x.Coord * multiplierX
                result.offset.y = mouseEv.y.Coord * multiplierY

        of KeyDown, KeyUp:
            let keyEv = cast[KeyboardEventPtr](event)
            let wnd = windowFromSDLEvent(keyEv)
            result = newKeyboardEvent(virtualKeyFromNative(cint(keyEv.keysym.scancode)), buttonStateFromSDLState(keyEv.state.KeyState), keyEv.repeat)
            #result.rune = keyEv.keysym.unicode.Rune
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

method onResize*(w: SdlWindow, newSize: Size) =
    when defined(macosx) and not defined(ios):
        w.pixelRatio = w.scaleFactor()
    else:
        w.pixelRatio = screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * w.pixelRatio), GLsizei(newSize.height * w.pixelRatio))
    procCall w.Window.onResize(newSize)

when false:
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

proc nextEvent(evt: var sdl2.Event) =
    if gcRequested:
        echo "full collect"
        GC_fullCollect()
        gcRequested = false

    when defined(ios):
        proc iPhoneSetEventPump(enabled: Bool32) {.importc: "SDL_iPhoneSetEventPump".}

        iPhoneSetEventPump(true)
        pumpEvents()
        iPhoneSetEventPump(false)
        while pollEvent(evt):
            discard handleEvent(addr evt)

        if animationEnabled == 0:
            mainApplication().drawWindows()
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

method startTextInput*(w: SdlWindow, r: Rect) =
    startTextInput()

method stopTextInput*(w: SdlWindow) =
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

template runApplication*(body: typed): typed =
    sdlMain()

    try:
        body
        runUntilQuit()
    except:
        logi "Exception caught: ", getCurrentExceptionMsg()
        logi getCurrentException().getStackTrace()
        quit 1
