import strutils, streams, logging
import nimx/private/font/font_data
import nimx/assets/url_stream
import rect_packer
import ttf

type StbTtfGlyphProvider* = ref object
  path: string
  size: float32 # "Real" glyph size. Usually bigger than font size.
  fontData: string
  fontInfo: stbtt_fontinfo
  glyphMargin*: int32

proc setPath*(p: StbTtfGlyphProvider, path: string) =
  p.path = path

template setSize*(p: StbTtfGlyphProvider, sz: float32) =
  p.size = sz

proc loadFontData(p: StbTtfGlyphProvider) =
  if p.fontData.len != 0: return
  if p.path.startsWith("res://"):
    var s: Stream
    openStreamForUrl(p.path) do(st: Stream, err: string):
      s = st
    if s.isNil:
      error "Could not load font from path: ", p.path
    p.fontData = s.readAll()
    s.close()
  else:
    p.fontData = readFile(p.path)

  if stbtt_InitFont(p.fontInfo, cast[ptr font_type](p.fontData.cstring), 0) == 0:
    warn "Could not init font"
    raise newException(Exception, "Could not init font")

proc clearCache*(p: StbTtfGlyphProvider) =
  p.fontData = ""

proc getFontMetrics*(p: StbTtfGlyphProvider, oAscent, oDescent: var float32) =
  p.loadFontData()
  let scale = stbtt_ScaleForMappingEmToPixels(p.fontInfo, p.size)
  var ascent, descent, lineGap : cint
  stbtt_GetFontVMetrics(p.fontInfo, ascent, descent, lineGap)
  oAscent = float32(ascent) * scale
  oDescent = float32(descent) * scale
  p.clearCache()

proc bakeChars*(p: StbTtfGlyphProvider, start: int32, data: var GlyphData) =
  let startChar = start * charChunkLength
  let endChar = startChar + charChunkLength

  var rectPacker = newPacker(32, 32)

  p.loadFontData()

  let scale = stbtt_ScaleForMappingEmToPixels(p.fontInfo, p.size)
  var ascent, descent, lineGap : cint
  stbtt_GetFontVMetrics(p.fontInfo, ascent, descent, lineGap)

  # f.impl.ascent = float32(ascent) * scale
  # f.impl.descent = float32(descent) * scale

  var glyphIndexes: array[charChunkLength, cint]

  for i in startChar ..< endChar:
    if isPrintableCodePoint(i):
      let g = stbtt_FindGlyphIndex(p.fontInfo, i) # g > 0 when found
      glyphIndexes[i - startChar] = g
      var advance, lsb, x0, y0, x1, y1: cint
      stbtt_GetGlyphHMetrics(p.fontInfo, g, advance, lsb)
      stbtt_GetGlyphBitmapBox(p.fontInfo, g, scale, scale, x0, y0, x1, y1)
      let gw = x1 - x0
      let gh = y1 - y0
      let (x, y) = rectPacker.packAndGrow(gw + p.glyphMargin * 2, gh + p.glyphMargin * 2)

      let c = charOff(i - startChar)
      data.glyphMetrics.charOffComp(c, compX) = (x0.cfloat).int16
      data.glyphMetrics.charOffComp(c, compY) = (y0.cfloat + ascent.cfloat * scale).int16
      data.glyphMetrics.charOffComp(c, compAdvance) = (scale * advance.cfloat).int16
      data.glyphMetrics.charOffComp(c, compTexX) = (x + p.glyphMargin).int16
      data.glyphMetrics.charOffComp(c, compTexY) = (y + p.glyphMargin).int16
      data.glyphMetrics.charOffComp(c, compWidth) = (gw).int16
      data.glyphMetrics.charOffComp(c, compHeight) = (gh).int16

  let width = rectPacker.width
  let height = rectPacker.height
  data.bitmapWidth = width.uint16
  data.bitmapHeight = height.uint16
  var temp_bitmap = newSeq[byte](width * height)

  for i in startChar ..< endChar:
    let indexOfGlyphInRange = i - startChar
    data.dfDoneForGlyph[indexOfGlyphInRange] = true
    if isPrintableCodePoint(i):
      let c = charOff(indexOfGlyphInRange)
      if data.glyphMetrics.charOffComp(c, compAdvance) > 0:
        let x = data.glyphMetrics.charOffComp(c, compTexX).int
        let y = data.glyphMetrics.charOffComp(c, compTexY).int
        let w = data.glyphMetrics.charOffComp(c, compWidth).cint
        let h = data.glyphMetrics.charOffComp(c, compHeight).cint
        if w > 0 and h > 0:
          stbtt_MakeGlyphBitmap(p.fontInfo, addr temp_bitmap[x + y * width.int], w, h, width.cint, scale, scale, glyphIndexes[indexOfGlyphInRange])
          data.dfDoneForGlyph[indexOfGlyphInRange] = false

  p.clearCache()
  when defined(gcDestructors):
    data.bitmap = move(temp_bitmap)
  else:
    shallowCopy(data.bitmap, temp_bitmap)
