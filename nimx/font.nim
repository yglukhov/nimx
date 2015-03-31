import types
import logging
import unicode
import tables

when not defined js:
    import ttf
    import os

# Quick and dirty interface for fonts.
# TODO:
#  - Remove dependency on OpenGL.
#  - Lazy bucket loading for character ranges
#  - Distance field textures

import opengl


when defined js:
    type stbtt_bakedchar = object

const charChunkLength = 96

type CharInfo = ref object
    bakedChars: array[charChunkLength, stbtt_bakedchar]
    texture: GLuint

type Font* = ref object
    chars: Table[int32, CharInfo]
    size*: float
    isHorizontal*: bool
    filePath: string
    when defined js:
        ctx: ref RootObj


proc bakeChars(f: Font, start: int32) =
    when defined js:
        discard
    else:
        var rawData = readFile(f.filePath)
        const width = 512
        const height = 512
        var temp_bitmap : array[width * height, byte]
        var info : CharInfo
        info.new()
        discard stbtt_BakeFontBitmap(cstring(rawData), 0, f.size, addr temp_bitmap, width, height, start * charChunkLength, charChunkLength, addr info.bakedChars) # no guarantee this fits!
        glGenTextures(1, addr info.texture)
        glBindTexture(GL_TEXTURE_2D, info.texture)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, width, height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, addr temp_bitmap)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        f.chars[start] = info

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
        result.size = size
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

proc getQuadDataForRune*(f: Font, r: Rune, quad: var array[16, Coord], texture: var GLuint, pt: var Point) =
    when not defined js:
        var x, y: cfloat
        x = pt.x
        y = pt.y
        var q : stbtt_aligned_quad
        let chunkStart = (r.int / charChunkLength.int).int32
        if not f.chars.hasKey(chunkStart):
            f.bakeChars(chunkStart)
        let charIndexInChunk = r.int mod charChunkLength
        let chunk = f.chars[chunkStart]

        stbtt_GetBakedQuad(chunk.bakedChars[charIndexInChunk], 512, 512, x, y, q, true) # true=opengl & d3d10+,false=d3d9
        quad = [ q.x0, q.y0, q.s0, q.t0,
                q.x1, q.y0, q.s1, q.t0,
                q.x1, q.y1, q.s1, q.t1,
                q.x0, q.y1, q.s0, q.t1 ]
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

