import math
import types
import system_logger
import unicode
import tables
import rect_packer
import nimx.resource

when defined(js):
    import dom
    import private.js_font_metrics
else:
    import ttf
    import os
    import write_image_impl

import private.edtaa3func # From ttf library
import private.simple_table

import opengl
import portable_gl

const charChunkLength = 200

type BackedCharComponent = enum
    compX = 0
    compY
    compAdvance
    compTexX
    compTexY
    compWidth
    compHeight

type Baseline* = enum
    bTop
    bAlphabetic
    bBottom

const numberOfComponents = ord(high(BackedCharComponent)) + 1
type BakedCharInfo = array[numberOfComponents * charChunkLength, int16]

template charOff(i: int): int = i * numberOfComponents
template charOffComp(bc: var BakedCharInfo, charOffset: int, comp: BackedCharComponent): var int16 =
    bc[charOffset + ord(comp)]

type CharInfo = ref object
    bakedChars: BakedCharInfo
    tempBitmap: seq[byte]
    texture: TextureRef
    texWidth, texHeight: uint16

when defined(js):
    type FastString = cstring
else:
    type FastString = string


template charHeightForSize(s: float): float =
    if s > 128: 128
    else: 64

template scaleForSize(s: float): float = s / charHeightForSize(s)

type FontImpl = ref object
    chars: SimpleTable[int32, CharInfo]
    ascent: float32
    descent: float32

var fontCache : SimpleTable[FastString, FontImpl]

proc cachedImplForFont(face: string, sz: float): FontImpl =
    if fontCache.isNil:
        fontCache = newSimpleTable(FastString, FontImpl)
    var key : FastString = face & "_" & $charHeightForSize(sz).int
    if fontCache.hasKey(key):
        result = fontCache[key]
    else:
        result.new()
        result.chars = newSimpleTable(int32, CharInfo)
        fontCache[key] = result

type Font* = ref object
    impl: FontImpl
    mSize: float
    isHorizontal*: bool
    scale*: float
    filePath: string
    horizontalSpacing*: Coord
    shadowX*, shadowY*, shadowBlur*: float32
    glyphMargin: int32
    baseline*: Baseline # Beware! Experinmetal!

proc `size=`*(f: Font, s: float) =
    f.mSize = s
    f.scale = scaleForSize(s)
    f.impl = cachedImplForFont(f.filePath, s)

template size*(f: Font): float = f.mSize

proc prepareTexture(i: CharInfo): GL =
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

when dumpDebugBitmaps:
    template dumpBitmaps(name: string, bitmap: seq[byte], width, height, start: int, fSize: float) =
        var bmp = newSeq[byte](width * height * 3)
        for i in 0 .. < width * height:
            bmp[3*i] = bitmap[i]

        discard stbi_write_bmp("atlas_nimx_" & name & "_" & $fSize & "_" & $start & "_" & $width & "x" & $height & ".bmp", width.cint, height.cint, 3.cint, addr bmp[0])

when defined(js):
    proc cssFontName(f: Font): cstring =
        let fSize = charHeightForSize(f.size)
        let fName : cstring = f.filePath
        {.emit: """`result` = "" + (`fSize`|0) + "px " + `fName`;""".}

    proc auxCanvasForFont(f: Font): Element =
        let fName = f.cssFontName
        result = document.createElement("canvas")
        {.emit: """
        var ctx = `result`.getContext('2d');
        `result`.style.font = `fName`;
        ctx.font = `fName`;
        `result`.__nimx_ctx = ctx;
        """.}

proc updateFontMetrics(f: Font) =
    logi "update"
    when defined(js):
        var ascent, descent: int32
        let fSize = charHeightForSize(f.size)
        let fName = f.cssFontName
        {.emit: """
        var metrics = nimx_calculateFontMetricsInCanvas(`fName`, `fSize`);
        `ascent` = metrics.ascent;
        `descent` = -metrics.descent;
        """.}
        f.impl.ascent = float32(ascent)
        f.impl.descent = float32(descent)
    else:
        var rawData = readFile(f.filePath)
        var fontinfo: stbtt_fontinfo
        if stbtt_InitFont(fontinfo, cast[ptr font_type](rawData.cstring), 0) == 0:
            logi "Could not init font"
            raise newException(Exception, "Could not init font")

        let fSize = charHeightForSize(f.size)
        let scale = stbtt_ScaleForMappingEmToPixels(fontinfo, fSize)
        var ascent, descent, lineGap : cint
        stbtt_GetFontVMetrics(fontinfo, ascent, descent, lineGap)
        f.impl.ascent = float32(ascent) * scale
        f.impl.descent = float32(descent) * scale

template updateFontMetricsIfNeeded(f: Font) =
    if f.impl.ascent == 0: f.updateFontMetrics()

proc ascent*(f: Font): float32 =
    f.updateFontMetricsIfNeeded()
    result = f.impl.ascent * f.scale

proc descent*(f: Font): float32 =
    f.updateFontMetricsIfNeeded()
    result = f.impl.descent * f.scale

proc bakeChars(f: Font, start: int32, res: CharInfo) =
    let startChar = start * charChunkLength
    let endChar = startChar + charChunkLength

    let fSize = charHeightForSize(f.size)

    var rectPacker = newPacker(32, 32)
    when defined(js):
        f.updateFontMetricsIfNeeded()

        let h = int32(f.impl.ascent - f.impl.descent)
        let canvas = f.auxCanvasForFont()
        let fName = f.cssFontName

        {.emit: """
        var ctx = `canvas`.__nimx_ctx;
        """.}

        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                var w: int32
                var s : cstring
                {.emit: """
                var mt = ctx.measureText(String.fromCharCode(`i`));
                `s` = String.fromCharCode(`i`);
                `w` = mt.width;
                """.}

                if w > 0:
                    let (x, y) = rectPacker.packAndGrow(w + f.glyphMargin * 2, h + f.glyphMargin * 2)

                    let c = charOff(i - startChar)
                    #res.bakedChars.charOffComp(c, compX) = 0
                    #res.bakedChars.charOffComp(c, compY) = 0
                    res.bakedChars.charOffComp(c, compAdvance) = w.int16
                    res.bakedChars.charOffComp(c, compTexX) = (x + f.glyphMargin).int16
                    res.bakedChars.charOffComp(c, compTexY) = (y + f.glyphMargin).int16
                    res.bakedChars.charOffComp(c, compWidth) = w.int16
                    res.bakedChars.charOffComp(c, compHeight) = h.int16

        let texWidth = rectPacker.width
        let texHeight = rectPacker.height
        res.texWidth = texWidth.uint16
        res.texHeight = texHeight.uint16

        asm """
        `canvas`.width = `texWidth`;
        `canvas`.height = `texHeight`;
        ctx.textBaseline = "top";
        ctx.font = `fName`;
        """

        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                let c = charOff(i - startChar)
                let w = res.bakedChars.charOffComp(c, compAdvance)
                if w > 0:
                    let x = res.bakedChars.charOffComp(c, compTexX)
                    let y = res.bakedChars.charOffComp(c, compTexY)
                    {.emit: "ctx.fillText(String.fromCharCode(`i`), `x`, `y`);".}

        var data : seq[float32]
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

        shallowCopy(res.tempBitmap, byteData)
    else:
        var rawData = readFile(f.filePath)

        var fontinfo: stbtt_fontinfo
        if stbtt_InitFont(fontinfo, cast[ptr font_type](rawData.cstring), 0) == 0:
            logi "Could not init font"
            raise newException(Exception, "Could not init font")

        let scale = stbtt_ScaleForMappingEmToPixels(fontinfo, fSize)
        var ascent, descent, lineGap : cint
        stbtt_GetFontVMetrics(fontinfo, ascent, descent, lineGap)

        f.impl.ascent = float32(ascent) * scale
        f.impl.descent = float32(descent) * scale

        var glyphIndexes: array[charChunkLength, cint]

        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                let g = stbtt_FindGlyphIndex(fontinfo, i) # g > 0 when found
                glyphIndexes[i - startChar] = g
                var advance, lsb, x0, y0, x1, y1: cint
                stbtt_GetGlyphHMetrics(fontinfo, g, advance, lsb)
                stbtt_GetGlyphBitmapBox(fontinfo, g, scale, scale, x0, y0, x1, y1)
                let gw = x1 - x0
                let gh = y1 - y0
                let (x, y) = rectPacker.packAndGrow(gw + f.glyphMargin * 2, gh + f.glyphMargin * 2)

                let c = charOff(i - startChar)
                res.bakedChars.charOffComp(c, compX) = (x0.cfloat).int16
                res.bakedChars.charOffComp(c, compY) = (y0.cfloat + ascent.cfloat * scale).int16
                res.bakedChars.charOffComp(c, compAdvance) = (scale * advance.cfloat).int16
                res.bakedChars.charOffComp(c, compTexX) = (x + f.glyphMargin).int16
                res.bakedChars.charOffComp(c, compTexY) = (y + f.glyphMargin).int16
                res.bakedChars.charOffComp(c, compWidth) = (gw).int16
                res.bakedChars.charOffComp(c, compHeight) = (gh).int16

        let width = rectPacker.width
        let height = rectPacker.height
        res.texWidth = width.uint16
        res.texHeight = height.uint16
        var temp_bitmap = newSeq[byte](width * height)

        let dfCtx = newDistanceFieldContext()
        for i in startChar .. < endChar:
            if isPrintableCodePoint(i):
                let c = charOff(i - startChar)
                if res.bakedChars.charOffComp(c, compAdvance) > 0:
                    let x = res.bakedChars.charOffComp(c, compTexX).int
                    let y = res.bakedChars.charOffComp(c, compTexY).int
                    let w = res.bakedChars.charOffComp(c, compWidth).cint
                    let h = res.bakedChars.charOffComp(c, compHeight).cint
                    if w > 0 and h > 0:
                        stbtt_MakeGlyphBitmap(fontinfo, addr temp_bitmap[x + y * width.int], w, h, width.cint, scale, scale, glyphIndexes[i - startChar])
                        dfCtx.make_distance_map(temp_bitmap, x - f.glyphMargin, y - f.glyphMargin, w + f.glyphMargin * 2, h + f.glyphMargin * 2, width)

        when dumpDebugBitmaps:
            dumpBitmaps("df", temp_bitmap, width, height, start, fSize)

        shallowCopy(res.tempBitmap, temp_bitmap)

when not defined(js):
    proc newFontWithFile*(pathToTTFile: string, size: float): Font =
        result.new()
        result.isHorizontal = true # TODO: Support vertical fonts
        result.filePath = pathToTTFile
        result.size = size
        result.glyphMargin = 8

var sysFont : Font

const preferredFonts = when defined(js) or defined(windows) or defined(emscripten):
        [
            "Arial",
            "OpenSans-Regular"
        ]
    elif defined(ios):
        [
            "OpenSans-Regular"
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

when not defined(js):
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
        elif defined(emscripten):
            [
                "res"
            ]
        else:
            [
                "/usr/share/fonts/truetype",
                "/usr/share/fonts/truetype/ubuntu-font-family",
                "/usr/share/fonts/TTF",
                "/usr/share/fonts/truetype/dejavu"
            ]

when not defined(js):
    iterator potentialFontFilesForFace(face: string): string =
        for sp in fontSearchPaths:
            yield sp / face & ".ttf"
        when not defined(emscripten):
            yield getAppDir() / "res" / face & ".ttf"
            yield getAppDir() /../ "Resources" / face & ".ttf"
            yield getAppDir() / face & ".ttf"

    proc findFontFileForFace(face: string): string =
        for f in potentialFontFilesForFace(face):
            if fileExists(f):
                return f

proc newFontWithFace*(face: string, size: float): Font =
    when defined(js):
        result.new()
        result.filePath = face
        result.isHorizontal = true # TODO: Support vertical fonts
        result.size = size
        result.glyphMargin = 8
    else:
        let path = findFontFileForFace(face)
        if path != nil:
            result = newFontWithFile(path, size)

proc systemFontSize*(): float = 16

proc setGlyphMargin*(f: Font, margin: int32) =
    if margin == f.glyphMargin:
        return

    f.glyphMargin = margin
    f.impl = cachedImplForFont(f.filePath, f.size)

proc systemFontOfSize*(size: float): Font =
    for f in preferredFonts:
        result = newFontWithFace(f, size)
        if result != nil: return

    when not defined(js):
        logi "ERROR: Could not find system font:"
        for face in preferredFonts:
            for f in potentialFontFilesForFace(face):
                logi "Tried path '", f, "'"

proc systemFont*(): Font =
    if sysFont == nil:
        sysFont = systemFontOfSize(systemFontSize())
    result = sysFont
    if result == nil:
        logi "WARNING: Could not create system font"

proc chunkAndCharIndexForRune(f: Font, r: Rune): tuple[ch: CharInfo, index: int] =
    let chunkStart = floor(r.int / charChunkLength.int).int32
    result.index = r.int mod charChunkLength
    if f.impl.chars.hasKey(chunkStart):
       result.ch = f.impl.chars[chunkStart]
    else:
        result.ch.new()
        f.bakeChars(chunkStart, result.ch)
        f.impl.chars[chunkStart] = result.ch

    if result.ch.texture.isEmpty and sharedGL() != nil:
        let gl = result.ch.prepareTexture()
        let texWidth = result.ch.texWidth.GLsizei
        let texHeight = result.ch.texHeight.GLsizei
        when defined(js):
            var byteData: seq[byte]
            shallowCopy(byteData, result.ch.tempBitmap)
            {.emit: """
            `gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.ALPHA, `texWidth`, `texHeight`, 0, `gl`.ALPHA, `gl`.UNSIGNED_BYTE, `byteData`);
            """.}
        else:
            gl.texImage2D(gl.TEXTURE_2D, 0, GLint(gl.ALPHA), texWidth, texHeight, 0, gl.ALPHA, gl.UNSIGNED_BYTE, addr result.ch.tempBitmap[0])
        result.ch.tempBitmap = nil
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        #gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)
        #gl.generateMipmap(gl.TEXTURE_2D)

proc getQuadDataForRune*(f: Font, r: Rune, quad: var openarray[Coord], offset: int, texture: var TextureRef, pt: var Point) =
    let (chunk, charIndexInChunk) = f.chunkAndCharIndexForRune(r)
    let c = charOff(charIndexInChunk)

    template charComp(e: BackedCharComponent): auto =
        chunk.bakedChars.charOffComp(c, e).Coord

    let w = charComp(compWidth)
    let h = charComp(compHeight)

    f.updateFontMetricsIfNeeded()

    let baselineOffset = case f.baseline
        of bTop: 0.0
        of bBottom: -f.impl.ascent + f.impl.descent
        of bAlphabetic: -f.impl.ascent

    let m = f.glyphMargin.float * f.scale
    let x0 = pt.x + charComp(compX) * f.scale - m
    let x1 = x0 + w * f.scale + m * 2.0
    let y0 = pt.y + charComp(compY) * f.scale - m + baselineOffset * f.scale
    let y1 = y0 + h * f.scale + m * 2.0

    var s0 = charComp(compTexX) - f.glyphMargin.float
    var t0 = charComp(compTexY) - f.glyphMargin.float
    let s1 = (s0 + w + f.glyphMargin.float * 2.0) / chunk.texWidth.Coord
    let t1 = (t0 + h + f.glyphMargin.float * 2.0) / chunk.texHeight.Coord
    s0 /= chunk.texWidth.Coord
    t0 /= chunk.texHeight.Coord

    quad[offset + 0] = x0; quad[offset + 1] = y0; quad[offset + 2] = s0; quad[offset + 3] = t0
    quad[offset + 4] = x0; quad[offset + 5] = y1; quad[offset + 6] = s0; quad[offset + 7] = t1
    quad[offset + 8] = x1; quad[offset + 9] = y1; quad[offset + 10] = s1; quad[offset + 11] = t1
    quad[offset + 12] = x1; quad[offset + 13] = y0; quad[offset + 14] = s1; quad[offset + 15] = t0
    pt.x += charComp(compAdvance) * f.scale
    texture = chunk.texture

template getQuadDataForRune*(f: Font, r: Rune, quad: var array[16, Coord], texture: var TextureRef, pt: var Point) =
    f.getQuadDataForRune(r, quad, 0, texture, pt)

proc getAdvanceForRune(f: Font, r: Rune): Coord =
    let (chunk, charIndexInChunk) = f.chunkAndCharIndexForRune(r)
    let c = charOff(charIndexInChunk)
    result = chunk.bakedChars.charOffComp(c, compAdvance).Coord * f.scale

proc height*(f: Font): float32 =
    f.updateFontMetricsIfNeeded()
    result = (f.impl.ascent - f.impl.descent) * f.scale

proc sizeOfString*(f: Font, s: string): Size =
    var pt : Point
    var first = true
    for ch in s.runes:
        if first:
            first = false
        else:
            pt.x += f.horizontalSpacing
        pt.x += f.getAdvanceForRune(ch)
    result = newSize(pt.x, f.height)

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
    if offset == 0: position = 0

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
