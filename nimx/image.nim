
import types
import opengl
import math
import load_image_impl
import write_image_impl

type Image* = ref object of RootObj
    texture: GLuint
    size: Size
    sizeInTexels*: Size

template offset(p: pointer, off: int): pointer =
    cast[pointer](cast[int](p) + off)

proc imageWithContentsOfFile*(path: string): Image =
    result.new()
    var x, y, comp: cint
    var data = stbi_load(path, addr x, addr y, addr comp, 0)
    glGenTextures(1, addr result.texture)
    glBindTexture(GL_TEXTURE_2D, result.texture)
    let format : GLint = case comp:
        of 1: GL_ALPHA
        of 2: GL_LUMINANCE_ALPHA
        of 3: GL_RGB
        of 4: GL_RGBA
        else: 0
    result.size = newSize(x.Coord, y.Coord)
    let texWidth = if isPowerOfTwo(x): x.int else: nextPowerOfTwo(x)
    let texHeight = if isPowerOfTwo(y): x.int else: nextPowerOfTwo(x)

    var pixelData = data

    result.sizeInTexels.width = 1.0
    result.sizeInTexels.height = 1.0

    if texWidth != x or texHeight != y:
        let texRowWidth = texWidth * comp
        let newData = alloc(texRowWidth * texHeight)
        let rowWidth = x * comp
        for row in 0 .. y:
            copyMem(offset(newData, row * texRowWidth), offset(data, row * rowWidth), rowWidth)
        pixelData = cast[ptr uint8](newData)
        result.sizeInTexels.width = x.Coord / texWidth.Coord
        result.sizeInTexels.height = y.Coord / texHeight.Coord

    glTexImage2D(GL_TEXTURE_2D, 0, comp, texWidth.GLsizei, texHeight.GLsizei, 0, format.GLenum, GL_UNSIGNED_BYTE, cast[pointer] (pixelData))
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

    stbi_image_free(data)
    if data != pixelData:
        dealloc(pixelData)

    result.size.width = x.Coord
    result.size.height = y.Coord

proc draw*(i: Image, drawProc: proc()) =
    # set graphics context
    defer:
        # restore context
        discard
    drawProc()

method texture*(i: Image): GLuint = i.texture

method size*(i: Image): Size = i.size

type ImageFileFormat = enum tga, hdr, bmp, png

proc writeToFile(i: Image, path: string, format: ImageFileFormat) =
    glBindTexture(GL_TEXTURE_2D, i.texture)
    var w, h: GLint
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, addr w)
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, addr h)

    let comp = 3

    var data = alloc(comp * w * h)
    glGetTexImage(GL_TEXTURE_2D, 0, GL_RGB, GL_UNSIGNED_BYTE, data)

    let actualWidth = i.size.width.GLint
    let actualHeight = i.size.height.GLint
    if w != actualWidth:
        let actualRowWidth = actualWidth * comp
        let dataRowWidth = w * comp
        var newData = alloc(actualRowWidth * actualHeight)

        for row in 0 .. actualHeight:
            copyMem(offset(newData, row * actualRowWidth), offset(data, row * dataRowWidth), actualRowWidth)

        dealloc(data)
        data = newData

    let res = case format:
        of tga: stbi_write_tga(path, actualWidth.cint, actualHeight.cint, comp.cint, data)
        of hdr: stbi_write_hdr(path, actualWidth.cint, actualHeight.cint, comp.cint, data)
        of bmp: stbi_write_bmp(path, actualWidth.cint, actualHeight.cint, comp.cint, data)
        of png: stbi_write_png(path, actualWidth.cint, actualHeight.cint, comp.cint, data, 0)

    dealloc(data)


proc writeToBMPFile*(i: Image, path: string) = i.writeToFile(path, bmp)
proc writeToPNGFile*(i: Image, path: string) = i.writeToFile(path, png)
proc writeToTGAFile*(i: Image, path: string) = i.writeToFile(path, tga)
#proc writeToHDRFile*(i: Image, path: string) = i.writeToFile(path, hdr) # Crashes...

