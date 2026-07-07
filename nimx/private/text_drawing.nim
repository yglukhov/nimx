import unicode
import ../[font, context, types]

var textSubpixelDrawing = true
proc enableTextSubpixelDrawing*(state: bool) =
  textSubpixelDrawing = state

proc drawTextBase*(c: GraphicsContext, font: Font, pt: var Point, text: openarray[char]) =
  var texture: TextureRef
  var quad: array[16, Coord]
  for ch in text.runes:
    font.getQuadDataForRune(ch, quad, texture, pt)
    if not texture.isEmpty:
      var col = c.fillColor
      col.a *= c.alpha
      c.drawTextureQuad(texture, quad, col, true)
    pt.x += font.horizontalSpacing

proc drawText*(c: GraphicsContext, font: Font, pt: var Point, text: openarray[char]) =
  c.drawTextBase(font, pt, text)

proc drawText*(c: GraphicsContext, font: Font, pt: Point, text: openarray[char]) {.gcsafe.} =
  var p = pt
  c.drawText(font, p, text)
