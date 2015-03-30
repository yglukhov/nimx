
import types
import opengl
import math
import portable_gl
import unsigned

when not defined js:
    import resource
    import load_image_impl
    import write_image_impl

type Image* = ref object of RootObj
    texture*: GLuint
    size*: Size
    sizeInTexels*: Size

when not defined js:
    template offset(p: pointer, off: int): pointer =
        cast[pointer](cast[int](p) + off)

    proc imageWithBitmap*(data: ptr uint8, x, y, comp: int): Image =
        result.new()
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
        let texHeight = if isPowerOfTwo(y): y.int else: nextPowerOfTwo(y)

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

        glTexImage2D(GL_TEXTURE_2D, 0, format.cint, texWidth.GLsizei, texHeight.GLsizei, 0, format.GLenum, GL_UNSIGNED_BYTE, cast[pointer] (pixelData))
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        result.size.width = x.Coord
        result.size.height = y.Coord
        if data != pixelData:
            dealloc(pixelData)

    proc imageWithContentsOfFile*(path: string): Image =
        var x, y, comp: cint
        var data = stbi_load(path, addr x, addr y, addr comp, 0)
        result = imageWithBitmap(data, x, y, comp)
        stbi_image_free(data)

    proc imageWithResource*(r: ResourceObj): Image =
        var x, y, comp: cint
        var data = stbi_load_from_memory(cast[ptr uint8](r.data), r.size.cint, addr x, addr y, addr comp, 0)
        result = imageWithBitmap(data, x, y, comp)
        stbi_image_free(data)


proc imageWithResource*(name: string): Image =
    when defined js:
        result.new()
        let nativeName : cstring = "res/" & name
        asm """
        `result`.__image = new Image();
        `result`.__image.crossOrigin = '';
        `result`.__image.src = `nativeName`;
        """
    else:
        let r = loadResourceByName(name)
        result = imageWithResource(r[])
        freeResource(r)

proc imageWithSize*(size: Size): Image =
    result.new()
    result.size = size
    let texWidth = if isPowerOfTwo(size.width.int): size.width.int else: nextPowerOfTwo(size.width.int)
    let texHeight = if isPowerOfTwo(size.height.int): size.height.int else: nextPowerOfTwo(size.height.int)
    result.sizeInTexels.width = size.width / texWidth.Coord
    result.sizeInTexels.height = size.height / texHeight.Coord

method getTexture*(i: Image, gl: GL): GLuint =
    when defined js:
        if i.texture == 0:
            var width, height : Coord
            var loadingComplete = false
            asm """
            `loadingComplete` = `i`.__image.complete;
            if (`loadingComplete`)
            {
                `width` = `i`.__image.width;
                `height` = `i`.__image.height;
            }
            """
            if loadingComplete:
                i.texture = gl.createTexture()
                gl.bindTexture(gl.TEXTURE_2D, i.texture)
                let texWidth = if isPowerOfTwo(width.int): width.int else: nextPowerOfTwo(width.int)
                let texHeight = if isPowerOfTwo(height.int): height.int else: nextPowerOfTwo(height.int)
                i.size.width = width
                i.size.height = height
                i.sizeInTexels.width = width / texWidth.Coord
                i.sizeInTexels.height = height / texHeight.Coord
                if texWidth != width.int or texHeight != height.int:
                    asm """
                    var canvas = document.createElement('canvas');
                    canvas.width = `texWidth`;
                    canvas.height = `texHeight`;
                    canvas.getContext('2d').drawImage(`i`.__image, 0, 0);
                    `gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.RGBA, `gl`.RGBA, `gl`.UNSIGNED_BYTE, canvas);
                    """
                else:
                    asm "`gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.RGBA, `gl`.RGBA, `gl`.UNSIGNED_BYTE, `i`.__image);"

                asm """
                `i`.__image = null;
                `gl`.texParameteri(`gl`.TEXTURE_2D, `gl`.TEXTURE_MAG_FILTER, `gl`.NEAREST);
                `gl`.texParameteri(`gl`.TEXTURE_2D, `gl`.TEXTURE_MIN_FILTER, `gl`.NEAREST);
                """
    result = i.texture

method size*(i: Image): Size = i.size

type ImageFileFormat = enum tga, hdr, bmp, png

proc writeToFile(i: Image, path: string, format: ImageFileFormat) =
    when not defined(js) and not defined(android):
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

        discard case format:
            of tga: stbi_write_tga(path, actualWidth.cint, actualHeight.cint, comp.cint, data)
            of hdr: stbi_write_hdr(path, actualWidth.cint, actualHeight.cint, comp.cint, data)
            of bmp: stbi_write_bmp(path, actualWidth.cint, actualHeight.cint, comp.cint, data)
            of png: stbi_write_png(path, actualWidth.cint, actualHeight.cint, comp.cint, data, 0)

        dealloc(data)


proc writeToBMPFile*(i: Image, path: string) = i.writeToFile(path, bmp)
proc writeToPNGFile*(i: Image, path: string) = i.writeToFile(path, png)
proc writeToTGAFile*(i: Image, path: string) = i.writeToFile(path, tga)
#proc writeToHDRFile*(i: Image, path: string) = i.writeToFile(path, hdr) # Crashes...

