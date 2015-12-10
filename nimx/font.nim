import types
import system_logger
import unicode
import tables
import rect_packer

when defined js:
    import dom
else:
    import ttf
    import os

# Quick and dirty interface for fonts.
# TODO:
#  - Remove dependency on OpenGL.
#  - Distance field textures

import opengl
import portable_gl

const charChunkLength = 96

type BackedCharComponent = enum
    compX = 0
    compY
    compAdvance
    compTexX
    compTexY
    compWidth
    compHeight

const numberOfComponents = ord(high(BackedCharComponent)) + 1
type BakedCharInfo = array[numberOfComponents * charChunkLength, int16]

template charOff(i: int): int = i * numberOfComponents
template charOffComp(bc: var BakedCharInfo, charOffset: int, comp: BackedCharComponent): var int16 =
    bc[charOffset + ord(comp)]

type CharInfo = ref object
    bakedChars: BakedCharInfo
    texture: GLuint
    texWidth, texHeight: uint16

type Font* = ref object
    when defined js:
        chars: ref RootObj
    else:
        chars: Table[int32, CharInfo]
    size*: float
    isHorizontal*: bool
    filePath: string
    horizontalSpacing*: Coord
    when defined js:
        canvas: Element

proc prepareTexture(i: var CharInfo): GL =
    result = sharedGL()
    i.texture = result.createTexture()
    result.bindTexture(result.TEXTURE_2D, i.texture)
    result.texParameteri(result.TEXTURE_2D, result.TEXTURE_MIN_FILTER, result.LINEAR)

proc bakeChars(f: Font, start: int32): CharInfo =
    result.new()

    let startChar = start * charChunkLength
    let endChar = startChar + charChunkLength

    var rectPacker = newPacker(32, 32)
    when defined js:
        let fontName : cstring = $f.size & "px " & f.filePath
        let canvas = document.createElement("canvas").Element
        asm """
        var ctx = `canvas`.getContext('2d');
        ctx.font = `fontName`;
        ctx.textBaseline = "top";
        """
        f.canvas = canvas

        for i in startChar .. < endChar:
            var w: int32
            let h = f.size.int32 + 2
            asm """
            var mt = ctx.measureText(String.fromCharCode(`i`));
            `w` = mt.width;
            """

            if w > 0:
                let (x, y) = rectPacker.packAndGrow(w, h)

                let c = charOff(i - startChar)
                #result.bakedChars.charOffComp(c, compX) = 0
                #result.bakedChars.charOffComp(c, compY) = 0
                result.bakedChars.charOffComp(c, compAdvance) = w.int16
                result.bakedChars.charOffComp(c, compTexX) = x.int16
                result.bakedChars.charOffComp(c, compTexY) = y.int16
                result.bakedChars.charOffComp(c, compWidth) = w.int16
                result.bakedChars.charOffComp(c, compHeight) = h.int16

        let texWidth = rectPacker.width
        let texHeight = rectPacker.height
        result.texWidth = texWidth.uint16
        result.texHeight = texHeight.uint16

        asm """
        `canvas`.width = `texWidth`;
        `canvas`.height = `texHeight`;
        ctx.font = `fontName`;
        ctx.textBaseline = "top";
        """

        for i in startChar .. < endChar:
            let c = charOff(i - startChar)
            if result.bakedChars.charOffComp(c, compAdvance) > 0:
                let x = result.bakedChars.charOffComp(c, compTexX)
                let y = result.bakedChars.charOffComp(c, compTexY)
                asm "ctx.fillText(String.fromCharCode(`i`), `x`, `y`);"

        let gl = result.prepareTexture()
        asm """
        `gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.ALPHA, `gl`.ALPHA, `gl`.UNSIGNED_BYTE, `canvas`);
        """
    else:
        var rawData = readFile(f.filePath)

        var fontinfo: stbtt_fontinfo
        if stbtt_InitFont(fontinfo, cast[font_type](rawData.cstring), 0) == 0:
            logi "Could not init font"
            return nil

        let scale = stbtt_ScaleForPixelHeight(fontinfo, f.size)
        var ascent, descent, lineGap : cint
        stbtt_GetFontVMetrics(fontinfo, ascent, descent, lineGap)
        ascent = cint(ascent.cfloat * scale)
        descent = cint(descent.cfloat * scale)
        lineGap = cint(lineGap.cfloat * scale)

        var glyphIndexes: array[charChunkLength, cint]

        for i in startChar .. < endChar:
            let g = stbtt_FindGlyphIndex(fontinfo, i) # g > 0 when found
            glyphIndexes[i - startChar] = g
            var advance, lsb, x0,y0,x1,y1: cint
            stbtt_GetGlyphHMetrics(fontinfo, g, advance, lsb)
            stbtt_GetGlyphBitmapBox(fontinfo, g, scale, -scale, x0, y0, x1, y1)
            let gw = x1 - x0
            let gh = y0 - y1 + 2 # Why is this +2 needed????
            let (x, y) = rectPacker.packAndGrow(gw, gh + 1)

            let c = charOff(i - startChar)
            result.bakedChars.charOffComp(c, compX) = x0.int16
            result.bakedChars.charOffComp(c, compY) = (ascent - y0).int16
            result.bakedChars.charOffComp(c, compAdvance) = (scale * advance.cfloat).int16
            result.bakedChars.charOffComp(c, compTexX) = x.int16
            result.bakedChars.charOffComp(c, compTexY) = y.int16
            result.bakedChars.charOffComp(c, compWidth) = gw.int16
            result.bakedChars.charOffComp(c, compHeight) = gh.int16

        let width = rectPacker.width
        let height = rectPacker.height
        result.texWidth = width.uint16
        result.texHeight = height.uint16
        var temp_bitmap = newSeq[byte](width * height)

        for i in startChar .. < endChar:
            let c = charOff(i - startChar)
            if result.bakedChars.charOffComp(c, compAdvance) > 0:
                let x = result.bakedChars.charOffComp(c, compTexX).int
                let y = result.bakedChars.charOffComp(c, compTexY).int
                let w = result.bakedChars.charOffComp(c, compWidth).cint
                let h = result.bakedChars.charOffComp(c, compHeight).cint
                stbtt_MakeGlyphBitmap(fontinfo, addr temp_bitmap[x + y * width.int], w, h, width.cint, scale, scale, glyphIndexes[i - startChar])

        let gl = result.prepareTexture()
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.ALPHA, width, height, 0, gl.ALPHA, gl.UNSIGNED_BYTE, addr temp_bitmap[0])

when not defined js:
    proc newFontWithFile*(pathToTTFile: string, size: float): Font =
        result.new()
        result.isHorizontal = true # TODO: Support vertical fonts
        result.filePath = pathToTTFile
        result.size = size
        result.chars = initTable[int32, CharInfo]()

var sysFont : Font

const preferredFonts = when defined(macosx) or defined(js) or defined(windows):
        [
            "Arial"
        ]
    elif defined(android):
        [
            "DroidSans"
        ]
    else:
        [
            "Ubuntu-R",
            "DejaVuSans"
        ]

const fontSearchPaths = when defined(macosx):
        [
            "/Library/Fonts"
        ]
    elif defined(android):
        [
            "/system/fonts"
        ]
    elif defined(windows):
        [
            r"c:\Windows\Fonts" #todo: system will not always in the c disk
        ]
    else:
        [
            "/usr/share/fonts/truetype/ubuntu-font-family",
            "/usr/share/fonts/TTF",
            "/usr/share/fonts/truetype/dejavu"
        ]

when not defined js:
    proc findFontFileForFace(face: string): string =
        for sp in fontSearchPaths:
            let f = sp / face & ".ttf"
            if fileExists(f):
                return f
            logi "Tried font '", f, "' with no luck"

proc newFontWithFace*(face: string, size: float): Font =
    when defined js:
        result.new()
        result.filePath = face
        result.isHorizontal = true # TODO: Support vertical fonts
        result.size = size
        var c: ref RootObj
        asm "`c` = {};"
        result.chars = c
    else:
        let path = findFontFileForFace(face)
        if path != nil:
            result = newFontWithFile(path, size)

proc systemFontSize*(): float = 16

proc systemFontOfSize*(size: float): Font =
    for f in preferredFonts:
        result = newFontWithFace(f, size)
        if result != nil:
            break

proc systemFont*(): Font =
    if sysFont == nil:
        sysFont = systemFontOfSize(systemFontSize())
    result = sysFont
    if result == nil:
        logi "WARNING: Could not create system font"

import math

proc chunkAndCharIndexForRune(f: Font, r: Rune): tuple[ch: CharInfo, index: int] =
    let chunkStart = floor(r.int / charChunkLength.int).int32
    result.index = r.int mod charChunkLength
    when defined js:
        var chunk: CharInfo
        let chars = f.chars
        var hasCh = false
        asm "`hasCh` = `chunkStart` in `chars`;"
        if not hasCh:
            chunk = f.bakeChars(chunkStart)
            asm "`chars`[`chunkStart`] = `chunk`;"
        else:
            asm "`chunk` = `chars`[`chunkStart`];"
        result.ch = chunk
    else:
        if not f.chars.hasKey(chunkStart):
            f.chars[chunkStart] = f.bakeChars(chunkStart)
        result.ch = f.chars[chunkStart]

proc getQuadDataForRune*(f: Font, r: Rune, quad: var array[16, Coord], texture: var GLuint, pt: var Point) =
    let (chunk, charIndexInChunk) = f.chunkAndCharIndexForRune(r)
    var bc : type(chunk.bakedChars)
    shallowCopy(bc, chunk.bakedChars)
    let c = charOff(charIndexInChunk)

    let x0 = pt.x + bc.charOffComp(c, compX).Coord
    let x1 = x0 + bc.charOffComp(c, compWidth).Coord
    let y0 = pt.y + bc.charOffComp(c, compY).Coord
    let y1 = y0 + bc.charOffComp(c, compHeight).Coord

    var s0 = bc.charOffComp(c, compTexX).Coord
    var t0 = bc.charOffComp(c, compTexY).Coord
    let s1 = (s0 + bc.charOffComp(c, compWidth).Coord) / chunk.texWidth.Coord
    let t1 = (t0 + bc.charOffComp(c, compHeight).Coord) / chunk.texHeight.Coord
    s0 /= chunk.texWidth.Coord
    t0 /= chunk.texHeight.Coord

    quad[0] = x0; quad[1] = y0; quad[2] = s0; quad[3] = t0
    quad[4] = x1; quad[5] = y0; quad[6] = s1; quad[7] = t0
    quad[8] = x1; quad[9] = y1; quad[10] = s1; quad[11] = t1
    quad[12] = x0; quad[13] = y1; quad[14] = s0; quad[15] = t1
    pt.x += bc.charOffComp(c, compAdvance).Coord
    texture = chunk.texture

proc sizeOfString*(f: Font, s: string): Size =
    var pt : Point
    var quad: array[16, Coord]
    var tex: GLuint
    var first = true
    for ch in s.runes:
        if first:
            first = false
        else:
            pt.x += f.horizontalSpacing
        f.getQuadDataForRune(ch, quad, tex, pt)
    result = newSize(pt.x, f.size)

proc getClosestCursorPositionToPointInString*(f: Font, s: string, p: Point, position: var int, offset: var Coord) =
    var pt = zeroPoint
    var closestPoint = zeroPoint
    var quad: array[16, Coord]
    var i = 0
    var tex: GLuint
    for ch in s.runes:
        f.getQuadDataForRune(ch, quad, tex, pt)
        if (f.isHorizontal and (abs(p.x - pt.x) < abs(p.x - closestPoint.x))) or
           (not f.isHorizontal and (abs(p.y - pt.y) < abs(p.y - closestPoint.y))):
            closestPoint = pt
            position = i + 1
        pt.x += f.horizontalSpacing
        inc i
    offset = if f.isHorizontal: closestPoint.x else: closestPoint.y

proc cursorOffsetForPositionInString*(f: Font, s: string, position: int): Coord =
    var pt = zeroPoint
    var quad: array[16, Coord]
    var i = 0
    var tex: GLuint

    for ch in s.runes:
        if i == position:
            break
        inc i

        f.getQuadDataForRune(ch, quad, tex, pt)
        pt.x += f.horizontalSpacing
    result = if f.isHorizontal: pt.x else: pt.y
