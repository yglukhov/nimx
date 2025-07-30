
when defined(js) or defined(emscripten) or defined(wasm):
  discard
else:
  {.error: "This module can be used only for web target".}

# import dom except Window
# import jsbind
import wasmrt

import nimx/[ abstract_window, system_logger, view, context, matrixes, app,
      portable_gl, event ]
import nimx/private/js_vk_map

type WebWindow* = ref object of Window
  renderingContext: GraphicsContext
  # canvas: Element
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
  # let c = w.canvas

  if not isFullscreen and v:
    requestFullscreen(w.canvasId)
  elif isFullscreen and not v:
    exitFullscreen()

export abstract_window

# template buttonStateFromKeyEvent(evt: dom.Event): ButtonState =
#   if evt.`type` == "keyup": bsUp
#   elif evt.`type` == "keydown": bsDown
#   else: bsUnknown

# proc setupWebGL() =
#   {.emit: """
#     window.requestAnimFrame = (function() {
#       return window.requestAnimationFrame ||
#         window.webkitRequestAnimationFrame ||
#         window.mozRequestAnimationFrame ||
#         window.oRequestAnimationFrame ||
#         window.msRequestAnimationFrame ||
#         function(callback, element) {
#         window.setTimeout(callback, 1000/60);
#     };
#   })();

#   window.__nimx_focused_canvas = null;

#   document.addEventListener('mousedown', function(event) {
#     window.__nimx_focused_canvas = event.target;
#   }, false);

#   window.__nimx_keys_down = {};
#   """.}

#   proc onkey(evt: dom.Event) =
#     when declared(KeyboardEvent):
#       let evt = cast[KeyboardEvent](evt)
#     var wnd : WebWindow
#     var repeat = false
#     let bs = buttonStateFromKeyEvent(evt)
#     if bs == bsDown:
#       {.emit: """
#       `repeat` = `evt`.keyCode in window.__nimx_keys_down;
#       window.__nimx_keys_down[`evt`.keyCode] = true;
#       """.}
#     elif bs == bsUp:
#       {.emit: """
#       delete window.__nimx_keys_down[`evt`.keyCode];
#       """.}

#     {.emit: """
#     if (window.__nimx_focused_canvas !== null && window.__nimx_focused_canvas.__nimx_window !== undefined) {
#       `wnd` = window.__nimx_focused_canvas.__nimx_window;
#     }
#     """.}
#     if not wnd.isNil:
#       # TODO: Complete this!
#       var e = newKeyboardEvent(virtualKeyFromNative(evt.keyCode), bs, repeat)

#       #result.rune = keyEv.keysym.unicode.Rune
#       e.window = wnd
#       discard mainApplication().handleEvent(e)

#   document.addEventListener("keydown", onkey, false)
#   document.addEventListener("keyup", onkey, false)


# setupWebGL()

# proc buttonCodeFromJSEvent(e: dom.Event): VirtualKey =
#   when declared(MouseEvent):
#     let e = cast[MouseEvent](e)
#   case e.button:
#     of 1: VirtualKey.MouseButtonPrimary
#     of 2: VirtualKey.MouseButtonSecondary
#     of 3: VirtualKey.MouseButtonMiddle
#     else: VirtualKey.Unknown

# proc eventLocationFromJSEvent(e: dom.Event, c: Element): Point =
#   var offx, offy: Coord
#   {.emit: """
#   var r = `c`.getBoundingClientRect();
#   `offx` = r.left;
#   `offy` = r.top;
#   """.}
#   when declared(MouseEvent):
#     let e = cast[MouseEvent](e)
#   result.x = e.clientX.Coord - offx
#   result.y = e.clientY.Coord - offy

# proc setupEventHandlersForCanvas(w: WebWindow, c: Element) =
#   let onmousedown = proc (e: dom.Event) =
#     var evt = newMouseDownEvent(eventLocationFromJSEvent(e, c), buttonCodeFromJSEvent(e))
#     evt.window = w
#     discard mainApplication().handleEvent(evt)

#   let onmouseup = proc (e: dom.Event) =
#     var evt = newMouseUpEvent(eventLocationFromJSEvent(e, c), buttonCodeFromJSEvent(e))
#     evt.window = w
#     discard mainApplication().handleEvent(evt)

#   let onmousemove = proc (e: dom.Event) =
#     var evt = newMouseMoveEvent(eventLocationFromJSEvent(e, c))
#     evt.window = w
#     discard mainApplication().handleEvent(evt)

#   let onscroll = proc (e: dom.Event): bool =
#     var evt = newEvent(etScroll, eventLocationFromJSEvent(e, c))
#     var x, y: Coord
#     {.emit: """
#     `x` = `e`.deltaX;
#     `y` = `e`.deltaY;
#     """.}
#     evt.offset.x = x
#     evt.offset.y = y
#     evt.window = w
#     result = not mainApplication().handleEvent(evt)

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

#   # TODO: Remove this hack, when handlers definition in dom.nim fixed.
#   {.emit: """
#   document.addEventListener('mousedown', `onmousedown`)
#   document.addEventListener('mouseup', `onmouseup`)
#   document.addEventListener('mousemove', `onmousemove`)
#   document.addEventListener('wheel', `onscroll`)

#   window.onresize = `onresize`;
#   window.onfocus = `onfocus`;
#   window.onblur = `onblur`;
#   """.}

proc setupEventHandlers(
  c: cstring,
  m: proc(x, y: cdouble, buttonState, buttonCode: int32) {.nimcall.}
     ) {.importwasmraw: """
  var d = document, c = d.getElementById(_nimsj($0)),
  om = (s, e) => {
    var r = c.getBoundingClientRect();
    _nime._dvddii($1, e.clientX - r.left, e.clientY - r.top, s, e.button)
  };
  d.addEventListener('mousemove', e => om(0, e));
  d.addEventListener('mousedown', e => om(1, e));
  d.addEventListener('mouseup', e => om(2, e));
  """.}

proc requestAnimFrame(p: proc() {.nimcall}) {.importwasmraw: """
requestAnimationFrame(function(){try{_nime._dv($0)}catch(e) {console.log("Erro caught", e);_nime.nimerr(); throw e;}})
""".}

proc animFrame() =
  mainApplication().runAnimations()
  mainApplication().drawWindows()
  requestAnimFrame(animFrame)

proc getDocumentElementFloatProp(i, p: cstring): cdouble {.importwasmraw: "return document.getElementById(_nimsj($0))[_nimsj($1)]".}
proc createCanvas(i: cstring, x, y: cfloat) {.importwasmraw: """
var d = document, w = window, I = _nimsj($0), e = d.getElementById(I), pixelRatio = w.devicePixelRatio || 1, x = $1, y = $2;
if (!e) {
  e = d.createElement("canvas");
  e.id = I;
  d.body.appendChild(e)
}
e.style.width = x + 'px';
e.style.height = y + 'px';
// var r = e.getBoundingClientRect();
e.width = x * pixelRatio;
e.height = y * pixelRatio;
e.scaled = true;

if (!w.GLCtx) {
  var o = {stencil: true, alpha: false, premultipliedAlpha: false, antialias: false}, c = null;
  try {
    c = e.getContext('webgl', o)
  } catch(err) {}
  if (!c)
    try {
      c  = e.getContext('experimental-webgl', o)
    } catch(err) {}

  if (c) {
    var devicePixelRatio = window.devicePixelRatio || 1;
    c.viewportWidth = x * devicePixelRatio;
    c.viewportHeight = y * devicePixelRatio;
    c.getExtension('OES_standard_derivatives');
    c.pixelStorei(c.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    w.GLCtx = c
  } else
    alert("Your browser does not support WebGL. Please, use a modern browser.")
}
""".}

# proc adjustCanvasPixelRatio(i: cstring)

proc onMouse(x, y: cdouble, buttonState, buttonCode: int32) =
  let a = mainApplication()
  let w = a.keyWindow
  if not w.isNil:
    let buttonState = case buttonState
                      of 1: bsDown
                      of 2: bsUp
                      else: bsUnknown
    let buttonCode = case buttonCode
                     of 1: VirtualKey.MouseButtonPrimary
                     of 2: VirtualKey.MouseButtonSecondary
                     of 3: VirtualKey.MouseButtonMiddle
                     else: VirtualKey.Unknown
    var pos = newPoint(x, y)
    var evt = if buttonState == bsUnknown:
        newMouseMoveEvent(pos)
      else:
        newMouseButtonEvent(pos, buttonCode, buttonState)
    evt.window = w
    discard mainApplication().handleEvent(evt)

proc initWithCanvasId*(w: WebWindow, canvasId: string) =
  w.canvasId = canvasId
  let width = getDocumentElementFloatProp(canvasId, "width")
  let height = getDocumentElementFloatProp(canvasId, "height")
  procCall w.Window.init()
  w.onResize(newSize(width, height))

  w.renderingContext = newGraphicsContext()

  # w.setupEventHandlersForCanvas(canvas)

  w.enableAnimation(true)
  mainApplication().addWindow(w)
  requestAnimFrame(animFrame)

  defineDyncall("vddii")
  setupEventHandlers(canvasId, onMouse)

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
  echo "new web window"
  WebWindow.new()

proc newWebWindowByFillingBrowserWindow*(): Window =
  var res: WebWindow
  res.new()
  res.initByFillingBrowserWindow()
  res

newWindow = newWebWindow
newFullscreenWindow = newWebWindowByFillingBrowserWindow

method init*(w: WebWindow) =
  let id = nextCanvasId()
  createCanvas(id, 800, 600)
  # init(cast[pointer](w), w.canvasId, $r.width, $r.height)
  w.initWithCanvasId(id)

method drawWindow*(w: WebWindow) =
  let c = w.renderingContext
  let oldContext = setCurrentContext(c)
  c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
    procCall w.Window.drawWindow()
  setCurrentContext(oldContext)

method onResize*(w: WebWindow, newSize: Size) =
  w.renderingContext.gl.viewport(0, 0, GLSizei(newSize.width), GLsizei(newSize.height))
  procCall w.Window.onResize(newSize)

# proc sendInputEvent(wnd: WebWindow, evt: dom.Event) =
#   var s: cstring
#   {.emit: """
#   `s` = window.__nimx_textinput.value;
#   window.__nimx_textinput.value = "";
#   """.}
#   var e = newEvent(etTextInput)
#   e.window = wnd
#   e.text = $s
#   discard mainApplication().handleEvent(e)

# method startTextInput*(wnd: WebWindow, r: Rect) =
#   let oninput = proc(evt: dom.Event) =
#     wnd.sendInputEvent(evt)

#   {.emit: """
#   if (window.__nimx_textinput === undefined) {
#     var i = window.__nimx_textinput = document.createElement('input');
#     i.type = 'text';
#     i.style.position = 'absolute';
#     i.style.top = '-99999px';
#     document.body.appendChild(i);
#   }
#   window.__nimx_textinput.oninput = `oninput`;
#   setTimeout(function(){ window.__nimx_textinput.focus(); }, 1);
#   """.}

# method stopTextInput*(w: WebWindow) =
#   {.emit: """
#   if (window.__nimx_textinput !== undefined) {
#     window.__nimx_textinput.oninput = null;
#     window.__nimx_textinput.blur();
#   }
#   """.}

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
