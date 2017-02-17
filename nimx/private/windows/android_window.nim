import heapqueue, locks, posix, os, unicode
import nimx / [abstract_window, app, context, event, screen, mini_profiler, keyboard]
import system_logger
import egl, opengl
import jnim

import android/ndk/[ anative_window, alooper, aasset_manager,
                    aconfiguration, anative_activity, ainput, arect ]

import android.view.key_character_map

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
    androidContentRect: ARect

var defaultWindow: AndroidWindow
var gNativeActivity: ANativeActivity
var gNativeWindow: ANativeWindow

var drawingThread: Thread[void]
var drawingThreadRunning = false
var pendingDrawRequests = 0
var animationEnabled = 0

proc getAndroidAssetManager*(): AAssetManager {.exportc: "nimx_getAndroidAssetManager".} =
    gNativeActivity.assetManager

proc getAndroidActivity*(): jobject {.exportc: "nimx_getAndroidActivity".} =
    gNativeActivity.obj

proc getAndroidNativeActivity*(): ANativeActivity = gNativeActivity

proc updateWinSize(win: AndroidWindow, n: ANativeWindow) =
    win.pixelRatio = screenScaleFactor()
    let w = n.getWidth().Coord
    let h = n.getHeight().Coord
    win.onResize(newSize(w, h))
    logi "win size: ", w, " x ", h

import private.jni_wrapper

type jclass = jni_wrapper.jclass

proc smarterFindClass(env: JNIEnvPtr, name: cstring): jclass =
    result = env.FindClass(env, name)
    if cast[pointer](result) == nil:
        env.ExceptionClear(env)
        let activityClass = env.FindClass(env, "android/app/Activity")
        let getClassLoader = env.GetMethodID(env, activityClass, "getClassLoader", "()Ljava/lang/ClassLoader;")
        env.deleteLocalRef(activityClass)
        let cls = env.CallObjectMethod(env, getAndroidActivity(), getClassLoader)
        let classLoader = env.FindClass(env, "java/lang/ClassLoader")
        let findClass = env.GetMethodID(env, classLoader, "loadClass", "(Ljava/lang/String;)Ljava/lang/Class;")
        env.deleteLocalRef(classLoader)
        let strClassName = env.NewStringUTF(env, name)
        result = cast[jclass](env.CallObjectMethod(env, cls, findClass, strClassName))
        env.deleteLocalRef(strClassName)
        env.deleteLocalRef(cls)

proc patchJNIEnv() =
    findClassOverride = smarterFindClass

proc init(w: AndroidWindow, wnd: ANativeWindow) =
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

    discard wnd.setBuffersGeometry(0, 0, format.ANativeWindowFormat)

    if eglBindApi(EGL_OPENGL_ES_API) == EGL_FALSE:
        logi "eglBindApi failed"
        raise newException(Exception, "eglBindApi failed")

    let surface = eglCreateWindowSurface(display, config, wnd, nil)
    let context = eglCreateContext(display, config, nil, addr ctxAttribs[0])

    if eglMakeCurrent(display, surface, surface, context) == EGL_FALSE:
        logi "Unable to eglMakeCurrent"
        raise newException(Exception, "Unable to eglMakeCurrent")

    w.egldisplay = display
    w.eglcontext = context
    w.eglsurface = surface

    w.renderingContext = newGraphicsContext()
    updateWinSize(w, wnd)

var pipeLock: Lock
var pipeFd: cint
var drawFd: cint

{.push stackTrace: off.}
proc nimx_performOnMainThread(procAddr, dataAddr: pointer) {.exportc.} =
    pipeLock.acquire()
    discard posix.write(pipeFd, unsafeAddr procAddr, sizeof(procAddr))
    discard posix.write(pipeFd, unsafeAddr dataAddr, sizeof(dataAddr))
    pipeLock.release()
{.pop.}

proc animateAndDraw() =
    mainApplication().runAnimations()
    mainApplication().drawWindows()

proc tryRead(fd: cint, res: var pointer): bool =
    let r = posix.read(fd, addr res, sizeof(res))
    if r <= 0: return
    result = true
    doAssert(r == sizeof(res))

proc dispatchPerformOnMainThread(fd, events: cint, data: pointer): cint {.cdecl.} =
    result = 1
    var procAddr: pointer
    var dataPtr: pointer
    while not tryRead(fd, procAddr): discard
    while not tryRead(fd, dataPtr): discard
    cast[proc(data: pointer) {.cdecl.}](procAddr)(dataPtr)

    if tryRead(fd, procAddr):
        while not tryRead(fd, dataPtr): discard
        cast[proc(data: pointer) {.cdecl.}](procAddr)(dataPtr)

    animateAndDraw()

proc animatedDraw(fd, events: cint, data: pointer): cint {.cdecl.} =
    result = 1
    atomicDec pendingDrawRequests
    var dummy: pointer
    discard tryRead(fd, dummy)
    discard tryRead(fd, dummy)
    animateAndDraw()

proc setNonBlocking(fd: cint) {.inline.} =
  var x = fcntl(fd, F_GETFL, 0)
  if x != -1:
    var mode = x or O_NONBLOCK
    discard fcntl(fd, F_SETFL, mode)

proc setupLooper() =
    initLock(pipeLock)
    var pipeFds: array[2, cint]
    discard posix.pipe(pipeFds)
    pipeFd = pipeFds[1]
    setNonBlocking(pipeFds[0])
    discard ALooper_forThread().addFd(pipeFds[0], ALOOPER_POLL_CALLBACK, ALOOPER_EVENT_INPUT, dispatchPerformOnMainThread, nil)

    var drawFds: array[2, cint]
    discard posix.pipe(drawFds)
    drawFd = drawFds[1]
    setNonBlocking(drawFds[0])
    discard ALooper_forThread().addFd(drawFds[0], ALOOPER_POLL_CALLBACK, ALOOPER_EVENT_INPUT, animatedDraw, nil)

proc eventWithMotionEvent(event: AMotionEvent): Event =
    let a = event.getAction()
    let x = event.getX(0) / defaultWindow.androidContentRect.right.float * defaultWindow.frame.width
    let y = event.getY(0) / defaultWindow.androidContentRect.bottom.float * defaultWindow.frame.height
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

proc getUnicodeChar*(e: AKeyEvent): int32 =
    let kcm = KeyCharacterMap.load(e.getDeviceId())
    result = kcm.get(e.getKeyCode(), e.getMetaState())

proc eventWithKeyEvent(event: AKeyEvent): Event =
    let bs = if event.getAction() == AKEY_EVENT_ACTION_UP: bsUp else: bsDown
    let scanCode = event.getScanCode()
    let u = event.getUnicodeChar()
    logi "unicode: ", u, ", \"", Rune(u), "\""
    logi "keycode: ", event.getKeyCode()
    logi "scancode: ", scanCode
    result = newKeyboardEvent(VirtualKey.Unknown, bs, event.getRepeatCount() > 0)
    #result.rune = keyEv.keysym.unicode.Rune
    result.window = defaultWindow

proc eventWithAndroidEvent(event: AInputEvent): Event =
    let motion = event.toMotionEvent()
    if not motion.isNil:
        result = eventWithMotionEvent(motion)
    else:
        let key = event.toKeyEvent()
        if not key.isNil:
            result = eventWithKeyEvent(key)

proc androidSetOnWindowCreated*(p: proc(activity: ANativeActivity, window: ANativeWindow) {.cdecl.}) =
    getAndroidNativeActivity().callbacks.onNativeWindowCreated = p

proc drawingThreadFunc() {.thread.} =
    while drawingThreadRunning:
        let req = atomicInc(pendingDrawRequests)
        if req < 10:
            var dummy: pointer
            discard drawFd.write(addr dummy, sizeof(dummy))
        else:
            atomicDec(pendingDrawRequests)
        sleep(17)

method enableAnimation*(w: AndroidWindow, flag: bool) =
    doAssert( (animationEnabled == 0 and flag) or (animationEnabled != 0 and not flag) , "animationEnabled: " & $animationEnabled & " flag: " & $flag)
    if flag:
        inc animationEnabled
        drawingThreadRunning = true
        pendingDrawRequests = 0
        createThread(drawingThread, drawingThreadFunc)
        logi "enable animation"
    else:
        dec animationEnabled
        drawingThreadRunning = false
        logi "disable animation"

proc newAndroidWindow(): AndroidWindow =
    logi "Creating android window"
    result.new()
    let w = gNativeWindow.getWidth().Coord
    let h = gNativeWindow.getHeight().Coord
    result.init(newRect(0, 0, w, h))
    init(result, gNativeWindow)
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

proc defaultOnStart(activity: ANativeActivity) {.cdecl.} =
    discard

proc defaultOnResume(activity: ANativeActivity) {.cdecl.} =
    discard
    
proc defaultOnSaveInstanceState(activity: ANativeActivity, outSize: var csize): pointer {.cdecl.} =
    discard

proc defaultOnPause(activity: ANativeActivity) {.cdecl.} =
    discard

proc defaultOnStop(activity: ANativeActivity) {.cdecl.} =
    discard

proc defaultOnDestroy(activity: ANativeActivity) {.cdecl.} =
    discard

proc defaultOnWindowFocusChanged(activity: ANativeActivity, hasFocus: cint) {.cdecl.} =
    discard

proc defaultOnNativeWindowCreated(activity: ANativeActivity, window: ANativeWindow) {.cdecl.} =
    gNativeWindow = window

proc defaultOnNativeWindowResized(activity: ANativeActivity, window: ANativeWindow) {.cdecl.} =
    updateWinSize(defaultWindow, window)

proc defaultOnNativeWindowRedrawNeeded(activity: ANativeActivity, window: ANativeWindow) {.cdecl.} =
    if not defaultWindow.isNil:
        defaultWindow.setNeedsDisplay()
    animateAndDraw()

proc defaultOnNativeWindowDestroyed(activity: ANativeActivity, window: ANativeWindow) {.cdecl.} =
    discard

proc onInputEvent(event: AInputEvent): bool =
    var e = eventWithAndroidEvent(event)
    if (e.kind != etUnknown):
        result = mainApplication().handleEvent(e)

proc onEvent(fd, events: cint, data: pointer): cint {.cdecl.} =
    result = 1
    let q = cast[AInputQueue](data)
    var event: AInputEvent
    while q.getEvent(event) >= 0:
        if q.preDispatchEvent(event) != 0: continue
        let handled = onInputEvent(event).cint
        discard q.finishEvent(event, handled)

    if animationEnabled == 0 and not defaultWindow.isNil and defaultWindow.needsDisplay:
        animateAndDraw()

proc defaultOnInputQueueCreated(activity: ANativeActivity, queue: AInputQueue) {.cdecl.} =
    queue.attachLooper(ALooper_forThread(), ALOOPER_POLL_CALLBACK, onEvent, cast[pointer](queue))

proc defaultOnInputQueueDestroyed(activity: ANativeActivity, queue: AInputQueue) {.cdecl.} =
    discard

proc defaultOnContentRectChanged(activity: ANativeActivity, rect: ptr ARect) {.cdecl.} =
    if not defaultWindow.isNil:
        defaultWindow.androidContentRect = rect[]
        updateWinSize(defaultWindow, gNativeWindow)

proc defaultOnConfigurationChanged(activity: ANativeActivity) {.cdecl.} =
    discard

proc defaultOnLowMemory(activity: ANativeActivity) {.cdecl.} =
    discard

template runApplication*(body: typed): typed =
    proc onNativeWindowCreated(activity: ANativeActivity, window: ANativeWindow) {.cdecl.} =
        gNativeWindow = window
        block:
            sharedProfiler().enabled = true
            body
    setupLooper()
    patchJNIEnv()
    androidSetOnWindowCreated(onNativeWindowCreated)

{.push stackTrace: off.}
proc ANativeActivity_onCreate(activity: ANativeActivity, savedState: pointer, savedStateSize: csize) {.exportc.} =
    errorMessageWriter = proc(msg: string) =
        logi msg

    gNativeActivity = activity
    let cb = activity.callbacks
    cb.onStart = defaultOnStart
    cb.onResume = defaultOnResume
    cb.onSaveInstanceState = defaultOnSaveInstanceState
    cb.onPause = defaultOnPause
    cb.onStop = defaultOnStop
    cb.onDestroy = defaultOnDestroy
    cb.onWindowFocusChanged = defaultOnWindowFocusChanged
    cb.onNativeWindowCreated = defaultOnNativeWindowCreated
    cb.onNativeWindowResized = defaultOnNativeWindowResized
    cb.onNativeWindowRedrawNeeded = defaultOnNativeWindowRedrawNeeded
    cb.onNativeWindowDestroyed = defaultOnNativeWindowDestroyed
    cb.onInputQueueCreated = defaultOnInputQueueCreated
    cb.onInputQueueDestroyed = defaultOnInputQueueDestroyed
    cb.onContentRectChanged = defaultOnContentRectChanged
    cb.onConfigurationChanged = defaultOnConfigurationChanged
    cb.onLowMemory = defaultOnLowMemory

    proc NimMain() {.importc.}
    NimMain()
{.pop.}
