import types
import system_logger
import unicode
import tables
import rect_packer

when defined js:
    import dom
    import private.js_font_metrics
else:
    import ttf
    import os
    import write_image_impl

import private.edtaa3func # From ttf library
import private.simple_table

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
    texture: TextureRef
    texWidth, texHeight: uint16

when defined(js):
    type FastString = cstring
else:
    type FastString = string


template charHeightForSize(s: float): float = 64
template scaleForSize(s: float): float = s / charHeightForSize(s)

var fontCache : SimpleTable[FastString, SimpleTable[int32, CharInfo]]

proc cachedCharsForFont(face: string, sz: float): SimpleTable[int32, CharInfo] =
    if fontCache.isNil:
        fontCache = newSimpleTable(FastString, SimpleTable[int32, CharInfo])
    var key : FastString = face & "_" & $charHeightForSize(sz).int
    if fontCache.hasKey(key):
        result = fontCache[key]
    else:
        result = newSimpleTable(int32, CharInfo)
        fontCache[key] = result

type Font* = ref object
    chars: SimpleTable[int32, CharInfo]
    mSize: float
    isHorizontal*: bool
    scale: float
    filePath: string
    horizontalSpacing*: Coord
    gamma*, base*: float32
    ascent, descent: float32
    shadowX*, shadowY*, shadowBlur*: float32

    when defined js:
        canvas: Element

proc linearDependency(x, x1, y1, x2, y2: float): float =
    result = y1 + (x - x1) * (y2 - y1) / (x2 - x1)

proc gammaWithSize(x: float): float =
    if x < 60:
        result = linearDependency(x, 14, 0.23, 60, 0.1)
    elif x < 160:
        result = linearDependency(x, 60, 0.1, 160, 0.03)
    else:
        result = linearDependency(x, 160, 0.03, 200, 0.02)


proc `size=`*(f: Font, s: float) =
    f.mSize = s
    f.scale = scaleForSize(s)
    f.chars = cachedCharsForFont(f.filePath, s)
    f.base = 0.5
    f.gamma = gammaWithSize(s)

template size*(f: Font): float = f.mSize

proc prepareTexture(i: var CharInfo): GL =
    result = sharedGL()
    i.texture = result.createTexture()
    result.bindTexture(result.TEXTURE_2D, i.texture)
    result.texParameteri(result.TEXTURE_2D, result.TEXTURE_MIN_FILTER, result.LINEAR)

const dumpDebugBitmaps = false

when dumpDebugBitmaps and defined(js):
    proc logBitmap(title: cstring, bytes: openarray[byte], width, height: int) =
        {.emit: """
        var span = document.createElement("span");
        span.innerHTML = `title`;
        document.body.appendChild(span);
        var canvas = document.createElement("canvas")
        document.body.appendChild(canvas);
        canvas.width = `width`;
        canvas.height = `height`;
        var ctx = `canvas`.getContext('2d');
        var imgData2 = ctx.createImageData(`width`, `height`);
        var imgData = imgData2.data;
        var sz = `width` * `height`;
        for (var i = 0; i < sz; ++i) {
            var offs = i * 4;
            imgData[offs] = 0;// `bytes`[i];
            imgData[offs + 1] = 0; //`bytes`[i];
            imgData[offs + 2] = 0; //`bytes`[i];
            imgData[offs + 3] = `bytes`[i];
        }
        ctx.putImageData(imgData2, 0, 0);
        """.}

template isPrintableCodePoint(c: int): bool = not (i <= 0x1f or i == 0x7f or (i >= 0x80 and i <= 0x9F))

proc bakeChars(f: Font, start: int32): CharInfo =
    result.new()

    let startChar = start * charChunkLength
    let endChar = startChar + charChunkLength

    let fSize = charHeightForSize(f.size)

    var rectPacker = newPacker(32, 32)
    when defined js:
        let fName : cstring = f.filePath
        let fontName : cstring = $fSize.int & "px " & f.filePath
        let canvas = document.createElement("canvas").Element
        var ascent, descent: int32
        {.emit: """
        var ctx = `canvas`.getContext('2d');
        ctx.font = `fontName`;
        `canvas`.style.font = `fontName`;
        ctx.textBaseline = "top";
        var metrics = `f`.__nimx_metrix;
        if (metrics === undefined) {
            var mt = nimx_calculateFontMetricsInCanvas(ctx, `fName`, `fSize`);
            metrics = {ascent: mt.ascent, descent: mt.descent};
            `f`.__nimx_metrix = metrics;
        }
        `ascent` = metrics.ascent;
        `descent` = metrics.descent;
        """.}
        f.canvas = canvas

        const glyphMargin = 2
        let h = ascent + descent

        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                var w: int32
                var isspace = false
                var s : cstring
                asm """
                var mt = ctx.measureText(String.fromCharCode(`i`));
                `s` = String.fromCharCode(`i`);
                `isspace` = `s` == " ";
                `w` = mt.width;
                """

                if w > 0:
                    let (x, y) = rectPacker.packAndGrow(w + glyphMargin * 2, h + glyphMargin * 2)

                    let c = charOff(i - startChar)
                    #result.bakedChars.charOffComp(c, compX) = 0
                    #result.bakedChars.charOffComp(c, compY) = 0
                    result.bakedChars.charOffComp(c, compAdvance) = w.int16
                    result.bakedChars.charOffComp(c, compTexX) = (x + glyphMargin).int16
                    result.bakedChars.charOffComp(c, compTexY) = (y + glyphMargin).int16
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
            if isPrintableCodePoint(i):
                let c = charOff(i - startChar)
                let w = result.bakedChars.charOffComp(c, compAdvance)
                if w > 0:
                    let x = result.bakedChars.charOffComp(c, compTexX)
                    let y = result.bakedChars.charOffComp(c, compTexY)
                    {.emit: "ctx.fillText(String.fromCharCode(`i`), `x`, `y`);".}

        var data : seq[cdouble]
        var byteData : seq[byte]
        {.emit: """
        var sz = `texWidth` * `texHeight`;
        var imgData = ctx.getImageData(0, 0, `texWidth`, `texHeight`).data;
        `data` = new Float32Array(sz);
        `byteData` = new Uint8Array(sz);
        for (var i = 3, j = 0; j < sz; i += 4, ++j) {
            `data`[j] = imgData[i];
        }
        """.}

        make_distance_map(data, texWidth, texHeight)
        {.emit: "for (var i = 0; i < sz; ++i) `byteData`[i] = (255 - (`data`[i]|0))|0;".}

        when dumpDebugBitmaps:
            logBitmap("alpha", byteData, texWidth, texHeight)

        let gl = result.prepareTexture()
        asm """
        `gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.ALPHA, `texWidth`, `texHeight`, 0, `gl`.ALPHA, `gl`.UNSIGNED_BYTE, `byteData`);
        """
    else:
        var rawData = readFile(f.filePath)

        var fontinfo: stbtt_fontinfo
        if stbtt_InitFont(fontinfo, cast[font_type](rawData.cstring), 0) == 0:
            logi "Could not init font"
            return nil

        let scale = stbtt_ScaleForPixelHeight(fontinfo, fSize)
        var ascent, descent, lineGap : cint
        stbtt_GetFontVMetrics(fontinfo, ascent, descent, lineGap)
        ascent = cint(ascent.cfloat * scale)
        descent = cint(descent.cfloat * scale)

        var glyphIndexes: array[charChunkLength, cint]

        const glyphMargin = 2

        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                let g = stbtt_FindGlyphIndex(fontinfo, i) # g > 0 when found
                glyphIndexes[i - startChar] = g
                var advance, lsb, x0,y0,x1,y1: cint
                stbtt_GetGlyphHMetrics(fontinfo, g, advance, lsb)
                stbtt_GetGlyphBitmapBox(fontinfo, g, scale, scale, x0, y0, x1, y1)
                let gw = x1 - x0
                let gh = y1 - y0
                let (x, y) = rectPacker.packAndGrow(gw + glyphMargin * 2, gh + glyphMargin * 2)

                let c = charOff(i - startChar)
                result.bakedChars.charOffComp(c, compX) = x0.int16
                result.bakedChars.charOffComp(c, compY) = (ascent + y0).int16
                result.bakedChars.charOffComp(c, compAdvance) = (scale * advance.cfloat).int16
                result.bakedChars.charOffComp(c, compTexX) = (x + glyphMargin).int16
                result.bakedChars.charOffComp(c, compTexY) = (y + glyphMargin).int16
                result.bakedChars.charOffComp(c, compWidth) = gw.int16
                result.bakedChars.charOffComp(c, compHeight) = gh.int16

        let width = rectPacker.width
        let height = rectPacker.height
        result.texWidth = width.uint16
        result.texHeight = height.uint16
        var temp_bitmap = newSeq[byte](width * height)

        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                let c = charOff(i - startChar)
                if result.bakedChars.charOffComp(c, compAdvance) > 0:
                    let x = result.bakedChars.charOffComp(c, compTexX).int
                    let y = result.bakedChars.charOffComp(c, compTexY).int
                    let w = result.bakedChars.charOffComp(c, compWidth).cint
                    let h = result.bakedChars.charOffComp(c, compHeight).cint
                    stbtt_MakeGlyphBitmap(fontinfo, addr temp_bitmap[x + y * width.int], w, h, width.cint, scale, scale, glyphIndexes[i - startChar])

        when dumpDebugBitmaps:
            discard stbi_write_bmp("atlas_nimx_alpha_" & $fSize & "_" & $start & "_" & $width & "x" & $height & ".bmp", width, height, 1, addr temp_bitmap[0])

        make_distance_map(temp_bitmap, width, height)

        when dumpDebugBitmaps:
            discard stbi_write_bmp("atlas_nimx_df_" & $fSize & "_" & $start & "_" & $width & "x" & $height & ".bmp", width, height, 1, addr temp_bitmap[0])
        let gl = result.prepareTexture()
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.ALPHA, width, height, 0, gl.ALPHA, gl.UNSIGNED_BYTE, addr temp_bitmap[0])

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)
    gl.generateMipmap(gl.TEXTURE_2D)

when not defined js:
    proc newFontWithFile*(pathToTTFile: string, size: float): Font =
        result.new()
        result.isHorizontal = true # TODO: Support vertical fonts
        result.filePath = pathToTTFile
        result.size = size

var sysFont : Font

const preferredFonts = when defined(js) or defined(windows):
        [
            "Arial"
        ]
    elif defined(macosx):
        [
            "Arial",
            "Arial Unicode"
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
            "/usr/share/fonts/truetype",
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
    if not f.chars.hasKey(chunkStart):
        f.chars[chunkStart] = f.bakeChars(chunkStart)
    result.ch = f.chars[chunkStart]

proc getQuadDataForRune*(f: Font, r: Rune, quad: var openarray[Coord], offset: int, texture: var TextureRef, pt: var Point) =
    let (chunk, charIndexInChunk) = f.chunkAndCharIndexForRune(r)
    let c = charOff(charIndexInChunk)

    template charComp(e: BackedCharComponent): auto =
        chunk.bakedChars.charOffComp(c, e).Coord

    let w = charComp(compWidth).Coord
    let h = charComp(compHeight).Coord

    let x0 = pt.x + charComp(compX).Coord * f.scale
    let x1 = x0 + w * f.scale
    let y0 = pt.y + charComp(compY).Coord * f.scale
    let y1 = y0 + h * f.scale

    var s0 = charComp(compTexX).Coord
    var t0 = charComp(compTexY).Coord
    let s1 = (s0 + w) / chunk.texWidth.Coord
    let t1 = (t0 + h) / chunk.texHeight.Coord
    s0 /= chunk.texWidth.Coord
    t0 /= chunk.texHeight.Coord

    quad[offset + 0] = x0; quad[offset + 1] = y0; quad[offset + 2] = s0; quad[offset + 3] = t0
    quad[offset + 4] = x0; quad[offset + 5] = y1; quad[offset + 6] = s0; quad[offset + 7] = t1
    quad[offset + 8] = x1; quad[offset + 9] = y1; quad[offset + 10] = s1; quad[offset + 11] = t1
    quad[offset + 12] = x1; quad[offset + 13] = y0; quad[offset + 14] = s1; quad[offset + 15] = t0
    pt.x += charComp(compAdvance).Coord * f.scale
    texture = chunk.texture

template getQuadDataForRune*(f: Font, r: Rune, quad: var array[16, Coord], texture: var TextureRef, pt: var Point) =
    f.getQuadDataForRune(r, quad, 0, texture, pt)

proc sizeOfString*(f: Font, s: string): Size =
    var pt : Point
    var quad: array[16, Coord]
    var tex: TextureRef
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
    var tex: TextureRef
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
    var tex: TextureRef

    for ch in s.runes:
        if i == position:
            break
        inc i

        f.getQuadDataForRune(ch, quad, tex, pt)
        pt.x += f.horizontalSpacing
    result = if f.isHorizontal: pt.x else: pt.y
