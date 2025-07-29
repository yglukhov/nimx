
const charChunkLength* = 200

type GlyphMetricsComponent* = enum
  compX = 0
  compY
  compAdvance
  compTexX
  compTexY
  compWidth
  compHeight

const numberOfComponents = ord(high(GlyphMetricsComponent)) + 1
type GlyphMetrics* = array[numberOfComponents * charChunkLength, int16]

template charOff*(i: int): int = i * numberOfComponents
template charOffComp*(bc: var GlyphMetrics, charOffset: int, comp: GlyphMetricsComponent): var int16 =
  bc[charOffset + ord(comp)]

type GlyphData* = object
  glyphMetrics*: GlyphMetrics
  bitmap*: seq[byte]
  dfDoneForGlyph*: seq[bool]
  bitmapWidth*, bitmapHeight*: uint16

template isPrintableCodePoint*(c: int): bool = not (i <= 0x1f or i == 0x7f or (i >= 0x80 and i <= 0x9F))
