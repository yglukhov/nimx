
import nimx/[ abstract_window, system_logger, view, context, event, app, screen,
                linkage_details, portable_gl, types ]

import nimx / private / winapi_vk_map

import opengl
import logging
import windows except `SIZE`, `COORD`
import strutils
import unicode

const GWLP_USERDATA = -21

type WinAPiWindow* = ref object of Window
    hwnd: HWND
    hglrc: HGLRC
    hDC: HDC
    renderingContext: GraphicsContext

method `fullscreen=`*(w: WinAPiWindow, v: bool) =
    raise newException(OSError, "Not implemented yet")

var defaultWindow: WinAPiWindow

proc winEventProc(hwnd: HWND, msg: WINUINT, wparam: WPARAM, lparam: LPARAM): LRESULT {.stdcall, gcsafe.}

var class_name = "nimx_window"
var hInstance = 0

proc registerWinApinClass()=
    if hInstance == 0:
        var wc: WNDCLASS
        wc.style = 0
        wc.lpfnWndProc = winEventProc
        wc.cbClsExtra = 0
        wc.cbWndExtra = 0
        wc.hInstance = 0
        wc.hIcon = 0
        wc.hCursor = LoadCursor(hInstance, "IDC_ARROW")
        wc.hbrBackground = GetStockObject(WHITE_BRUSH)
        wc.lpszMenuName = nil
        wc.lpszClassName = class_name

        if RegisterClass(wc) == 0:
            warn "Failed to register ", class_name
        else:
            info "Class registered"

    hInstance = GetModuleHandle(nil)

proc setUpContext(w: WinAPiWindow)=
    w.hDC = GetDC(w.hwnd)

    var pfd: PIXELFORMATDESCRIPTOR
    pfd.nSize = sizeof(PIXELFORMATDESCRIPTOR).int16
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
    if DescribePixelFormat(w.hDC, pf, psize.WINUINT, addr pfd) == 0:
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
    else:
        info "GraphicsContext created!"

    # discard ReleaseDC(w.hwnd, w.hDC)

method init*(w: WinAPiWindow, r: types.Rect)=
    procCall w.Window.init(r)

method draw*(w: WinAPiWindow, r: types.Rect) =
    let c = currentContext()
    let gl = c.gl
    if w.mActiveBgColor != w.backgroundColor:
        gl.clearColor(w.backgroundColor.r, w.backgroundColor.g, w.backgroundColor.b, w.backgroundColor.a)
        w.mActiveBgColor = w.backgroundColor

    gl.stencilMask(0xFF)
    gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)
    gl.stencilMask(0x00)

method drawWindow(w: WinAPiWindow) =
    let c = w.renderingContext
    let oldContext = setCurrentContext(c)
    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    if SwapBuffers(w.hDC) == 0:
        warn "SwapBuffers failed"
    setCurrentContext(oldContext)

method onResize*(w: WinAPiWindow, newSize: Size) =
    w.pixelRatio = screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * w.pixelRatio), GLsizei(newSize.height * w.pixelRatio))
    procCall w.Window.onResize(newSize)

proc newWinApiWindow(r: types.Rect): WinAPiWindow=
    result.new()
    result.init(r)
    registerWinApinClass()
    if defaultWindow.isNil:
        defaultWindow = result
        mainApplication().addWindow(defaultWindow)

    let name = newWideCString("myWin32Win")
    let winName = newWideCString("winName")

    result.hwnd = CreateWindow(class_name, "Nimx window", WS_OVERLAPPEDWINDOW or WS_CLIPSIBLINGS or WS_CLIPCHILDREN, cint(r.x), cint(r.y), cint(r.width), cint(r.height), 0, 0, hInstance, nil)
    result.setUpContext()
    discard ShowWindow(result.hwnd, SW_SHOW)
    discard UpdateWindow(result.hwnd)

    if SetWindowLongPtr(result.hwnd, GWLP_USERDATA, cast[LONG_PTR](result)) == 0 and GetLastError() != 0:
        warn "hwnd user data is not setted ", GetLastError()

    var nwRect: windows.RECT
    if GetClientRect(result.hwnd, addr nwRect) != 0:
        result.onResize(newSize(nwRect.BottomRight.x.Coord - nwRect.TopLeft.x.Coord,
            nwRect.BottomRight.y.Coord - nwRect.TopLeft.y.Coord)
        )

proc getWindowFromHWND(hwnd: HWND): Window {.inline.} =
    result = cast[WinAPiWindow](GetWindowLongPtr(hwnd, GWLP_USERDATA))

proc getMouseEvent(win: Window, lparam: WPARAM, msg: WINUINT): Event=
    let x = GET_X_LPARAM(lparam)
    let y = GET_Y_LPARAM(lparam)
    let pos = newPoint(x.Coord, y.Coord)

    case msg:
    of WM_MOUSEMOVE:
        if not win.isNil:
            result = newMouseMoveEvent(pos)
            result.window = win
        discard

    of WM_LBUTTONDOWN, WM_MBUTTONDOWN, WM_RBUTTONDOWN:
        if not win.isNil:
            let button = case msg:
                of WM_LBUTTONDOWN: VirtualKey.MouseButtonPrimary
                of WM_MBUTTONDOWN: VirtualKey.MouseButtonMiddle
                of WM_RBUTTONDOWN: VirtualKey.MouseButtonSecondary
                else: VirtualKey.Unknown
            result = newMouseButtonEvent(pos, button, bsDown)
            result.window = win

    of WM_LBUTTONUP, WM_MBUTTONUP, WM_RBUTTONUP:
        if not win.isNil:
            let button = case msg:
                of WM_LBUTTONUP: VirtualKey.MouseButtonPrimary
                of WM_MBUTTONUP: VirtualKey.MouseButtonMiddle
                of WM_RBUTTONUP: VirtualKey.MouseButtonSecondary
                else: VirtualKey.Unknown
            result = newMouseButtonEvent(pos, button, bsUp)
            result.window = win
    else: discard

proc winEventProc(hwnd: HWND, msg: WINUINT, wparam: WPARAM, lparam: LPARAM): LRESULT {.stdcall.} =
    {.gcsafe.}:
        var e: Event
        let app = mainApplication()
        let win = getWindowFromHWND(hwnd)

        case msg
        of WM_PAINT:
            defaultWindow.setNeedsDisplay()
            app.runAnimations()
            app.drawWindows()

        of WM_SIZE, WM_SIZING:
            var rect: windows.RECT
            if GetClientRect(hwnd, addr rect) != 0:
                e = newEvent(etWindowResized)
                e.window = win
                e.position.x = rect.BottomRight.x.Coord - rect.TopLeft.x.Coord
                e.position.y = rect.BottomRight.y.Coord - rect.TopLeft.y.Coord

                defaultWindow.setNeedsDisplay()
                app.runAnimations()
                app.drawWindows()

            result = 1

        of WM_MOUSEMOVE, WM_MOUSEWHEEL, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_MBUTTONDOWN, WM_MBUTTONUP, WM_RBUTTONDOWN, WM_RBUTTONUP:
            e = win.getMouseEvent(lparam, msg)

        of WM_KEYUP, WM_KEYDOWN, WM_SYSKEYUP, WM_SYSKEYDOWN:
            var btnState = lparam shr 31
            var prevBtnState = (lparam and (1 shl 30)) shr 30
            var extKey = (lparam and (1 shl 24)) shr 24 # todo use to recognize left\right alt and ctrl
            let keyCode = virtualKeyFromNative(wparam.int)
            e = newKeyboardEvent(keyCode, if btnState == 0: bsDown else: bsUp, btnState != prevBtnState)
            e.window = win

        of WM_CHAR:
            case wparam
            of VK_BACK, VK_RETURN, VK_ESCAPE, VK_TAB, VK_SHIFT:
                discard
            else:
                var text = ""
                text.add(wparam.char)
                e = newEvent(etTextInput)
                e.window = win
                e.text = $newWideCString(text)
                echo "WM_CHAR ", e.text, " wpb ", toBin(wparam, 16), " wp ", wparam, " ", IsWindowUnicode(hwnd)

        of WM_DESTROY:
            discard ReleaseDC(hwnd, (win.WinAPiWindow).hDC)
            PostQuitMessage(0)

        else:
            result = DefWindowProc(hwnd, msg, wparam, lparam)

        if e.kind != etUnknown:
            result = app.handleEvent(e).int


proc runUntilQuit*()=
    var msg:MSG
    while GetMessage(addr msg, 0, 0, 0) != 0:
      discard TranslateMessage(addr msg)
      discard DispatchMessage(addr msg)

template runApplication*(body: typed): typed=
    try:
        body
        runUntilQuit()

    except:
        logi "Exception caught: ", getCurrentExceptionMsg()
        logi getCurrentException().getStackTrace()
        quit 1

newWindow = proc(r: types.Rect): Window =
    result = newWinApiWindow(r)
