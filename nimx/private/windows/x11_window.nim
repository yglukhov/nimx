import std/[asyncdispatch, parseutils]
import ../../[types, abstract_window, view, context, event, app, notification_center]
import x11/[xlib, xutil, xresource]
import x11/x except Window
import wgpu except Status
import yasync/compat
import ../../private/x11_vk_map

export abstract_window

type
  X11Window* = ref object of Window
    xdisplay*: PDisplay
    xwindow*: x.Window
    renderingContext: GraphicsContext
    wgpuInstance: Instance
    wgpuAdapter: Adapter
    wgpuDevice: Device
    wgpuSurface: Surface
    wgpuFormat: TextureFormat

var defaultDisplay: PDisplay
var allWindows* {.threadvar.}: seq[X11Window]
var animationEnabled = false

proc registerDisplayInDispatcher(d: PDisplay) {.gcsafe.}

proc getPreferredFormat(surface: Surface, adapter: Adapter): TextureFormat =
  var caps: SurfaceCapabilities
  if surface.getCapabilities(adapter, caps) and caps.formatCount > 0:
    result = caps.formats[0]
  else:
    result = tfBGRA8Unorm

proc createWgpuSurface(w: X11Window, instance: Instance): Surface =
  var x11d: SurfaceSourceXlibWindow
  x11d.sType = stSurfaceSourceXlibWindow
  x11d.display = w.xdisplay
  x11d.window = w.xwindow.uint64
  var sd: SurfaceDescriptor
  sd.nextInChain = addr x11d
  instance.createSurface(sd)

proc initWgpu(w: X11Window) =
  w.wgpuInstance = createInstance()
  if w.wgpuInstance.isNil: raise newException(IOError, "Could not create WebGPU instance")
  w.wgpuSurface = w.createWgpuSurface(w.wgpuInstance)
  if w.wgpuSurface.isNil: raise newException(IOError, "Could not create WebGPU X11 surface")
  var adapterOpts: RequestAdapterOptions
  adapterOpts.compatibleSurface = w.wgpuSurface
  w.wgpuAdapter = waitFor w.wgpuInstance.requestAdapter(adapterOpts)
  if w.wgpuAdapter.isNil: raise newException(IOError, "Could not create WebGPU adapter")
  var deviceOpts: DeviceDescriptor
  deviceOpts.uncapturedErrorCallbackInfo.callback = proc(d: Device, e: ErrorType, message: StringView, data1, data2: pointer) {.cdecl.} =
    echo "WebGPU error: ", e, ": ", message
  w.wgpuDevice = waitFor w.wgpuAdapter.requestDevice(deviceOpts)
  if w.wgpuDevice.isNil: raise newException(IOError, "Could not create WebGPU device")
  w.wgpuFormat = w.wgpuSurface.getPreferredFormat(w.wgpuAdapter)
  let sz = w.frame.size * w.viewportPixelRatio
  w.renderingContext.configureSurface(w.wgpuDevice, w.wgpuSurface, w.wgpuFormat, sz.width.int, sz.height.int)

proc initX11Window(w: X11Window, d: PDisplay, f: Rect) =
  let screen = DefaultScreen(d)
  let root = RootWindow(d, screen)
  let black = BlackPixel(d, screen)
  let white = WhitePixel(d, screen)
  let xw = XCreateSimpleWindow(d, root, f.x.cint, f.y.cint, max(1, f.width.int).cuint, max(1, f.height.int).cuint, 0, black, white)
  discard XSelectInput(d, xw, KeyPressMask or KeyReleaseMask or KeymapStateMask or PointerMotionMask or ButtonPressMask or ButtonReleaseMask or EnterWindowMask or LeaveWindowMask or StructureNotifyMask or ExposureMask)
  discard XMapRaised(d, xw)
  discard XFlush(d)

  w.xdisplay = d
  w.xwindow = xw
  w.pixelRatio = 1
  w.viewportPixelRatio = 1
  w.renderingContext = newGraphicsContext()
  allWindows.add(w)
  mainApplication().addWindow(w)
  procCall w.Window.init()
  w.onResize(f.size)
  w.initWgpu()

proc getDefaultDisplay*(): PDisplay =
  if defaultDisplay.isNil:
    defaultDisplay = XOpenDisplay(nil)
    if defaultDisplay.isNil: raise newException(IOError, "Could not open X11 display")
    registerDisplayInDispatcher(defaultDisplay)
  defaultDisplay

method init*(w: X11Window) {.gcsafe.} =
  {.cast(gcsafe).}:
    w.initX11Window(getDefaultDisplay(), newRect(0, 0, 800, 600))

proc destroy(w: X11Window) =
  if w.xwindow != 0:
    discard XDestroyWindow(w.xdisplay, w.xwindow)
  w.xwindow = 0
  w.xdisplay = nil
  for i, xw in allWindows:
    if xw == w:
      allWindows.del(i)
      break

proc findWindowWithX(d: PDisplay, w: x.Window): X11Window =
  for xw in allWindows:
    if xw.xwindow == w: return xw

proc setTitle(w: X11Window, t: cstring) = discard XStoreName(w.xdisplay, w.xwindow, t)
proc getTitle(w: X11Window): string =
  var pname: cstring
  discard XFetchName(w.xdisplay, w.xwindow, addr pname)
  if not pname.isNil:
    result = $pname
    discard XFree(pname)

method `title=`*(w: X11Window, t: string) = w.setTitle(t)
method title*(w: X11Window): string = w.getTitle()

proc getOsFrame(w: X11Window): Rect =
  var attrs: XWindowAttributes
  discard XGetWindowAttributes(w.xdisplay, w.xwindow, addr attrs)
  newRect(attrs.x.Coord, attrs.y.Coord, attrs.width.Coord, attrs.height.Coord)

proc modifiersFromXState(state: cuint): ModifiersSet =
  if (state and ShiftMask) != 0: result.incl(LeftShift); result.incl(RightShift)
  if (state and ControlMask) != 0: result.incl(LeftControl); result.incl(RightControl)
  if (state and Mod1Mask) != 0: result.incl(LeftAlt); result.incl(RightAlt)
  if (state and Mod4Mask) != 0: result.incl(LeftGUI); result.incl(RightGUI)

proc eventWithXEvent(d: PDisplay, ev: var XEvent, result: var seq[Event]) =
  var e: Event
  case ev.theType
  of KeymapNotify:
    discard XRefreshKeyboardMapping(addr ev.xmapping)
  of KeyPress:
    let im = XOpenIM(d, nil, nil, nil)
    let ic = XCreateIC(im, XNInputStyle, XIMPreeditNothing or XIMStatusNothing, XNClientWindow, ev.xkey.window, nil)
    XSetICFocus(ic)
    let wnd = findWindowWithX(d, ev.xkey.window)
    var str = newString(25)
    var ks: KeySym
    var st: Status
    let sz = Xutf8LookupString(ic, addr ev.xkey, addr str[0], str.len.cint, addr ks, addr st).int
    XDestroyIC(ic)
    if st in {XLookupKeySymVal, XLookupBoth}:
      e = newKeyboardEvent(virtualKeyFromNative(ks), bsDown, false)
      e.window = wnd
      e.modifiers = modifiersFromXState(ev.xkey.state)
      result.add(e)
      if e.keyCode in {Backspace, Return}: return
    if st in {XLookupChars, XLookupBoth} and (ev.xkey.state and ControlMask) == 0 and sz != 0:
      str.setLen(sz)
      e = newEvent(etTextInput)
      e.text = str
      e.window = wnd
      result.insert(e, 0)
  of KeyRelease:
    let wnd = findWindowWithX(d, ev.xkey.window)
    var str = newString(25)
    var ks: KeySym
    discard XLookupString(addr ev.xkey, addr str[0], str.len.cint, addr ks, nil).int
    e = newKeyboardEvent(virtualKeyFromNative(ks), bsUp, false)
    e.modifiers = modifiersFromXState(ev.xkey.state)
    e.window = wnd
    result.add(e)
  of ButtonPress, ButtonRelease:
    let wnd = findWindowWithX(d, ev.xbutton.window)
    if wnd.isNil: return
    let pos = newPoint(ev.xbutton.x.Coord, ev.xbutton.y.Coord) / wnd.pixelRatio
    if ev.xbutton.button in 4.cuint .. 7.cuint:
      e = newEvent(etScroll, pos)
      const multiplierX = 30.0
      const multiplierY = -30.0
      case ev.xbutton.button
      of 4: e.offset.y = -multiplierY
      of 5: e.offset.y = multiplierY
      of 6: e.offset.x = multiplierX
      of 7: e.offset.x = -multiplierY
      else: discard
    else:
      let state = if ev.theType == ButtonPress: bsDown else: bsUp
      let button = case ev.xbutton.button
        of 1: VirtualKey.MouseButtonPrimary
        of 2: VirtualKey.MouseButtonMiddle
        of 3: VirtualKey.MouseButtonSecondary
        else: VirtualKey.Unknown
      e = newMouseButtonEvent(pos, button, state)
    e.modifiers = modifiersFromXState(ev.xbutton.state)
    e.window = wnd
    result.add(e)
  of MotionNotify:
    let wnd = findWindowWithX(d, ev.xmotion.window)
    if wnd.isNil: return
    e = newMouseMoveEvent(newPoint(ev.xmotion.x.Coord, ev.xmotion.y.Coord) / wnd.pixelRatio)
    e.modifiers = modifiersFromXState(ev.xmotion.state)
    e.window = wnd
    result.add(e)
  of ConfigureNotify:
    let wnd = findWindowWithX(d, ev.xconfigure.window)
    if wnd.isNil: return
    e = newEvent(etWindowResized)
    e.window = wnd
    e.position = newPoint(ev.xconfigure.width.Coord, ev.xconfigure.height.Coord) / wnd.pixelRatio
    result.add(e)
  of Expose:
    let wnd = findWindowWithX(d, ev.xexpose.window)
    if not wnd.isNil: wnd.setNeedsDisplay()
  else:
    discard

proc animateAndDraw() =
  let a = mainApplication()
  a.runAnimations()
  a.drawWindows()

proc onXSocket(d: PDisplay) =
  var ev: XEvent
  var evs = newSeqOfCap[Event](2)
  let application = mainApplication()
  while XPending(d) != 0:
    evs.setLen(0)
    discard XNextEvent(d, addr ev)
    eventWithXEvent(d, ev, evs)
    for i in 0 .. evs.high: discard application.handleEvent(evs[i])
  animateAndDraw()

proc registerDisplayInDispatcher(d: PDisplay) =
  let fd = XConnectionNumber(d)
  register(AsyncFD(fd))
  addRead(AsyncFD(fd)) do(fd: AsyncFD) -> bool:
    {.gcsafe.}: onXSocket(d)

proc newXWindow(r: Rect): X11Window =
  result = X11Window.new()

newWindow = proc(r: Rect): Window {.gcsafe.} =
  {.cast(gcsafe).}:
    result = newXWindow(r)
newFullscreenWindow = proc(): Window {.gcsafe.} =
  {.cast(gcsafe).}:
    result = newXWindow(zeroRect)

template runApplication*(initCode: typed) =
  block:
    initCode
    animateAndDraw()
    runForever()

method draw*(w: X11Window, r: Rect) = discard

method drawWindow(w: X11Window) =
  let c = w.renderingContext
  let oldContext = setCurrentContext(c)
  if c.beginFrame(w.backgroundColor):
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
      procCall w.Window.drawWindow()
    c.endFrame()
  setCurrentContext(oldContext)

proc scaleFactor(w: X11Window): float =
  var dpi = 96.0
  let nd = XOpenDisplay(DisplayString(w.xdisplay))
  if not nd.isNil:
    let resourceString = XResourceManagerString(nd)
    if not resourceString.isNil:
      XrmInitialize()
      let db = XrmGetStringDatabase(resourceString)
      if not db.isNil:
        var value: XrmValue
        var typ: cstring
        if XrmGetResource(db, "Xft.dpi", "String", addr typ, addr value) != 0:
          if not value.address.isNil:
            discard parseFloat($cast[cstring](value.address), dpi, 0)
        XrmDestroyDatabase(db)
    discard XCloseDisplay(nd)
  dpi / 96

proc updatePixelRatio(w: X11Window) {.inline.} =
  w.pixelRatio = w.scaleFactor()
  w.viewportPixelRatio = w.pixelRatio

method onResize*(w: X11Window, newSize: Size) =
  w.updatePixelRatio()
  procCall w.Window.onResize(newSize)
  let vp = w.frame.size * w.viewportPixelRatio
  if not w.renderingContext.isNil and not w.wgpuDevice.isNil and not w.wgpuSurface.isNil:
    w.renderingContext.configureSurface(w.wgpuDevice, w.wgpuSurface, w.wgpuFormat, vp.width.int, vp.height.int)

proc redraw() {.async.} =
  await sleepAsync(1)
  animateAndDraw()

method markNeedsDisplay*(w: X11Window) = asyncCheck redraw()

proc animationLoop() {.async.} =
  while true:
    animateAndDraw()
    if not animationEnabled: break
    await sleepAsync(1000 div 60)

method animationStateChanged*(w: X11Window, state: bool) =
  let wasDisabled = not animationEnabled
  animationEnabled = state
  if wasDisabled and animationEnabled: asyncCheck animationLoop()
