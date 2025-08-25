import nimx/[ abstract_window, system_logger, view, context, event, app,
       linkage_details, portable_gl, screen ]

import darwin/objc/[runtime, nsobject]
import darwin/foundation/[nsnotification, nsautoreleasepool, nsgeometry, nsbundle, nsprocessinfo]
import darwin/app_kit/[nsview, nswindow, nsapplication, nsmenu, nsevent, nsopenglview, nsopengl]
import darwin/core_video/[cvdisplay_link]

import opengl
import std/[unicode, times]

{.passL: "-framework AppKit".}

type
  NimxView = ptr object of NSOpenGLView
  NimxWindow = ptr object of NSWindow
  NimxAppDelegate = ptr object of NSObject

  Pcb = ref object
    cb: proc()

  DelegateExtra = object
    pcb: Pcb

  NimxViewExtra = object
    w: AppkitWindow
  NimxWindowExtra = object
    w: AppkitWindow

  AppkitWindow* = ref object of Window
    nativeWindow: NimxWindow
    nativeView: NimxView
    renderingContext: GraphicsContext
    displayLink: CVDisplayLink

const
  AppDelegateClass = "NimxAppDelegate"


proc getApplicationName(): string =
  let b = NSBundle.mainBundle()
  var res = cast[NSString](b.objectForInfoDictionaryKey("CFBundleDisplayName"))
  if res == nil:
    res = cast[NSString](b.objectForInfoDictionaryKey("CFBundleName"))
  if res.len != 0:
    res = NSProcessInfo.processInfo().processName()
  $res

proc createApplicationMenu() =
  let app = NSApplication.sharedApplication()
  if app == nil: return
  if app.mainMenu() != nil and app.mainMenu().numberOfItems() != 1: return

  let mainMenu = NSMenu.alloc().init()
  let appName = getApplicationName()

  let appleMenu = NSMenu.alloc().initWithTitle("")
  discard appleMenu.addItem("About " & appName, sel_registerName("orderFrontStandardAboutPanel:"), "")
  appleMenu.addItem(NSMenuItem.separatorItem())
  discard appleMenu.addItem("Settings…", nil, ",")
  appleMenu.addItem(NSMenuItem.separatorItem())

  let serviceMenu = NSMenu.alloc.initWithTitle("")
  var menuItem = appleMenu.addItem("Services", nil, "")
  menuItem.setSubmenu(serviceMenu)
  app.setServicesMenu(serviceMenu)
  serviceMenu.release()
  appleMenu.addItem(NSMenuItem.separatorItem())

  discard appleMenu.addItem("Hide " & appName, sel_registerName("hide:"), "h")
  menuItem = appleMenu.addItem("Hide Others", sel_registerName("hideOtherApplications:"), "h")
  menuItem.setKeyEquivalentModifierMask(NSEventModifierFlags(NSEventModifierFlagOption.ord or NSEventModifierFlagCommand.ord))
  discard appleMenu.addItem("Show All", sel_registerName("unhideAllApplications:"), "")
  appleMenu.addItem(NSMenuItem.separatorItem())
  discard appleMenu.addItem("Quit " & appName, sel_registerName("terminate:"), "q")

  menuItem = NSMenuItem.alloc().initWithTitle("", nil, "")
  menuItem.setSubmenu(appleMenu)
  mainMenu.addItem(menuItem)
  menuItem.release()
  appleMenu.release()

  if true: # Create view menu if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6)
    let viewMenu = NSMenu.alloc().initWithTitle("View")
    menuItem = viewMenu.addItem("Toggle Full Screen", sel_registerName("toggleFullScreen:"), "f")
    menuItem.setKeyEquivalentModifierMask(NSEventModifierFlags(NSEventModifierFlagControl.ord or NSEventModifierFlagCommand.ord))

    menuItem = NSMenuItem.alloc().initWithTitle("View", nil, "")
    menuItem.setSubmenu(viewMenu)
    mainMenu.addItem(menuItem)
    menuItem.release()
    viewMenu.release()

  let windowMenu = NSMenu.alloc().initWithTitle("Window")
  discard windowMenu.addItem("Minimize", sel_registerName("performMiniaturize:"), "m")
  discard windowMenu.addItem("Zoom", sel_registerName("performZoom:"), "")
  menuItem = mainMenu.addItem("Window", nil, "")
  menuItem.setSubmenu(windowMenu)
  app.setWindowsMenu(windowMenu)
  windowMenu.release()

  app.setMainMenu(mainMenu)
  mainMenu.release()

proc appDidFinishLaunching(self: NimxAppDelegate, cmd: SEL, a: NSNotification) {.cdecl.} =
  createApplicationMenu()
  let delegateClass = getClass(AppDelegateClass)
  assert(delegateClass != nil)
  let extra = cast[ptr DelegateExtra](cast[uint](self) + delegateClass.getInstanceSize().uint)
  let pcb = extra.pcb
  assert(pcb != nil)
  pcb.cb()
  GC_unref(pcb)
  extra.pcb = nil
  NSApplication.sharedApplication().activateIgnoringOtherApps(true)

proc createAppDelegateClass(): ObjcClass =
  result = allocateClassPair(getClass("NSObject"), AppDelegateClass, 0)
  discard addMethod(result, sel_registerName("applicationDidFinishLaunching:"), appDidFinishLaunching)

  registerClassPair(result)

proc createViewClass(): ObjcClass {.gcsafe.}
proc createWindowClass(): ObjcClass {.gcsafe.}

proc viewClass(): ObjcClass =
  var r {.global.}: ObjcClass
  if r == nil:
    r = createViewClass()
  r

proc windowClass(): ObjcClass =
  var r {.global.}: ObjcClass
  if r == nil:
    r = createWindowClass()
  r

proc createPixelFormat(colorBits, depthBits: uint32): NSOpenGLPixelFormat =
  var pixelAttribs = [
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFAAccelerated,
    NSOpenGLPFAColorSize,
    colorBits,
    NSOpenGLPFADepthSize,
    depthBits,
    0
  ]
  #  NSOpenGLPixelFormatAttribute pixelAttribs[ 16 ];
  #  int pixNum = 0;
  #  NSDictionary *fullScreenMode;

  #  pixelAttribs[pixNum++] = NSOpenGLPFADoubleBuffer;
  #  pixelAttribs[pixNum++] = NSOpenGLPFAAccelerated;
  #  pixelAttribs[pixNum++] = NSOpenGLPFAColorSize;
  #  pixelAttribs[pixNum++] = colorBits;
  #  pixelAttribs[pixNum++] = NSOpenGLPFADepthSize;
  #  pixelAttribs[pixNum++] = depthBits;
  #  if( runningFullScreen )  // Do this before getting the pixel format
  #  {
  #   pixelAttribs[pixNum++] = NSOpenGLPFAFullScreen;
  #   fullScreenMode = (NSDictionary *) CGDisplayBestModeForParameters(
  #                      kCGDirectMainDisplay,
  #                      colorBits, frame.size.width,
  #                      frame.size.height, NULL );
  #   CGDisplayCapture( kCGDirectMainDisplay );
  #   CGDisplayHideCursor( kCGDirectMainDisplay );
  #   CGDisplaySwitchToMode( kCGDirectMainDisplay,
  #              (CFDictionaryRef) fullScreenMode );
  #  }
  #  pixelAttribs[pixNum] = 0;
  NSOpenGLPixelFormat.alloc().initWithAttributes(addr pixelAttribs[0])
  #  return [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelAttribs];
# }

when defined(ios):
  method fullscreen*(w: AppkitWindow): bool = true
else:
  method `fullscreen=`*(w: AppkitWindow, v: bool) =
    raise newException(OSError, "Not implemented yet")

var animationEnabled = 0

method animationStateChanged*(w: AppkitWindow, flag: bool) =
  discard

proc onDisplayLink(displayLink: CVDisplayLink, inNow, inOutputTime: ptr CVTimeStamp, flagsIn: CVOptionFlags,
                   flagsOut: var CVOptionFlags, userInfo: pointer) {.cdecl, stackTrace: off.} =
  let v = cast[NSView](userInfo)
  v.performSelectorOnMainThread(sel_registerName("onDisplayLinkMainThread:"), nil, false)

proc initCommon(w: AppkitWindow, r: view.Rect) =
  procCall init(w.Window)

  let frame = NSMakeRect(r.x, r.y, r.width, r.height)

  let styleMask = NSWindowStyleMask(NSWindowStyleMaskTitled or NSWindowStyleMaskClosable or
     NSWindowStyleMaskMiniaturizable or NSWindowStyleMaskResizable)

  let winClass = windowClass()
  let viewClass = viewClass()

  let win = cast[NimxWindow](
    cast[NSWindow](
      createInstance(winClass, sizeof(NimxWindowExtra).csize_t)).initWithContentRect(frame, styleMask,
        NSBackingStoreBuffered, true))

  let winExtra = cast[ptr NimxWindowExtra](cast[uint](win) + winClass.getInstanceSize().uint)
  winExtra.w = w

  let pixelFormat = createPixelFormat(16, 16)
  let glView = cast[NimxView](
    cast[NSOpenGLView](
      createInstance(viewClass, sizeof(NimxViewExtra).csize_t)).initWithFrame(NSRect(), pixelFormat))

  glView.openGLContext().makeCurrentContext()

  let viewExtra = cast[ptr NimxViewExtra](cast[uint](glView) + viewClass.getInstanceSize().uint)
  viewExtra.w = w

  glView.setWantsBestResolutionOpenGLSurface(true)
  win.setContentView(glView)

  w.nativeWindow = win
  w.nativeView = glView

  # The context has to be inited before makeKeyAndOrderFront.
  w.renderingContext = newGraphicsContext()

  discard CVDisplayLinkCreateWithActiveCGDisplays(addr w.displayLink)
  discard w.displayLink.setOutputCallback(onDisplayLink, cast[pointer](glView))
  discard w.displayLink.start()

  win.makeKeyAndOrderFront(nil)
  mainApplication().addWindow(w)

proc initFullscreen*(w: AppkitWindow) =
  w.initCommon(newRect(0, 0, 800, 600))

method init*(w: AppkitWindow) =
  w.initCommon(newRect(0, 0, 800, 600))

proc newFullscreenAppkitWindow(): AppkitWindow =
  result.new()
  result.initFullscreen()

proc newAppkitWindow(r: view.Rect): AppkitWindow =
  result.new()
  result.init()

newWindow = proc(r: view.Rect): Window =
  result = newAppkitWindow(r)

newFullscreenWindow = proc(): Window =
  result = newFullscreenAppkitWindow()

method drawWindow(w: AppkitWindow) =
  let c = w.renderingContext
  c.gl.clear(c.gl.COLOR_BUFFER_BIT or c.gl.STENCIL_BUFFER_BIT or c.gl.DEPTH_BUFFER_BIT)
  let oldContext = setCurrentContext(c)

  c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
    procCall w.Window.drawWindow()
  let nv = w.nativeView
  nv.openGLContext().flushBuffer()
  setCurrentContext(oldContext)

method markNeedsDisplay*(w: AppkitWindow) =
  w.nativeView.setNeedsDisplay(true)

#[
proc windowFromSDLEvent[T](event: T): EmscriptenWindow =
  let sdlWndId = event.windowID
  let sdlWin = getWindowFromID(sdlWndId)
  if sdlWin != nil:
    result = cast[EmscriptenWindow](sdlWin.getData("__nimx_wnd"))

proc positionFromSDLEvent[T](event: T): auto =
  newPoint(event.x.Coord, event.y.Coord)

template buttonStateFromSDLState(s: KeyState): ButtonState =
  if s == KeyPressed:
    bsDown
  else:
    bsUp

var activeTouches = 0

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
      if bs == bsDown:
        inc activeTouches
        if activeTouches == 1:
          result.pointerId = 0
      elif bs == bsUp:
        dec activeTouches
      #logi "EVENT: ", result.position, " ", result.buttonState
      result.window = defaultWindow
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
        result.offset.x = mouseEv.x.Coord
        result.offset.y = mouseEv.y.Coord

    of KeyDown, KeyUp:
      let keyEv = cast[KeyboardEventPtr](event)
      let wnd = windowFromSDLEvent(keyEv)
      result = newKeyboardEvent(virtualKeyFromNative(keyEv.keysym.sym), buttonStateFromSDLState(keyEv.state.KeyState), keyEv.repeat)
      result.rune = keyEv.keysym.unicode.Rune
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
]#
method onResize*(w: AppkitWindow, newSize: Size) =
  let sf = screenScaleFactor()
  glViewport(0, 0, GLSizei(newSize.width * sf), GLsizei(newSize.height * sf))
  procCall w.Window.onResize(newSize)
#[
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

proc nextEvent(evt: var sdl2.Event) =
  when defined(ios):
    if waitEvent(evt):
      discard handleEvent(addr evt)
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

method startTextInput*(w: EmscriptenWindow, r: Rect) =
  startTextInput()

method stopTextInput*(w: EmscriptenWindow) =
  stopTextInput()
]#

proc runUntilQuit(cb: proc()) =
  let pool = NSAutoreleasePool.alloc().init()
  let app = NSApplication.sharedApplication()

  var delegateClass = getClass(AppDelegateClass)
  if delegateClass == nil:
    delegateClass = createAppDelegateClass()
  let delegate = cast[NimxAppDelegate](createInstance(delegateClass, sizeof(DelegateExtra).csize_t))

  var extra = cast[ptr DelegateExtra](cast[uint](delegate) + delegateClass.getInstanceSize().uint)
  extra.pcb = Pcb(cb: cb)
  GC_ref(extra.pcb)
  app.setDelegate(delegate)

  app.run()
  app.setDelegate(nil)
  delegate.release()
  pool.drain()

template runApplication*(body: typed) =
  try:
    runUntilQuit(proc() = body)
  except:
    logi "Exception caught: ", getCurrentExceptionMsg()
    logi getCurrentException().getStackTrace()
    quit 1

proc pointFromNSEvent(w: AppkitWindow, e: NSEvent): Point =
  let v = w.nativeView
  var pt = v.convertPointFromView(e.locationInWindow, nil)
  result.x = pt.x
  result.y = v.frame.size.height - pt.y

proc eventWithNSEvent(w: AppkitWindow, e: NSEvent): Event =
  case e.kind
  of NSLeftMouseDown:
    result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonPrimary, bsDown)
  of NSLeftMouseUp:
    result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonPrimary, bsUp)
  of NSLeftMouseDragged:
    result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonPrimary, bsUnknown)
  of NSRightMouseDown:
    result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonSecondary, bsDown)
  of NSRightMouseUp:
    result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonSecondary, bsUp)
  of NSRightMouseDragged:
    result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonSecondary, bsUnknown)
  else:
    discard

  result.window = w

proc getNimxWindow(v: NimxView): AppkitWindow =
  let extra = cast[ptr NimxViewExtra](cast[uint](v) + getInstanceSize(viewClass()).uint)
  extra.w

proc getNimxWindow(v: NimxWindow): AppkitWindow =
  let extra = cast[ptr NimxWindowExtra](cast[uint](v) + getInstanceSize(windowClass()).uint)
  extra.w

proc acceptsFirstResponder(self: NimxView, s: SEL): bool = true
proc drawRect(self: NimxView, s: SEL, r: NSRect) =
  mainApplication().runAnimations()
  mainApplication().drawWindows()
  # drawWindow(getNimxWindow(self))

proc reshape(self: NimxView, sel: SEL) =
  var sup = ObjcSuper(receiver: self, superClass: getSuperclass(viewClass()))
  let superImp = cast[proc(sup: var ObjcSuper, c: SEL) {.cdecl.}](objc_msgSendSuper)
  superImp(sup, sel)

  let w = getNimxWindow(self)
  if w != nil:
    let s = self.bounds
    w.onResize(newSize(s.size.width, s.size.height))

proc onDisplayLinkMainThread(self: NimxView, s: SEL, r: NSObject) =
  self.setNeedsDisplay(true)

proc createViewClass(): ObjcClass =
  result = allocateClassPair(getClass("NSOpenGLView"), "NimxView", 0)

  discard addMethod(result, sel_registerName("acceptsFirstResponder"), acceptsFirstResponder)
  discard addMethod(result, sel_registerName("drawRect:"), drawRect)
  discard addMethod(result, sel_registerName("reshape"), reshape)
  discard addMethod(result, sel_registerName("onDisplayLinkMainThread:"), onDisplayLinkMainThread)

  registerClassPair(result)


# - (void)keyDown: (NSEvent*) e {
#   [super keyDown: e];
# }

# - (void)keyUp: (NSEvent*) e {
#   [super keyUp: e];
# }

# - (void)insertText:(id)string replacementRange:(NSRange)replacementRange {
#   NSLog(@"text: %@", string);
# }

# - (void)doCommandBySelector:(SEL)selector {

# }

# - (void)setMarkedText:(id)string selectedRange:(NSRange)selectedRange replacementRange:(NSRange)replacementRange {

# }

# - (void)unmarkText {

# }

# - (NSRange)selectedRange {
#   return NSMakeRange(0, 0);
# }

# - (NSRange)markedRange {
#   return NSMakeRange(0, 0);
# }

# - (BOOL)hasMarkedText {
#   return NO;
# }

# - (nullable NSAttributedString *)attributedSubstringForProposedRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {
#   return nil;
# }

# - (NSArray<NSString *> *)validAttributesForMarkedText {
#   return nil;
# }

# - (NSRect)firstRectForCharacterRange:(NSRange)range actualRange:(nullable NSRangePointer)actualRange {
#   return NSZeroRect;
# }

# - (NSUInteger)characterIndexForPoint:(NSPoint)point {
#   return -1;
# }

# @end

# """.}


proc sendEvent(self: NimxWindow, cmd: SEL, e: NSEvent) {.cdecl.} =
  var s = ObjcSuper(receiver: self, superClass: getSuperclass(windowClass()))
  let superImp = cast[proc(s: var ObjcSuper, c: SEL, e: NSEvent) {.cdecl.}](objc_msgSendSuper)
  superImp(s, cmd, e)

  let w = self.getNimxWindow()
  var evt = w.eventWithNSEvent(e)
  discard mainApplication().handleEvent(evt)

proc createWindowClass(): ObjcClass =
  result = allocateClassPair(getClass("NSWindow"), "NimxWindow", 0)
  discard addMethod(result, sel_registerName("sendEvent:"), sendEvent)

  registerClassPair(result)
