when not defined(wasm):
  {.error: "This module can be used only for wasm target".}

import wasmrt

import nimx/[ abstract_window, system_logger, view, context, matrixes, app,
      portable_gl, event ]
import nimx/private/js_vk_map

type WebWindow* = ref object of Window
  renderingContext: GraphicsContext
  canvasId: string

proc fullScreenAvailableAux(): int {.importwasmraw: """
  var d = document;
  return d.fullscreenEnabled|d.webkitFullscreenEnabled
""".}

method fullscreenAvailable*(w: WebWindow): bool =
  fullScreenAvailableAux() != 0

proc fullscreenAux(): bool {.importwasmraw: """
  var d = document;
  return !!(d.fullscreenElement || d.webkitFullscreenElement)
""".}

method fullscreen*(w: WebWindow): bool =
  fullscreenAux()

proc requestFullscreen(canvasId: cstring) {.importwasmraw: """
  var c = document.getElementById(_nimsj($0));
  if (c.requestFullscreen)
    c.requestFullscreen();
  else if (c.webkitRequestFullscreen)
    c.webkitRequestFullscreen();
""".}

proc exitFullscreen() {.importwasmraw: """
  var d = document;
  if (d.exitFullscreen)
    d.exitFullscreen();
  else if (d.webkitExitFullscreen)
    d.webkitExitFullscreen();
""".}

method `fullscreen=`*(w: WebWindow, v: bool) =
  let isFullscreen = w.fullscreen

  if not isFullscreen and v:
    requestFullscreen(w.canvasId)
  elif isFullscreen and not v:
    exitFullscreen()

export abstract_window

# proc setupWebGL() =
#   {.emit: """

#   window.__nimx_focused_canvas = null;

#   document.addEventListener('mousedown', function(event) {
#     window.__nimx_focused_canvas = event.target;
#   }, false);

#   """.}


# setupWebGL()

# proc setupEventHandlersForCanvas(w: WebWindow, c: Element) =
#   let onresize = proc (e: dom.Event): bool =
#     var sizeChanged = false
#     var newWidth, newHeight : Coord
#     {.emit: """
#     `newWidth` = `c`.width;
#     `newHeight` = `c`.height;
#     var r = `c`.getBoundingClientRect();
#     if (r.width !== `c`.width) {
#       `newWidth` = r.width;
#       `c`.width = r.width;
#       `sizeChanged` = true;
#     }
#     if (r.height !== `c`.height) {
#       `newHeight` = r.height
#       `c`.height = r.height;
#       `sizeChanged` = true;
#     }
#     """.}
#     if sizeChanged:
#       var evt = newEvent(etWindowResized)
#       evt.window = w
#       evt.position.x = newWidth
#       evt.position.y = newHeight
#       discard mainApplication().handleEvent(evt)

#   let onfocus = proc()=
#     w.onFocusChange(true)

#   let onblur = proc()=
#     w.onFocusChange(false)


#   window.onresize = `onresize`;
#   window.onfocus = `onfocus`;
#   window.onblur = `onblur`;
#   """.}

proc setupMouseEventHandlers(
  c: cstring,
  m: proc(x, y: cdouble, buttonState, buttonCode: int32, deltaX, deltaY: cdouble): int32 {.nimcall.}
     ) {.importwasmraw: """
  var d = document, c = d.getElementById(_nimsj($0)),
  om = (s, e) => {
    var r = c.getBoundingClientRect();
    if (_nime._diddiidd($1, e.clientX - r.left, e.clientY - r.top, s, e.button, e.deltaX, e.deltaY))
      e.preventDefault()
  };
  d.addEventListener('mousemove', e => om(0, e));
  d.addEventListener('mousedown', e => om(1, e));
  d.addEventListener('mouseup', e => om(2, e));
  c.addEventListener('wheel', e => om(3, e))
  """.}

proc setupKeyEventHandlers(
  m: proc(keyCode, repeat, buttonState: int32): int32 {.nimcall.}
     ) {.importwasmraw: """
  var d = document,
  om = (s, e) => {
    if (_nime._diiii($0, e.keyCode, e.repeat, s)) e.preventDefault()
  };
  d.addEventListener('keydown', e => om(1, e));
  d.addEventListener('keyup', e => om(0, e))
  """.}

proc requestAnimFrame(p: proc() {.nimcall}) {.importwasmraw: """
requestAnimationFrame(() => {try{_nime._dv($0)}catch(e) {console.log("Error caught", e);_nime.nimerr(); throw e;}})
""".}

proc animFrame() =
  mainApplication().runAnimations()
  mainApplication().drawWindows()
  requestAnimFrame(animFrame)

proc getDocumentElementFloatProp(i, p: cstring): cdouble {.importwasmexpr: "document.getElementById(_nimsj($0))[_nimsj($1)]".}
proc createCanvas(i: cstring, x, y: cfloat) {.importwasmraw: """
var d = document, w = window, I = _nimsj($0), e = d.getElementById(I);
if (!e) {
  e = d.createElement("canvas");
  e.id = I;
  d.body.appendChild(e)
}
e.style.width = $1 + 'px';
e.style.height = $2 + 'px';

if (!w.GLCtx) {
  var o = {stencil: true, alpha: false, premultipliedAlpha: false, antialias: false}, c = null;
  try {
    c = e.getContext('webgl', o)
  } catch(_) {}
  if (!c)
    try {
      c  = e.getContext('experimental-webgl', o)
    } catch(_) {}

  if (c) {
    c.getExtension('OES_standard_derivatives');
    c.pixelStorei(c.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    w.GLCtx = c
  } else
    alert("Your browser does not support WebGL. Please, use a modern browser.")
}
""".}

proc onMouse(x, y: cdouble, buttonState, buttonCode: int32, dx, dy: cdouble): int32 =
  let a = mainApplication()
  let w = a.keyWindow
  if not w.isNil:
    let pos = newPoint(x, y)
    var evt: Event
    if buttonState == 3:
      evt = newEvent(etScroll, pos)
      evt.offset.x = dx.Coord
      evt.offset.y = dy.Coord
    else:
      let buttonState = case buttonState
                        of 1: bsDown
                        of 2: bsUp
                        else: bsUnknown
      let buttonCode = case buttonCode
                      of 1: VirtualKey.MouseButtonPrimary
                      of 2: VirtualKey.MouseButtonSecondary
                      of 3: VirtualKey.MouseButtonMiddle
                      else: VirtualKey.Unknown
      evt = if buttonState == bsUnknown:
          newMouseMoveEvent(pos)
        else:
          newMouseButtonEvent(pos, buttonCode, buttonState)
    evt.window = w
    result = a.handleEvent(evt).int32

proc onKey(keyCode, repeat, buttonState: int32): int32 =
  let a = mainApplication()
  let w = a.keyWindow
  if not w.isNil:
    let buttonState = case buttonState
                      of 1: bsDown
                      else: bsUp
    var e = newKeyboardEvent(virtualKeyFromNative(keyCode), buttonState, bool(repeat))
    e.window = w
    result = a.handleEvent(e).int32

proc initWithCanvasId*(w: WebWindow, canvasId: string) =
  w.canvasId = canvasId
  let width = getDocumentElementFloatProp(canvasId, "clientWidth")
  let height = getDocumentElementFloatProp(canvasId, "clientHeight")
  procCall w.Window.init()
  w.onResize(newSize(width, height))

  w.renderingContext = newGraphicsContext()

  # w.setupEventHandlersForCanvas(canvas)

  w.enableAnimation(true)
  mainApplication().addWindow(w)
  requestAnimFrame(animFrame)

  defineDyncall("iddiidd")
  setupMouseEventHandlers(canvasId, onMouse)

  defineDyncall("iiii")
  setupKeyEventHandlers(onKey)

proc nextCanvasId(): string =
  var counter {.global.} = 0
  inc counter
  "__nimx_canvas" & $counter

proc initByFillingBrowserWindow*(w: WebWindow) =
  # This is glitchy sometimes
  let id = nextCanvasId()
  createCanvas(id, -1, -1)
  w.initWithCanvasId(id)

# proc newWebWindow*(canvasId: string): WebWindow =
#   result.new()
#   result.initWithCanvasId(canvasId)

proc newWebWindow*(r: Rect): Window =
  WebWindow.new()

proc newWebWindowByFillingBrowserWindow*(): Window =
  var res: WebWindow
  res.new()
  res.initByFillingBrowserWindow()
  res

newWindow = newWebWindow
newFullscreenWindow = newWebWindowByFillingBrowserWindow

proc listenPixelRatioChange(cb: proc() {.nimcall.}) {.importwasmraw: """
  matchMedia(
    `(resolution: ${window.devicePixelRatio}dppx)`
  ).addEventListener("change", () => _nime._dv($0), { once: true })
""".}

proc getPixelRatio(): float {.importwasmexpr: "window.devicePixelRatio || 1".}

proc updateCanvasPixelRatio(r: float, canvasId: cstring) {.importwasmraw: """
  var c = document.getElementById(_nimsj($1));
  c.width = c.clientWidth * $0;
  c.height = c.clientHeight * $0
""".}

proc onPixelRatioChange() =
  let a = mainApplication()
  let w = a.keyWindow
  if not w.isNil:
    w.onResize(w.frame.size)

  defineDyncall("v")
  listenPixelRatioChange(onPixelRatioChange)

method init*(w: WebWindow) =
  let id = nextCanvasId()
  createCanvas(id, 800, 600)
  # init(cast[pointer](w), w.canvasId, $r.width, $r.height)
  w.initWithCanvasId(id)
  onPixelRatioChange()

method drawWindow*(w: WebWindow) =
  let c = w.renderingContext
  let oldContext = setCurrentContext(c)
  c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
    procCall w.Window.drawWindow()
  setCurrentContext(oldContext)

method onResize*(w: WebWindow, newSize: Size) =
  w.renderingContext.gl.viewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
  procCall w.Window.onResize(newSize)

  let p = getPixelRatio()
  w.viewportPixelRatio = p
  updateCanvasPixelRatio(p, WebWindow(w).canvasId)
  let vp = w.frame.size * p
  sharedGL().viewport(0, 0, GLSizei(vp.width), GLsizei(vp.height))

proc startTextInputAux(cb: proc(a: JSRef) {.cdecl.}) {.importwasmraw: """
  if (window.__nimx_textinput === undefined) {
    var i = window.__nimx_textinput = document.createElement('input');
    i.type = 'text';
    i.style.position = 'absolute';
    i.style.top = '-99999px';
    document.body.appendChild(i)
  }
  window.__nimx_textinput.oninput = () => {
    _nime._dvi($0, _nimok(window.__nimx_textinput.value));
    window.__nimx_textinput.value = ""
  };
  setTimeout(() => window.__nimx_textinput.focus(), 1)
""".}

proc length(j: JSObj): int {.importwasmp.}
proc strWriteOut(j: JSObj, p: pointer, len: int): int {.importwasmf: "_nimws".}

proc jsStringToStr(v: JSObj): string =
  if not v.isNil:
    let sz = length(v) * 3
    result.setLen(sz)
    if sz != 0:
      let actualSz = strWriteOut(v, addr result[0], sz)
      result.setLen(actualSz)

proc onInput(a: JSRef) {.cdecl.} =
  var e = newEvent(etTextInput)
  e.text = block:
    # Force JSRef destruction early
    jsStringToStr(JSObj(o: a))

  let a = mainApplication()
  e.window = a.keyWindow
  if not e.window.isNil:
    discard a.handleEvent(e)

method startTextInput*(w: WebWindow, r: Rect) =
  defineDyncall("vi")
  startTextInputAux(onInput)

proc stopTextInputAux() {.importwasmraw: """
  if (window.__nimx_textinput !== undefined) {
    window.__nimx_textinput.oninput = null;
    window.__nimx_textinput.blur()
  }
""".}

method stopTextInput*(w: WebWindow) =
  stopTextInputAux()

# window.onload = () => _nime._dv(p)
# TODO: the main code should be called upon window.onload, but it doesn't
# get called for some reason. So we're just calling it immediately now.
# proc initMain(p: proc() {.nimcall.}) {.importwasmraw: """
# _nime._dv($0)
# """.}

template runApplication*(code: typed) =
  proc main() =
    code
  main()
  # defineDyncall("v")
  # initMain(main)
