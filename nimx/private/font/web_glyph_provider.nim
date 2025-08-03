# import dom

# import jsbind
import wasmrt
import nimx/private/font/font_data
import rect_packer

type WebGlyphProvider* = ref object
  face: string
  size: float32
  glyphMargin*: int32

proc setFace*(p: WebGlyphProvider, face: string) =
  p.face = face

template setSize*(p: WebGlyphProvider, sz: float32) =
  p.size = sz

proc cssFontName(p: WebGlyphProvider): string =
  $int(p.size) & "px " & p.face

template clearCache*(p: WebGlyphProvider) = discard

proc calculateFontMetricsInCanvas(n: cstring, fontSize: int, o: pointer) {.importwasmraw: """
  var c = document.createElement("canvas"),
    C = c.getContext("2d");
  C.font = _nimsj($0);
  var m = C.measureText("Hl@¿Éq¶");
  _nimwf([m.actualBoundingBoxAscent, m.fontBoundingBoxDescent], $2)
  """.}

proc getFontMetrics*(p: WebGlyphProvider, oAscent, oDescent: var float32) =
  var o: array[2, float32]
  calculateFontMetricsInCanvas(p.cssFontName, int32(p.size), addr o)
  oAscent = o[0]
  oDescent = -o[1]

proc createAuxCanvas(n: cstring) {.importwasmraw: """
  var fName = _nimsj($0);
  var r = document.createElement("canvas");
  var ctx = r.getContext('2d');
  r.style.font = fName;
  ctx.font = fName;
  r.__nimx_ctx = ctx;
  window.__nimx_font_aux_canvas = r;
  """.}

proc measureChar(c: int32): int32 {.importwasmraw: """
  return window.__nimx_font_aux_canvas.__nimx_ctx.measureText(String.fromCharCode($0)).width
  """.}

proc configureAuxCanvas(w, h: int32, f: cstring) {.importwasmraw: """
  var c = window.__nimx_font_aux_canvas, x = c.__nimx_ctx;
  c.width = $0;
  c.height = $1;
  x.textBaseline = "top";
  x.font = _nimsj($2)
  """.}

proc fillText(c, x, y: int32) {.importwasmraw: """
  window.__nimx_font_aux_canvas.__nimx_ctx.fillText(String.fromCharCode($0), $1, $2)
  """.}

proc getImageDataAndDeleteCanvas(w, h: int32, o: pointer) {.importwasmraw: """
  var sz = $0 * $1,
    d = window.__nimx_font_aux_canvas.__nimx_ctx.getImageData(0, 0, $0, $1).data,
    o = new Int8Array(_nima, $2, sz);
  for (var i = 3, j = 0; j < sz; i += 4, ++j) o[j] = d[i];
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
