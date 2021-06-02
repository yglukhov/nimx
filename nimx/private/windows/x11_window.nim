import nimx/[ types, abstract_window, view, context, event, app, screen,
            portable_gl, linkage_details, notification_center ]

import x11/[xlib, xutil, xresource]
import x11/x except Window
import opengl/glx, opengl
import asyncdispatch, parseutils, times

import nimx/private/x11_vk_map
# X11 impl. Nice tutorial: https://github.com/gamedevtech/X11OpenGLWindow

type
  X11Window = ref object of Window
    xdisplay: PDisplay
    xwindow: x.Window

var defaultDisplay: PDisplay
var allWindows {.threadvar.}: seq[X11Window]

proc newXWindow(d: PDisplay, w: x.Window, r: Rect): X11Window =
  result = X11Window(xdisplay: d, xwindow: w)
  result.gfxCtx = newGraphicsContext()
  allWindows.add(result)
  result.init(w, r)
  mainApplication().addWindow(result)

proc chooseVisual(d: PDisplay, screenId: cint): PXVisualInfo =
  var majorGLX, minorGLX: cint
  discard glXQueryVersion(d, majorGLX, minorGLX)
  if (majorGLX, minorGLX) < (1.cint, 2.cint):
    raise newException(IOError, "GLX 1.2 or greater is required")
  var glxAttribs = [
    GLX_RGBA.int32,
    GLX_DOUBLEBUFFER,
    GLX_DEPTH_SIZE, 24,
    GLX_STENCIL_SIZE, 8,
    GLX_RED_SIZE, 8,
    GLX_GREEN_SIZE, 8,
    GLX_BLUE_SIZE, 8,
    # GLX_SAMPLE_BUFFERS, 0,
    # GLX_SAMPLES, 0,
    None]
  result = glXChooseVisual(d, screenId, addr glxAttribs[0])

proc newXWindow(d: PDisplay, f: Rect): X11Window =
  let s = DefaultScreenOfDisplay(d)
  let r = RootWindowOfScreen(s)
  let blk = XBlackPixelOfScreen(s)
  let visual = chooseVisual(d, XScreenNumberOfScreen(s))
  var attrs: TXSetWindowAttributes
  attrs.border_pixel = blk
  attrs.background_pixel = blk
  attrs.override_redirect = 0
  attrs.colormap = XCreateColormap(d, r, visual.visual, AllocNone)
  attrs.event_mask =
    KeyPressMask or KeyReleaseMask or KeymapStateMask or
    PointerMotionMask or ButtonPressMask or ButtonReleaseMask or EnterWindowMask or LeaveWindowMask or
    ExposureMask

  let w = XCreateWindow(d, r, f.x.cint, f.y.cint, f.width.cuint, f.height.cuint, 0, visual.depth, InputOutput, visual.visual, CWBackPixel or CWColormap or CWBorderPixel or CWEventMask or CWOverrideRedirect, addr attrs)

  let ctx = glXCreateContext(d, visual, nil, 1)
  discard glXMakeCurrent(d, w, ctx)

  discard XClearWindow(d, w)
  discard XMapRaised(d, w)
  discard XFlush(d)

  newXWindow(d, w, f)

proc destroy(w: X11Window) =
  discard XDestroyWindow(w.xdisplay, w.xwindow)
  w.xwindow = 0
  w.xdisplay = nil
  for i, x in allWindows:
    if x == w:
      allWindows.del(i)
      break

proc findWindowWithX(d: PDisplay, w: x.Window): X11Window =
  for x in allWindows:
    if x.xwindow == w:
      result = x
      break
  if result.isNil:
    echo "Could not find x window"

proc setTitle(w: X11Window, t: cstring) =
  discard XStoreName(w.xdisplay, w.xwindow, t)

proc getTitle(w: X11Window): string =
  var pname: cstring
  discard XFetchName(w.xdisplay, w.xwindow, addr pname)
  if not pname.isNil:
    result = $pname
    discard XFree(pname)

method `title=`*(w: X11Window, t: string) =
    w.setTitle(t)

method title*(w: X11Window): string = getTitle(w)

proc getOsFrame(w: X11Window): Rect =
  var attrs: TXWindowAttributes
  discard XGetWindowAttributes(w.xdisplay, w.xwindow, addr attrs)
  newRect(attrs.x.Coord, attrs.y.Coord, attrs.width.Coord, attrs.height.Coord)

proc eventWithXEvent(d: PDisplay, ev: var TXEvent, result: var seq[Event]) =
  var e: Event
  case ev.theType
  of KeymapNotify:
    discard XRefreshKeyboardMapping(addr ev.xmapping)
  of KeyPress:

    let im = XOpenIM(d, nil, nil, nil)
    # var styles: ptr TXIMStyles
    # var ximRequestedStyle: TXIMStyle
    # let failed = XGetIMValues(im, XNQueryInputStyle, addr styles, nil)
    # if not failed.isNil:
    #   echo "XIM Cant get styles"
    let ic = XCreateIC(im, XNInputStyle, XIMPreeditNothing or XIMStatusNothing, XNClientWindow, ev.xkey.window, nil)
    XSetICFocus(ic)
    let wnd = findWindowWithX(d, ev.xkey.window)
    var str = newString(25)
    var ks: TKeySym
    var st: TStatus
    let sz = Xutf8LookupString(ic, addr ev.xkey, addr str[0], str.len.cint, addr ks, addr st).int
    XDestroyIC(ic)

    if st in {XLookupKeySymVal, XLookupBoth}:
      e = newKeyboardEvent(virtualKeyFromNative(ks), bsDown, false)
      e.window = wnd
      result.add(e)

      # Some keycodes like Backspace still trigger an XLookupChars event, but we
      # don't want to generate an input event for that, so stop here
      if e.keyCode in {Backspace}:
        return

    if st in {XLookupChars, XLookupBoth} and sz != 0:
      if sz != 0:
        str.setLen(sz)
        e = newEvent(etTextInput)
        e.text = str
        e.window = wnd
        result.add(e)

  of KeyRelease:
    let wnd = findWindowWithX(d, ev.xkey.window)
    var str = newString(25)
    var ks: TKeySym
    discard XLookupString(addr ev.xkey, addr str[0], str.len.cint, addr ks, nil).int
    e = newKeyboardEvent(virtualKeyFromNative(ks), bsUp, false)
    e.window = wnd
    result.add(e)

  of ButtonPress, ButtonRelease:
    let state = if ev.theType == ButtonPress: bsDown else: bsUp
    let wnd = findWindowWithX(d, ev.xbutton.window)
    let button = case ev.xbutton.button
      of 1: VirtualKey.MouseButtonPrimary
      of 2: VirtualKey.MouseButtonMiddle
      of 3: VirtualKey.MouseButtonSecondary
      else: VirtualKey.Unknown
    let pos = newPoint(ev.xbutton.x.Coord, ev.xbutton.y.Coord) / wnd.pixelRatio
    e = newMouseButtonEvent(pos, button, state)
    e.window = wnd
    result.add(e)

  of MotionNotify:
    let wnd = findWindowWithX(d, ev.xmotion.window)
    let pos = newPoint(ev.xmotion.x.Coord, ev.xmotion.y.Coord) / wnd.pixelRatio
    e = newMouseMoveEvent(pos)
    e.window = wnd
    result.add(e)

  of EnterNotify:
    echo "Mouse enter"

  of LeaveNotify:
    echo "Mouse leave"

  of Expose:
    let wnd = findWindowWithX(d, ev.xexpose.window)
    e = newEvent(etWindowResized)
    e.window = wnd
    e.position = newPoint(ev.xexpose.width.Coord, ev.xexpose.height.Coord) / wnd.pixelRatio
    result.add(e)

  else:
    discard

proc animateAndDraw() =
  let a = mainApplication()
  a.runAnimations()
  a.drawWindows()

proc onXSocket(d: PDisplay) =
  var ev: TXEvent
  var evs = newSeqOfCap[Event](2)
  let app = mainApplication()
  while XPending(d) != 0:
    evs.setLen(0)
    discard XNextEvent(d, addr ev)
    eventWithXEvent(d, ev, evs)
    for i in 0 .. evs.high:
      discard app.handleEvent(evs[i])

  animateAndDraw()

proc registerDisplayInDispatcher(d: PDisplay) =
  let fd = XConnectionNumber(d)
  register(AsyncFD(fd))
  addRead(AsyncFD(fd)) do(fd: AsyncFD) -> bool:
    {.gcsafe.}:
      onXSocket(d)

proc newXWindow(r: Rect): X11Window =
  if defaultDisplay.isNil:
    defaultDisplay = XOpenDisplay(nil)
    registerDisplayInDispatcher(defaultDisplay)
  newXWindow(defaultDisplay, r)

newWindow = proc(r: view.Rect): Window =
    result = newXWindow(r)

newFullscreenWindow = proc(): Window =
    result = newXWindow(zeroRect)

template runApplication*(initCode: typed) =
  block:
    initCode
    runForever()

method draw*(w: X11Window, r: Rect) =
  let c = w.gfxCtx
  let gl = c.gl
  if w.mActiveBgColor != w.backgroundColor:
    gl.clearColor(w.backgroundColor.r, w.backgroundColor.g, w.backgroundColor.b, w.backgroundColor.a)
    w.mActiveBgColor = w.backgroundColor
  gl.stencilMask(0xFF)
  gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)
  gl.stencilMask(0x00)

method drawWindow(w: X11Window) =
  # discard glMakeCurrent(w.impl, w.sdlGlContext)
  let c = w.gfxCtx
  c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
    procCall w.Window.drawWindow()
  glXSwapBuffers(w.xdisplay, w.xwindow)
  # w.impl.glSwapWindow() # Swap the front and back frame buffers (double buffering)

proc scaleFactor(w: X11Window): float =
  var dpi = 96.0
  let nd = XOpenDisplay(DisplayString(w.xdisplay))
  if not nd.isNil:
    let resourceString = XResourceManagerString(nd)
    if not resourceString.isNil:
      XrmInitialize() # Need to initialize the DB before calling Xrm* functions
      let db = XrmGetStringDatabase(resourceString)
      if not db.isNil:
        var value: TXrmValue
        var typ: cstring
        if XrmGetResource(db, "Xft.dpi", "String", addr typ, addr value) != 0:
          if not value.address.isNil:
            discard parseFloat($cstring(value.address), dpi, 0)
        XrmDestroyDatabase(db)

    discard XCloseDisplay(nd)

  dpi / 96

proc updatePixelRatio(w: X11Window) {.inline.} =
  w.pixelRatio = w.scaleFactor()
  w.viewportPixelRatio = w.pixelRatio

method onResize*(w: X11Window, newSize: Size) =
  # discard glMakeCurrent(w.impl, w.sdlGlContext)
  w.updatePixelRatio()
  procCall w.Window.onResize(newSize)

  let constrainedSize = w.frame.size
  if constrainedSize != newSize:
    # Here we attempt to prevent window resizing (initiated externally)
    # On linux this doesn't work reliably, more research needed.
    when false:
      w.setOSWindowSize(constrainedSize)

  let vp = constrainedSize * w.viewportPixelRatio
  glViewport(0, 0, GLSizei(vp.width), GLsizei(vp.height))

proc redraw() {.async.} =
  await sleepAsync(1)
  animateAndDraw()

method markNeedsDisplay*(w: X11Window) =
  asyncCheck redraw()

var animationEnabled = false

proc animationLoop() {.async.} =
  while true:
    animateAndDraw()
    if not animationEnabled:
      break
    await sleepAsync(1000 div 60) # 60 fps.

method animationStateChanged*(w: X11Window, state: bool) =
  let wasDisabled = not animationEnabled
  animationEnabled = state
  if wasDisabled and animationEnabled:
    asyncCheck animationLoop()

when isMainModule:
  let d = XOpenDisplay(nil)
  registerDisplayInDispatcher(d)

  let w = newXWindow(d, newRect(50, 50, 500, 500))
  w.setTitle("nimx test")
  echo "sz: ", getOsFrame(w)
  echo "wnd created"
  # while true:
  #   discard XNextEvent(d, addr evt)
  #   echo "evt"

  runForever()

  w.destroy()
  discard XCloseDisplay(d)
