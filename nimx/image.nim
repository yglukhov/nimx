import types
import opengl
import math
import portable_gl
import tables
import json
import streams
import resource
import resource_cache
import system_logger

when not defined js:
    import load_image_impl
    import write_image_impl

type Image* = ref object of RootObj

type SelfContainedImage* = ref object of Image
    texture*: GLuint
    mSize: Size
    sizeInTexels: Size
    framebuffer*: GLuint

type
    SpriteSheet* = ref object of SelfContainedImage
        images: TableRef[string, SpriteImage]

    SpriteImage* = ref object of Image
        spriteSheet*: Image
        texCoords: array[4, GLfloat]
        mSize: Size

var imageCache = initTable[string, Image]()

proc registerImageInCache*(name: string, i: Image) =
    imageCache[name] = i

when not defined js:
    template offset(p: pointer, off: int): pointer =
        cast[pointer](cast[int](p) + off)

    proc initWithBitmap*(i: SelfContainedImage, data: ptr uint8, x, y, comp: int) =
        glGenTextures(1, addr i.texture)
        glBindTexture(GL_TEXTURE_2D, i.texture)
        let format : GLint = case comp:
            of 1: GL_ALPHA
            of 2: GL_LUMINANCE_ALPHA
            of 3: GL_RGB
            of 4: GL_RGBA
            else: 0
        i.mSize = newSize(x.Coord, y.Coord)
        let texWidth = if isPowerOfTwo(x): x.int else: nextPowerOfTwo(x)
        let texHeight = if isPowerOfTwo(y): y.int else: nextPowerOfTwo(y)

        var pixelData = data

        i.sizeInTexels.width = 1.0
        i.sizeInTexels.height = 1.0

        if texWidth != x or texHeight != y:
            let texRowWidth = texWidth * comp
            let newData = alloc(texRowWidth * texHeight)
            let rowWidth = x * comp
            for row in 0 .. <y:
                copyMem(offset(newData, row * texRowWidth), offset(data, row * rowWidth), rowWidth)
            pixelData = cast[ptr uint8](newData)
            i.sizeInTexels.width = x.Coord / texWidth.Coord
            i.sizeInTexels.height = y.Coord / texHeight.Coord

        glTexImage2D(GL_TEXTURE_2D, 0, format.cint, texWidth.GLsizei, texHeight.GLsizei, 0, format.GLenum, GL_UNSIGNED_BYTE, cast[pointer] (pixelData))
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        i.mSize.width = x.Coord
        i.mSize.height = y.Coord
        if data != pixelData:
            dealloc(pixelData)

    proc initWithContentsOfFile*(i: SelfContainedImage, path: string) =
        var x, y, comp: cint
        var data = stbi_load(path, addr x, addr y, addr comp, 0)
        i.initWithBitmap(data, x, y, comp)
        stbi_image_free(data)

    proc initWithResource*(i: SelfContainedImage, r: ResourceObj) =
        var x, y, comp: cint
        var data = stbi_load_from_memory(cast[ptr uint8](r.data), r.size.cint, addr x, addr y, addr comp, 0)
        i.initWithBitmap(data, x, y, comp)
        stbi_image_free(data)

    proc imageWithBitmap*(data: ptr uint8, x, y, comp: int): SelfContainedImage =
        result.new()
        result.initWithBitmap(data, x, y, comp)

    proc imageWithContentsOfFile*(path: string): SelfContainedImage =
        result.new()
        result.initWithContentsOfFile(path)

    proc imageWithResource*(r: ResourceObj): SelfContainedImage =
        result.new()
        result.initWithResource(r)

proc initWithResource*(i: SelfContainedImage, name: string) =
    when defined js:
        let nativeName : cstring = "res/" & name
        asm """
        `i`.__image = new Image();
        `i`.__image.crossOrigin = '';
        `i`.__image.src = `nativeName`;
        """
    else:
        let r = loadResourceByName(name)
        i.initWithResource(r[])
        freeResource(r)

proc imageWithResource*(name: string): SelfContainedImage =
    result = SelfContainedImage(imageCache.getOrDefault(name))
    if result.isNil:
        if warnWhenResourceNotCached:
            logi "WARNING: Image not found in cache: ", name
        result.new()
        result.initWithResource(name)

proc initSpriteImages(s: SpriteSheet, data: JsonNode) =
    let images = newTable[string, SpriteImage]()
    let fullOrigSize = if s.texture == 0:
            newSize(1, 1)
        else:
            newSize(s.mSize.width / s.sizeInTexels.width, s.mSize.height / s.sizeInTexels.height)
    for k, v in data["frames"]:
        let fr = v["frame"]
        let r = newRect(fr["x"].getFNum(), fr["y"].getFNum(), fr["w"].getFNum(), fr["h"].getFNum())
        var si : SpriteImage
        if not s.images.isNil: si = s.images[k]
        if si.isNil: si.new()
        si.spriteSheet = s
        si.mSize = r.size
        si.texCoords = [r.x / fullOrigSize.width, r.y / fullOrigSize.height, r.maxX / fullOrigSize.width, r.maxY / fullOrigSize.height]
        images[k] = si
    if not s.images.isNil:
        for k, v in s.images:
            if not images.hasKey(k): v.spriteSheet = nil
    s.images = images

proc newSpriteSheetWithResourceAndJson*(name: string, spriteDesc: JsonNode): SpriteSheet =
    result.new()
    result.initWithResource(name)
    result.initSpriteImages(spriteDesc)

# TODO: This isn't a place for parseJson
when defined(js):
    proc parseJson(s: Stream, filename: string): JsonNode =
        var fullJson = ""
        while true:
            const chunkSize = 1024
            let r = s.readStr(chunkSize)
            fullJson &= r
            if r.len != chunkSize: break
        result = parseJson(fullJson)

proc newSpriteSheetWithResourceAndJson*(imageFileName, jsonDescFileName: string): SpriteSheet =
    result.new()
    result.initWithResource(imageFileName)
    let res = result
    loadResourceAsync jsonDescFileName, proc(s: Stream) =
        let ssJson = parseJson(s, jsonDescFileName)
        res.initSpriteImages(ssJson)
        s.close()

proc imageWithSize*(size: Size): SelfContainedImage =
    result.new()
    result.mSize = size
    let texWidth = if isPowerOfTwo(size.width.int): size.width.int else: nextPowerOfTwo(size.width.int)
    let texHeight = if isPowerOfTwo(size.height.int): size.height.int else: nextPowerOfTwo(size.height.int)
    result.sizeInTexels.width = size.width / texWidth.Coord
    result.sizeInTexels.height = size.height / texHeight.Coord

method isLoaded*(i: Image): bool {.base.} = false

method isLoaded*(i: SelfContainedImage): bool =
    when defined js:
        result = i.texture != 0
        if not result:
            asm "`result` = `i`.__image.complete;"
    else:
        result = true

method isLoaded*(i: SpriteImage): bool = i.spriteSheet.isLoaded

method getTextureQuad*(i: Image, gl: GL, texCoords: var array[4, GLfloat]): GLuint {.base.} =
    raise newException(Exception, "Abstract method called!")

method getTextureQuad*(i: SelfContainedImage, gl: GL, texCoords: var array[4, GLfloat]): GLuint =
    when defined js:
        if i.texture == 0 and not gl.isNil:
            var width, height : Coord
            var loadingComplete = false
            asm """
            if (`i`.__image !== undefined) {
                `loadingComplete` = `i`.__image.complete;
                if (`loadingComplete`) {
                    `width` = `i`.__image.width;
                    `height` = `i`.__image.height;
                }
            }
            """
            if loadingComplete:
                i.texture = gl.createTexture()
                gl.bindTexture(gl.TEXTURE_2D, i.texture)
                {.emit: """
                `gl`.pixelStorei(`gl`.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
                """.}
                let texWidth = if isPowerOfTwo(width.int): width.int else: nextPowerOfTwo(width.int)
                let texHeight = if isPowerOfTwo(height.int): height.int else: nextPowerOfTwo(height.int)
                i.mSize.width = width
                i.mSize.height = height
                i.sizeInTexels.width = width / texWidth.Coord
                i.sizeInTexels.height = height / texHeight.Coord
                if texWidth != width.int or texHeight != height.int:
                    asm """
                    var canvas = document.createElement('canvas');
                    canvas.width = `texWidth`;
                    canvas.height = `texHeight`;
                    var ctx2d = canvas.getContext('2d');
                    ctx2d.globalCompositeOperation = "copy";
                    ctx2d.drawImage(`i`.__image, 0, 0);
                    `gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.RGBA, `gl`.RGBA, `gl`.UNSIGNED_BYTE, canvas);
                    """
                else:
                    asm "`gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.RGBA, `gl`.RGBA, `gl`.UNSIGNED_BYTE, `i`.__image);"
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
                gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    texCoords[0] = 0
    texCoords[1] = 0
    texCoords[2] = i.sizeInTexels.width
    texCoords[3] = i.sizeInTexels.height
    result = i.texture

proc fixupSpriteImages(s: SpriteSheet) =
    let fullOrigSize = newSize(s.mSize.width / s.sizeInTexels.width, s.mSize.height / s.sizeInTexels.height)

    for k, v in s.images:
        v.texCoords[0] /= fullOrigSize.width
        v.texCoords[1] /= fullOrigSize.height
        v.texCoords[2] /= fullOrigSize.width
        v.texCoords[3] /= fullOrigSize.height

method getTextureQuad*(i: SpriteSheet, gl: GL, texCoords: var array[4, GLfloat]): GLuint =
    let texWasnotReady = i.texture == 0
    result = procCall i.SelfContainedImage.getTextureQuad(gl, texCoords)
    if result != 0 and texWasnotReady:
        # Update images
        i.fixupSpriteImages()

method getTextureQuad*(i: SpriteImage, gl: GL, texCoords: var array[4, GLfloat]): GLuint =
    result = i.spriteSheet.getTextureQuad(gl, texCoords)
    texCoords = i.texCoords

method size*(i: Image): Size {.base.} = discard
method size*(i: SelfContainedImage): Size = i.mSize
method size*(i: SpriteImage): Size = i.mSize

proc subimageWithRect*(i: Image, r: Rect): SpriteImage =
    result.new()
    result.spriteSheet = i
    result.mSize = r.size
    result.texCoords = [r.x / i.size.width, r.y / i.size.height, r.maxX / i.size.width, r.maxY / i.size.height]

proc imageNamed*(s: SpriteSheet, name: string): SpriteImage =
    if not s.images.isNil:
        result = s.images[name]
    if result.isNil and s.texture == 0:
        result.new()
        result.spriteSheet = s
        if s.images.isNil: s.images = newTable[string, SpriteImage]()
        s.images[name] = result

type ImageFileFormat = enum tga, hdr, bmp, png

proc writeToFile(i: Image, path: string, format: ImageFileFormat) =
    when not defined(js) and not defined(android):
        var texCoords : array[4, GLfloat]
        let texture = i.getTextureQuad(nil, texCoords)
        glBindTexture(GL_TEXTURE_2D, texture)
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

registerResourcePreloader(["png", "jpg", "jpeg", "gif", "tif", "tiff", "tga"], proc(name: string, callback: proc()) =
    when defined(js):
        proc handler(r: ref RootObj) =
            var onImLoad = proc (im: ref RootObj) =
                var w, h: Coord
                {.emit: "`w` = im.width; `h` = im.height;".}
                let image = imageWithSize(newSize(w, h))
                {.emit: "`image`.__image = im;".}
                registerImageInCache(name, image)
                callback()
            {.emit:"""
            var im = new Image();
            im.onload = function(){`onImLoad`(im);};
            im.src = window.URL.createObjectURL(`r`);
            """.}

        loadJSResourceAsync(name, "blob", nil, nil, handler)
    else:
        registerImageInCache(name, imageWithResource(name))
        callback()
)
