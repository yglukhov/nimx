import types
import logging
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
#  - Lazy bucket loading for character ranges
#  - Distance field textures

import opengl
import portable_gl


when defined js:
    type stbtt_bakedchar = ref object
        w, h: uint16
        uvLeft, uvTop, uvRight, uvBottom: Coord

const charChunkLength = 96

type CharInfo = ref object
    bakedChars: array[charChunkLength, stbtt_bakedchar]
    texture: GLuint

type Font* = ref object
    when defined js:
        chars: ref RootObj
    else:
        chars: Table[int32, CharInfo]
    size*: float
    isHorizontal*: bool
    filePath: string
    when defined js:
        canvas: Element

proc bakeChars(f: Font, start: int32): CharInfo =
    result.new()
    when defined js:
        let fontName : cstring = $f.size & "px " & f.filePath
        let canvas = document.createElement("canvas").Element
        asm """
        var ctx = `canvas`.getContext('2d');
        ctx.font = `fontName`;
        ctx.textBaseline = "top";
        """
        f.canvas = canvas

        # TODO: Because of Nim bug 2476, initial size of packer should be
        # already big enough. Reduce it to 32x32 when fixed.
        var rectPacker = newPacker(512, 512)
        let startChar = start * charChunkLength
        let endChar = startChar + charChunkLength
        for i in startChar .. < endChar:
            var w: int32
            let h = f.size.int32 + 2
            asm """
            var str = String.fromCharCode(`i`);
            var mt = ctx.measureText(str);
            `w` = mt.width;
            """

            if w > 0:
                var bc : stbtt_bakedchar
                bc.new()
                bc.w = w.uint16
                bc.h = h.uint16
                asm "`bc`._str = str;"

                let (x, y) = rectPacker.packAndGrow(w, h)
                
                bc.w = w.uint16
                bc.h = h.uint16
                bc.uvLeft = x.float32
                bc.uvTop = y.float32
                bc.uvRight = (x + w).float32
                bc.uvBottom = (y + h).float32
                result.bakedChars[i - startChar] = bc

        let texWidth = rectPacker.width
        let texHeight = rectPacker.height

        asm """
        `canvas`.width = `texWidth`;
        `canvas`.height = `texHeight`;
        ctx.font = `fontName`;
        ctx.textBaseline = "top";
        """

        for bc in result.bakedChars:
            if not bc.isNil:
                let x = bc.uvLeft
                let y = bc.uvTop
                asm """
                ctx.fillText(`bc`._str, `x`, `y`);
                `bc`._str = null;
                """
                bc.uvLeft /= texWidth.float32
                bc.uvTop /= texHeight.float32
                bc.uvRight /= texWidth.float32
                bc.uvBottom /= texHeight.float32

        let gl = sharedGL()
        result.texture = gl.createTexture()
        gl.bindTexture(gl.TEXTURE_2D, result.texture)
        let c = f.chars
        asm """
        `gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.RGBA, `gl`.RGBA, `gl`.UNSIGNED_BYTE, `canvas`);
        """
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    else:
        var rawData = readFile(f.filePath)
        const width = 512
        const height = 512
        var temp_bitmap : array[width * height, byte]
        discard stbtt_BakeFontBitmap(cstring(rawData), 0, f.size, addr temp_bitmap, width, height, start * charChunkLength, charChunkLength, addr result.bakedChars) # no guarantee this fits!
        glGenTextures(1, addr result.texture)
        glBindTexture(GL_TEXTURE_2D, result.texture)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, width, height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, addr temp_bitmap)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)

when not defined js:
    proc newFontWithFile*(pathToTTFile: string, size: float): Font =
        result.new()
        result.isHorizontal = true # TODO: Support vertical fonts
        result.filePath = pathToTTFile
        result.size = size
        result.chars = initTable[int32, CharInfo]()

var sysFont : Font

const preferredFonts = when defined(macosx):
        [
            "Arial"
        ]
    elif defined(android):
        [
            "DroidSans"
        ]
    else:
        [
            "Ubuntu-R"
        ]

const fontSearchPaths = when defined(macosx):
        [
            "/Library/Fonts"
        ]
    elif defined(android):
        [
            "/system/fonts"
        ]
    else:
        [
            "/usr/share/fonts/truetype/ubuntu-font-family"
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

proc systemFont*(): Font =
    if sysFont == nil:
        for f in preferredFonts:
            sysFont = newFontWithFace(f, 16)
            if sysFont != nil:
                break
    result = sysFont

import math

proc getQuadDataForRune*(f: Font, r: Rune, quad: var array[16, Coord], texture: var GLuint, pt: var Point) =
    let chunkStart = floor(r.int / charChunkLength.int).int32
    let charIndexInChunk = r.int mod charChunkLength
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
        let bc = chunk.bakedChars[charIndexInChunk]
        quad[0] = pt.x; quad[1] = pt.y; quad[2] = bc.uvLeft; quad[3] = bc.uvTop
        quad[4] = pt.x + bc.w.Coord; quad[5] = pt.y; quad[6] = bc.uvRight; quad[7] = bc.uvTop
        quad[8] = pt.x + bc.w.Coord; quad[9] = pt.y + bc.h.Coord; quad[10] = bc.uvRight; quad[11] = bc.uvBottom
        quad[12] = pt.x; quad[13] = pt.y + bc.h.Coord; quad[14] = bc.uvLeft; quad[15] = bc.uvBottom
        pt.x += bc.w.Coord
    else:
        if not f.chars.hasKey(chunkStart):
            f.chars[chunkStart] = f.bakeChars(chunkStart)
        let chunk = f.chars[chunkStart]

        var x, y: cfloat
        x = pt.x
        y = pt.y + f.size

        var q : stbtt_aligned_quad
        stbtt_GetBakedQuad(chunk.bakedChars[charIndexInChunk], 512, 512, x, y, q, true) # true=opengl & d3d10+,false=d3d9
        quad = [ q.x0, q.y0, q.s0, q.t0,
                q.x1, q.y0, q.s1, q.t0,
                q.x1, q.y1, q.s1, q.t1,
                q.x0, q.y1, q.s0, q.t1 ]
        y -= f.size
        pt.x = x
        pt.y = y
    texture = chunk.texture

proc sizeOfString*(f: Font, s: string): Size =
    var pt : Point
    var quad: array[16, Coord]
    var tex: GLuint
    for ch in s.runes:
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
    result = if f.isHorizontal: pt.x else: pt.y

