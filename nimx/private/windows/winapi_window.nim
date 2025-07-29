
import nimx/[ abstract_window, system_logger, view, context, event, app, screen,
        linkage_details, portable_gl, types, cursor ]

import nimx / private / winapi_vk_map

import opengl
import std/[logging, asyncdispatch, times, monotimes, heapqueue]
import winim except SIZE, COORD
import strutils
import unicode

const GWLP_USERDATA = -21

type
  WinapiWindow* = ref object of Window
  hwnd: HWND
  hglrc: HGLRC
  hDC: HDC
  renderingContext: GraphicsContext

method `fullscreen=`*(w: WinapiWindow, v: bool) =
  raise newException(OSError, "Not implemented yet")

var animationEnabled = false

proc winEventProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM): LRESULT {.stdcall, gcsafe.}

const class_name = "nimx_window"

proc registerWinApinClass()=
  var wc: WNDCLASS
  # wc.style = 0
  wc.lpfnWndProc = winEventProc
  # wc.cbClsExtra = 0
  # wc.cbWndExtra = 0
  # wc.hInstance = 0
  # wc.hIcon = 0
  # let hInstance = GetModuleHandle(nil)
  wc.hCursor = LoadCursor(0, IDC_ARROW)
  wc.hbrBackground = GetStockObject(WHITE_BRUSH)
  # wc.lpszMenuName = nil
  wc.lpszClassName = class_name

  if RegisterClass(wc) == 0:
  warn "Failed to register ", class_name

proc setUpContext(w: WinapiWindow)=
  w.hDC = GetDC(w.hwnd)

  var pfd: PIXELFORMATDESCRIPTOR
  pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR).WORD
  pfd.nVersion = 1
  pfd.dwFlags = PFD_DOUBLEBUFFER or PFD_DRAW_TO_WINDOW or PFD_SUPPORT_OPENGL
  pfd.iPixelType = PFD_TYPE_RGBA
  pfd.cColorBits = 32

  var pf = ChoosePixelFormat(w.hDC, addr pfd)
  if pf == 0:
  warn "Can't choose pixel format ", GetLastError()

  if SetPixelFormat(w.hDC, pf, addr pfd) == 0:
  warn "Can't set pixel format ", GetLastError()

  let psize = sizeof(PIXELFORMATDESCRIPTOR)
  if DescribePixelFormat(w.hDC, pf, psize.UINT, addr pfd) == 0:
  warn "Can't descripe pixel format ", GetLastError()

  w.hglrc = wglCreateContext(w.hDC)
  if w.hglrc == 0:
  warn "Can't create context ", GetLastError()
  let res = wglMakeCurrent(w.hDC, w.hglrc)
  if res == 0:
  warn "Can't make current ", res, " context ", w.hglrc

  w.renderingContext = newGraphicsContext()
  if w.renderingContext.isNil:
  warn "Can't create GraphicsContext "

type
  PROCESS_DPI_AWARENESS* {.size: sizeof(cint).} = enum
  PROCESS_DPI_UNAWARE
  PROCESS_SYSTEM_DPI_AWARE
  PROCESS_PER_MONITOR_DPI_AWARE

proc SetProcessDpiAwareness(value: PROCESS_DPI_AWARENESS): HRESULT {.importc, stdcall, dynlib: "shcore".}

method init*(w: WinapiWindow, r: types.Rect) =
  procCall w.Window.init(r)
  mainApplication().addWindow(w)

  discard SetProcessDpiAwareness(PROCESS_PER_MONITOR_DPI_AWARE)
  registerWinApinClass()

  let hInstance = GetModuleHandle(nil)
  w.hwnd = CreateWindow(class_name, "nimx", WS_OVERLAPPEDWINDOW or WS_CLIPSIBLINGS or WS_CLIPCHILDREN, cint(r.x), cint(r.y), cint(r.width), cint(r.height), 0, 0, hInstance, nil)
  if w.hwnd == 0:
  let e = GetLastError()
  assert(false, "CreateWindow returned NULL, last error: " & $e)

  w.setUpContext()
  discard ShowWindow(w.hwnd, SW_SHOW)
  discard UpdateWindow(w.hwnd)

  SetLastError(0)
  if SetWindowLongPtr(w.hwnd, GWLP_USERDATA, cast[LONG_PTR](w)) == 0 and GetLastError() != 0:
  doAssert(false, "hwnd user data is not set: " & $GetLastError())

  var nwRect: winim.RECT
  if GetClientRect(w.hwnd, addr nwRect) != 0:
  w.onResize(newSize(nwRect.right.Coord - nwRect.left.Coord,
            nwRect.bottom.Coord - nwRect.top.Coord))

method draw*(w: WinapiWindow, r: types.Rect) =
  let c = currentContext()
  let gl = c.gl
  if w.mActiveBgColor != w.backgroundColor:
  gl.clearColor(w.backgroundColor.r, w.backgroundColor.g, w.backgroundColor.b, w.backgroundColor.a)
  w.mActiveBgColor = w.backgroundColor

  gl.stencilMask(0xFF)
  gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)
  gl.stencilMask(0x00)

method drawWindow(w: WinapiWindow) =
<<<<<<< HEAD
=======
  if w.hDC == 0:
  echo "Window destroyed"
  return

>>>>>>> version-2
  let c = w.renderingContext
  let oldContext = setCurrentContext(c)
  c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
  procCall w.Window.drawWindow()
  if SwapBuffers(w.hDC) == 0:
  warn "SwapBuffers failed"
  setCurrentContext(oldContext)

method onResize*(w: WinapiWindow, newSize: Size) =
  w.pixelRatio = screenScaleFactor()
  glViewport(0, 0, GLSizei(newSize.width * w.pixelRatio), GLsizei(newSize.height * w.pixelRatio))
  procCall w.Window.onResize(newSize)

proc newWinApiWindow(r: types.Rect): WinapiWindow =
  result.new()
  result.init(r)

proc getWindowFromHWND(hwnd: HWND): WinapiWindow {.inline.} =
  cast[WinapiWindow](GetWindowLongPtr(hwnd, GWLP_USERDATA))

proc getMouseEvent(win: Window, wparam: WPARAM, lparam: LPARAM, msg: UINT): Event=
  let x = GET_X_LPARAM(lparam)
  let y = GET_Y_LPARAM(lparam)
  let pos = newPoint(x.Coord, y.Coord)

  case msg:
  of WM_MOUSEMOVE:
  result = newMouseMoveEvent(pos)

  of WM_LBUTTONDOWN, WM_MBUTTONDOWN, WM_RBUTTONDOWN:
  let button = case msg:
    of WM_LBUTTONDOWN: VirtualKey.MouseButtonPrimary
    of WM_MBUTTONDOWN: VirtualKey.MouseButtonMiddle
    of WM_RBUTTONDOWN: VirtualKey.MouseButtonSecondary
    else: VirtualKey.Unknown
  result = newMouseButtonEvent(pos, button, bsDown)

  of WM_LBUTTONUP, WM_MBUTTONUP, WM_RBUTTONUP:
  let button = case msg:
    of WM_LBUTTONUP: VirtualKey.MouseButtonPrimary
    of WM_MBUTTONUP: VirtualKey.MouseButtonMiddle
    of WM_RBUTTONUP: VirtualKey.MouseButtonSecondary
    else: VirtualKey.Unknown
  result = newMouseButtonEvent(pos, button, bsUp)

  of WM_MOUSEWHEEL, WM_MOUSEHWHEEL:
  result = newEvent(etScroll, pos)
  let delta = cast[int16](HIWORD(wparam))
  const multiplierX = 1 / 30.0
  const multiplierY = 1 / -30.0
  # echo delta
  if msg == WM_MOUSEWHEEL:
    result.offset.y = delta.Coord * multiplierX
  else:
    result.offset.x = delta.Coord * multiplierY
  echo result.offset

  else: discard
  result.window = win

const WM_DPICHANGED = 0x02E0

proc winEventProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM): LRESULT {.stdcall.} =
  var e: Event
  let app = mainApplication()
  let win = getWindowFromHWND(hwnd)

  if win.isNil:
  return DefWindowProc(hwnd, msg, wparam, lparam)

  case msg
  of WM_PAINT:
  # echo "PAINT ", epochTime()
  win.setNeedsDisplay()

  of WM_SETCURSOR:
  if LOWORD(lParam) == HTCLIENT and hCursor != 0:
    SetCursor(hCursor)
    return TRUE
  else:
    return DefWindowProc(hwnd, msg, wparam, lparam)

  of WM_SIZE, WM_SIZING:
  var rect: winim.RECT
  if GetClientRect(hwnd, addr rect) != 0:
    e = newEvent(etWindowResized)
    e.window = win
    e.position.x = rect.right.Coord - rect.left.Coord
    e.position.y = rect.bottom.Coord - rect.top.Coord

    win.setNeedsDisplay()
    app.runAnimations()
    app.drawWindows()

  result = 1

  of WM_MOUSEMOVE, WM_MOUSEWHEEL, WM_MOUSEHWHEEL, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_MBUTTONDOWN, WM_MBUTTONUP, WM_RBUTTONDOWN, WM_RBUTTONUP:
  e = win.getMouseEvent(wparam, lparam, msg)

  of WM_KEYUP, WM_KEYDOWN, WM_SYSKEYUP, WM_SYSKEYDOWN:
  var btnState = lparam shr 31
  var prevBtnState = (lparam and (1 shl 30)) shr 30
  var extKey = (lparam and (1 shl 24)) shr 24 # todo use to recognize left\right alt and ctrl
  let keyCode = virtualKeyFromNative(wparam.int)
  e = newKeyboardEvent(keyCode, if btnState == 0: bsDown else: bsUp, btnState != prevBtnState)
  e.window = win
  # if msg == WM_KEYDOWN:
  #   echo "DOWN: ", keyCode

  of WM_CHAR:
  case wparam
  of VK_BACK, VK_RETURN, VK_ESCAPE, VK_TAB, VK_SHIFT:
    discard
  else:
    if wparam >= 32:
    let text = newWideCString(1)
    text[0] = wparam.Utf16Char
    e = newEvent(etTextInput)
    e.window = win
    e.text = $text
    # echo "WM_CHAR \"", e.text, "\" wpb ", toBin(wparam, 16), " wp ", wparam

  of WM_DESTROY:
  # echo "DESTROY!"
  discard ReleaseDC(hwnd, win.hDC)
<<<<<<< HEAD
=======
  # win.hDC = 0
>>>>>>> version-2
  PostQuitMessage(0)

  of WM_DPICHANGED:
  echo "WM_DPICHANGED handling not implemented :/"
  result = DefWindowProc(hwnd, msg, wparam, lparam)

  else:
  result = DefWindowProc(hwnd, msg, wparam, lparam)

  if e.kind != etUnknown:
  result = app.handleEvent(e).int

proc animateAndDraw() =
  mainApplication().runAnimations()
  mainApplication().drawWindows()

var tmpMessage: MSG

proc runUntilQuit*() =
  var msg: MSG
  animateAndDraw()

  let disp = getGlobalDispatcher()
  var ioPort = disp.getIoHandler()

  # Main loop
  while true:
  var timeout = INFINITE
  if disp.timers.len != 0:
    timeout = inMilliseconds(disp.timers[0].finishAt - getMonoTime()).int32
    if timeout <= 0:
    asyncdispatch.poll(0)
    continue
  const animFrameTimeout = 1000 div 60
  if animationEnabled and (timeout == INFINITE or timeout > animFrameTimeout):
    timeout = animFrameTimeout

  let r = MsgWaitForMultipleObjectsEx(1, addr ioPort, timeout, QS_ALLEVENTS, 0)
  if r == WAIT_OBJECT_0 + 1:
    # Message available
    if PeekMessage(addr msg, 0, 0, 0, 1) != 0:
    if msg.message == WM_QUIT:
      echo "quit"
      break

    # Here goes a hack to dispatch textInput events _before_
    # corresponding key events. It's the behavior that nimx event dispatching
    # depends upon. Maybe could be fixed in a higher level code.
    if TranslateMessage(addr msg):
      if tmpMessage.message != 0:
      discard DispatchMessage(addr tmpMessage)
      tmpMessage = msg
    else:
      discard DispatchMessage(addr msg)

      if tmpMessage.message != 0:
      discard DispatchMessage(addr tmpMessage)
      tmpMessage.message = 0

  elif r == WAIT_TIMEOUT:
    # We can hit timeout even if we don't have any timers in asyncdispatch,
    # if e.g. animation is running
    if hasPendingOperations():
    asyncdispatch.poll(0)
  elif r == WAIT_OBJECT_0:
    # ioPort completion...
    # echo "ioport!"
    asyncdispatch.poll(0)
  else:
    doAssert(false, "Unexpected result from MsgWaitFromMultipleObjectsEx: " & $r)

  animateAndDraw()

method animationStateChanged*(w: WinapiWindow, state: bool) =
  animationEnabled = state

method `title=`*(w: WinapiWindow, t: string) =
  SetWindowTextW(w.hWnd, newWideCString(t))

method title*(w: WinapiWindow): string =
  let sz = GetWindowTextLengthW(w.hWnd)
  let s = newWideCString(sz + 1)
  let sz1 = GetWindowTextW(w.hWnd, s, sz + 1)
  $s

proc reopenStdout() {.inline.} =
  # fix stdout not working in already opened cmd when compiling as a gui app
  when compileOption("app", "gui"):
  AttachConsole(-1)
  discard stdout.reopen("CONOUT$", fmWrite)

template runApplication*(body: typed) =
  try:
  reopenStdout()
  body
  runUntilQuit()

  except:
  logi "Exception caught: ", getCurrentExceptionMsg()
  logi getCurrentException().getStackTrace()
  quit 1

newWindow = proc(r: types.Rect): Window =
  newWinApiWindow(r)

newFullscreenWindow = proc(): Window =
  newWinApiWindow(zeroRect)
