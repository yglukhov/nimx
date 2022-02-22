# import dom

import jsbind
import wasmrt
import nimx/private/font/font_data
import rect_packer

type WebGlyphProvider* = ref object
    face: string
    size: float32
    glyphMargin*: int32

type Element = JSObj

proc setFace*(p: WebGlyphProvider, face: string) =
    p.face = face

template setSize*(p: WebGlyphProvider, sz: float32) =
    p.size = sz

proc cssFontName(p: WebGlyphProvider): string =
  $int(p.size) & "px " & p.face

template clearCache*(p: WebGlyphProvider) = discard

proc calculateFontMetricsInCanvas(n: cstring, fontSize: int, o: pointer) {.importwasm: """
  // Idea borrowed from from https://github.com/Pomax/fontmetrics.js
  var textstring = "Hl@¿Éq¶", n = _nimsj(n);
  var canvas = document.createElement("canvas");
  var ctx = canvas.getContext("2d");
  ctx.font = n;
  var m = ctx.measureText(textstring);

  var padding = 100;
  canvas.width = m.width + padding;
  canvas.height = 3*fontSize;
  canvas.style.opacity = 1;
  ctx.font = n;
  var w = canvas.width,
    h = canvas.height,
    baseline = h/2;

  // Set all canvas pixeldata values to 255, with all the content
  // data being 0. This lets us scan for data[i] != 255.
  ctx.fillStyle = "white";
  ctx.fillRect(-1, -1, w+2, h+2);
  ctx.fillStyle = "black";
  ctx.fillText(textstring, padding/2, baseline);
  var pixelData = ctx.getImageData(0, 0, w, h).data;

  // canvas pixel data is w*4 by h*4, because R, G, B and A are separate,
  // consecutive values in the array, rather than stored as 32 bit ints.
  var i = 0,
    w4 = w * 4,
    len = pixelData.length;

  // Finding the ascent uses a normal, forward scanline
  while (++i < len && pixelData[i] === 255) {}
  var ascent = (i/w4)|0;

  // Finding the descent uses a reverse scanline
  i = len - 1;
  while (--i > 0 && pixelData[i] === 255) {}
  var descent = (i/w4)|0;

  _nimwf([baseline - ascent, descent - baseline], o);
  """.}

proc getFontMetrics*(p: WebGlyphProvider, oAscent, oDescent: var float32) =
  var o: array[2, float32]
  calculateFontMetricsInCanvas(p.cssFontName, int32(p.size), addr o)
  oAscent = o[0]
  oDescent = -o[1]

proc createAuxCanvas(n: cstring) {.importwasm: """
  var fName = _nimsj(n);
  var r = document.createElement("canvas");
  var ctx = r.getContext('2d');
  r.style.font = fName;
  ctx.font = fName;
  r.__nimx_ctx = ctx;
  window.__nimx_font_aux_canvas = r;
  """.}

proc measureChar(c: int32): int32 {.importwasm: """
  return window.__nimx_font_aux_canvas.__nimx_ctx.measureText(String.fromCharCode(c)).width
  """.}

proc configureAuxCanvas(w, h: int32, f: cstring) {.importwasm: """
  var c = window.__nimx_font_aux_canvas, x = c.__nimx_ctx;
  c.width = w;
  c.height = h;
  x.textBaseline = "top";
  x.font = _nimsj(f)
  """.}

proc fillText(c, x, y: int32) {.importwasm: """
  window.__nimx_font_aux_canvas.__nimx_ctx.fillText(String.fromCharCode(c), x, y)
  """.}

proc getImageDataAndDeleteCanvas(w, h: int32, o: pointer) {.importwasm: """
  var sz = w * h,
    imgData = window.__nimx_font_aux_canvas.__nimx_ctx.getImageData(0, 0, w, h).data,
    byteData = new Int8Array(_nima.buffer, o, sz);
  for (var i = 3, j = 0; j < sz; i += 4, ++j) byteData[j] = imgData[i];
  delete window.__nimx_font_aux_canvas;
  """.}

proc bakeChars*(p: WebGlyphProvider, start: int32, data: var GlyphData) =
  let startChar = start * charChunkLength
  let endChar = startChar + charChunkLength

  var rectPacker = newPacker(32, 32)

  var ascent, descent: float32
  p.getFontMetrics(ascent, descent)

  let h = int32(ascent - descent)

  let fName = p.cssFontName
  createAuxCanvas(fName)

  for i in startChar ..< endChar:
    if isPrintableCodePoint(i):
      let w = measureChar(i)

      if w > 0:
        let (x, y) = rectPacker.packAndGrow(w + p.glyphMargin * 2, h + p.glyphMargin * 2)

        let c = charOff(i - startChar)
        #data.glyphMetrics.charOffComp(c, compX) = 0
        #data.glyphMetrics.charOffComp(c, compY) = 0
        data.glyphMetrics.charOffComp(c, compAdvance) = w.int16
        data.glyphMetrics.charOffComp(c, compTexX) = (x + p.glyphMargin).int16
        data.glyphMetrics.charOffComp(c, compTexY) = (y + p.glyphMargin).int16
        data.glyphMetrics.charOffComp(c, compWidth) = w.int16
        data.glyphMetrics.charOffComp(c, compHeight) = h.int16

  let texWidth = rectPacker.width
  let texHeight = rectPacker.height
  data.bitmapWidth = texWidth.uint16
  data.bitmapHeight = texHeight.uint16

  configureAuxCanvas(texWidth, texHeight, fname)

  for i in startChar ..< endChar:
    let indexOfGlyphInRange = i - startChar
    data.dfDoneForGlyph[indexOfGlyphInRange] = true
    if isPrintableCodePoint(i) and i != ord(' '):
      let c = charOff(indexOfGlyphInRange)
      let w = data.glyphMetrics.charOffComp(c, compAdvance)
      if w > 0:
        let x = data.glyphMetrics.charOffComp(c, compTexX)
        let y = data.glyphMetrics.charOffComp(c, compTexY)
        fillText(i, x, y)
        data.dfDoneForGlyph[indexOfGlyphInRange] = false

  data.bitmap.setLen(texWidth * texHeight)

  getImageDataAndDeleteCanvas(texWidth, texHeight, addr data.bitmap[0])
