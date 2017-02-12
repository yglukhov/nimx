import heapqueue, locks, posix
import abstract_window, app, context, timer, event, screen
import system_logger
import egl, opengl
import jnim

import android/ndk/[ native_glue, anative_window, alooper, aasset_manager,
                    aconfiguration, anative_activity, ainput ]

const
    AMOTION_EVENT_ACTION_DOWN = 0
    AMOTION_EVENT_ACTION_UP = 1
    AMOTION_EVENT_ACTION_MOVE = 2
    AMOTION_EVENT_ACTION_CANCEL = 3


type AndroidWindow = ref object of Window
    egldisplay: EGLDisplay
    eglsurface: EGLSurface
    eglcontext: EGLContext
    renderingContext: GraphicsContext

var defaultWindow: AndroidWindow
var gNativeApp: ANativeApp

proc getAndroidAssetManager*(): AAssetManager {.exportc: "nimx_getAndroidAssetManager".} =
    if gNativeApp.isNil:
        raise newException(Exception, "Could not get asset manager. Native app not created.")
    return gNativeApp.activity.assetManager

proc getAndroidActivity*(): jobject {.exportc: "nimx_getAndroidActivity".} =
    if gNativeApp.isNil:
        raise newException(Exception, "Could not get asset manager. Native app not created.")
    return gNativeApp.activity.obj

proc updateWinSize(win: AndroidWindow, n: ANativeWindow) =
    win.pixelRatio = screenScaleFactor()
    let w = n.getWidth().Coord
    let h = n.getHeight().Coord
    win.onResize(newSize(w, h))
    logi "win size: ", w, " x ", h

var origFindClass: proc(theEnv: JNIEnvPtr, name: cstring): jclass {.cdecl.}

proc patchJNIEnv() =
    proc findClass(theEnv: JNIEnvPtr, name: cstring): jclass {.cdecl.} =
        origFindClass = theEnv.FindClass

proc init(w: AndroidWindow, app: ANativeApp) =
    let display = eglGetDisplay(EGL_DEFAULT_DISPLAY)
    if eglInitialize(display, nil, nil) == EGL_FALSE:
        logi "eglInitialize failed"
        raise newException(Exception, "eglInitialize failed")

    var attribs = [EGL_SURFACE_TYPE.EGLint, EGL_WINDOW_BIT,
            EGL_BLUE_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_RED_SIZE, 8,
            EGL_STENCIL_SIZE, 8,
            EGL_DEPTH_SIZE, 8,
            EGL_NONE
        ]

    var ctxAttribs = [EGL_CONTEXT_CLIENT_VERSION.EGLint, 2,
            EGL_NONE
        ]

    var config: EGLConfig
    var numConfigs, format: EGLint

    if eglChooseConfig(display, addr attribs[0], addr config, 1, addr numConfigs) == EGL_FALSE:
        logi "eglChooseConfig failed"
        raise newException(Exception, "eglChooseConfig failed")

    if eglGetConfigAttrib(display, config, EGL_NATIVE_VISUAL_ID, addr format) == EGL_FALSE:
        logi "eglGetConfigAttrib failed"
        raise newException(Exception, "eglGetConfigAttrib failed")

    discard app.window.setBuffersGeometry(0, 0, format.ANativeWindowFormat)

    if eglBindApi(EGL_OPENGL_ES_API) == EGL_FALSE:
        logi "eglBindApi failed"
        raise newException(Exception, "eglBindApi failed")

    let surface = eglCreateWindowSurface(display, config, app.window, nil)
    let context = eglCreateContext(display, config, nil, addr ctxAttribs[0])

    if eglMakeCurrent(display, surface, surface, context) == EGL_FALSE:
        logi "Unable to eglMakeCurrent"
        raise newException(Exception, "Unable to eglMakeCurrent")

    w.egldisplay = display
    w.eglcontext = context
    w.eglsurface = surface

    w.renderingContext = newGraphicsContext()
    updateWinSize(w, app.window)

var pipeLock: Lock
var pipeFd: cint

{.push stackTrace: off.}
proc nimx_performOnMainThread(procAddr, dataAddr: pointer) {.exportc.} =
    pipeLock.acquire()
    discard posix.write(pipeFd, unsafeAddr procAddr, sizeof(procAddr))
    discard posix.write(pipeFd, unsafeAddr dataAddr, sizeof(dataAddr))
    pipeLock.release()
{.pop.}

proc dispatchPerformOnMainThread(fd, events: cint, data: pointer): cint {.cdecl.} =
    result = 1
    var procAddr: pointer
    var dataPtr: pointer
    discard posix.read(fd, addr procAddr, sizeof(procAddr))
    discard posix.read(fd, addr dataPtr, sizeof(dataPtr))
    cast[proc(data: pointer) {.cdecl.}](procAddr)(dataPtr)

var redrawAttempts = 0

proc handleCmd(app: ANativeApp, cmd: AppCmd) {.cdecl.} =
    logi "handleCmd: ", cmd
    case cmd
    of APP_CMD_START:
        initLock(pipeLock)
        var pipeFds: array[2, cint]
        discard posix.pipe(pipeFds)
        pipeFd = pipeFds[1]
        discard ALooper_forThread().addFd(pipeFds[0], ALOOPER_POLL_CALLBACK, ALOOPER_EVENT_INPUT, dispatchPerformOnMainThread, nil)

    of APP_CMD_INIT_WINDOW:
        if defaultWindow.isNil:
            logi "Nimx error: key window not created"
            raise newException(Exception, "Nimx error: key window not created")
        defaultWindow.init(app)
    of APP_CMD_CONFIG_CHANGED:
        logi "Config changed"
    of APP_CMD_CONTENT_RECT_CHANGED:
        logi "content rect changed: ", app.contentRect
        logi "density: ", app.config.getDensity()
        logi "w: ", app.window.getWidth(), ", h: ", app.window.getHeight()
        updateWinSize(defaultWindow, app.window)
    of APP_CMD_WINDOW_REDRAW_NEEDED:
        redrawAttempts = 3
    of APP_CMD_WINDOW_RESIZED:
        updateWinSize(defaultWindow, app.window)
    else:
        discard

proc eventWithMotionEvent(event: AMotionEvent): Event =
    let a = event.getAction()
    # let x = event.getAxisValue(AMOTION_EVENT_AXIS_X, 0)
    # let y = event.getAxisValue(AMOTION_EVENT_AXIS_Y, 0)
    let x = event.getX(0) / gNativeApp.contentRect.right.float * defaultWindow.frame.width
    let y = event.getY(0) / gNativeApp.contentRect.bottom.float * defaultWindow.frame.height
    let pos = newPoint(x, y)
    logi "ev: ", a, ", pos: ", pos
    case a
    of AMOTION_EVENT_ACTION_DOWN:
        result = newMouseDownEvent(pos, VirtualKey.MouseButtonPrimary)
        result.window = defaultWindow
    of AMOTION_EVENT_ACTION_UP:
        result = newMouseUpEvent(pos, VirtualKey.MouseButtonPrimary)
        result.window = defaultWindow
    of AMOTION_EVENT_ACTION_MOVE:
        result = newMouseMoveEvent(pos)
        result.window = defaultWindow
    else: discard

proc eventWithKeyEvent(event: AKeyEvent): Event =
    discard

proc eventWithAndroidEvent(event: AInputEvent): Event =
    let motion = event.toMotionEvent()
    if not motion.isNil:
        result = eventWithMotionEvent(motion)
    else:
        let key = event.toKeyEvent()
        if not key.isNil:
            result = eventWithKeyEvent(key)

proc handleInput(app: ANativeApp, event: AInputEvent) {.cdecl.} =
    var e = eventWithAndroidEvent(event)
    if (e.kind != etUnknown):
        discard mainApplication().handleEvent(e)

{.push stackTrace: off.}
proc preMain(app: ANativeApp) =
    gNativeApp = app
    # Setup logger
    errorMessageWriter = proc(msg: string) =
        logi msg
{.pop.}

declareAndroidMain(preMain, handleCmd, handleInput)

proc runUntilQuit() =
    try:
        while true:
            var events: cint
            var source: AndroidPollSource
            while true:
                let id = ALooper_pollAll(0, nil, addr events, cast[ptr pointer](addr source))

                if id == -3:
                    if not processTimers():
                        break
                elif id < 0:
                    break
                if not source.isNil:
                    source.process(source.app, source)

            if defaultWindow.renderingContext != nil:
                if redrawAttempts > 0:
                    defaultWindow.setNeedsDisplay()
                    dec redrawAttempts
                # defaultWindow.setNeedsDisplay()
                mainApplication().runAnimations()
                mainApplication().drawWindows()
    except:
        logi "Exception caught: ", getCurrentExceptionMsg()
        logi getCurrentException().getStackTrace()

template runApplication*(body: typed): typed =
    body
    runUntilQuit()

proc newAndroidWindow(): AndroidWindow =
    logi "Creating android window"
    result.new()
    result.init(newRect(0, 0, 1707, 960))
    if defaultWindow.isNil:
        defaultWindow = result
    mainApplication().addWindow(result)

method drawWindow(w: AndroidWindow) =
    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    discard eglSwapBuffers(w.egldisplay, w.eglsurface)
    setCurrentContext(oldContext)

method onResize*(w: AndroidWindow, newSize: Size) =
    glViewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
    procCall w.Window.onResize(newSize)

import android.content.context as acontext
import android.app.native_activity
import android.view.inputmethod.input_method_manager

proc getInputManager(): InputMethodManager =
    let act = NativeActivity.fromJObject(getAndroidActivity())
    result = InputMethodManager.fromJObject(act.getSystemService(Context.INPUT_METHOD_SERVICE).get)

# TODO: Input should be done in a less hacky way.
var inputShown = false

method startTextInput*(w: AndroidWindow, r: Rect) =
    let imm = getInputManager()
    if not inputShown:
        imm.toggleSoftInput(0, 0)

method stopTextInput*(w: AndroidWindow) =
    let imm = getInputManager()
    if inputShown:
        imm.toggleSoftInput(0, 0)

newWindow = proc(r: Rect): Window =
    result = newAndroidWindow()

newFullscreenWindow = proc(): Window =
    result = newAndroidWindow()
