import types
import opengl
import math, strutils, tables, json, streams
import portable_gl
import resource
import resource_cache
import system_logger

when not defined js:
    import load_image_impl
    import write_image_impl

type Image* = ref object of RootObj

type SelfContainedImage* = ref object of Image
    texture*: TextureRef
    mSize: Size
    texCoords*: array[4, GLfloat]
    framebuffer*: FramebufferRef
    mFilePath: string

type
    SpriteSheet* = ref object of SelfContainedImage
        images: TableRef[string, SpriteImage]

    SpriteImage* = ref object of Image
        spriteSheet*: Image
        mSubRect: Rect

    FixedTexCoordSpriteImage* = ref object of Image
        spriteSheet: Image
        mSize: Size
        texCoords: array[4, GLfloat]

template setupTexParams(gl: GL) =
    when defined(android) or defined(ios):
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    else:
        gl.generateMipmap(gl.TEXTURE_2D)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)

when not defined(js):
    include private.image_pvr

method setFilePath*(i: Image, path: string) {.base.} = discard
method setFilePath*(i: SelfContainedImage, path: string) =
    i.mFilePath = path

method filePath*(i: Image): string {.base.} = discard
method filePath*(i: SelfContainedImage): string = i.mFilePath

when not defined js:
    template offset(p: pointer, off: int): pointer =
        cast[pointer](cast[int](p) + off)

    proc loadBitmapToTexture(data: ptr uint8, x, y, comp: int, texture: var TextureRef, size: var Size, texCoords: var array[4, GLfloat]) =
        glGenTextures(1, addr texture)
        glBindTexture(GL_TEXTURE_2D, texture)
        let format : GLenum = case comp:
            of 1: GLenum(GL_ALPHA)
            of 2: GLenum(GL_LUMINANCE_ALPHA)
            of 3: GLenum(GL_RGB)
            of 4: GLenum(GL_RGBA)
            else: GLenum(0)
        size = newSize(x.Coord, y.Coord)
        let texWidth = if isPowerOfTwo(x): x.int else: nextPowerOfTwo(x)
        let texHeight = if isPowerOfTwo(y): y.int else: nextPowerOfTwo(y)

        var pixelData = data

        texCoords[2] = 1.0
        texCoords[3] = 1.0

        if texWidth != x or texHeight != y:
            let texRowWidth = texWidth * comp
            let newData = alloc(texRowWidth * texHeight)
            let rowWidth = x * comp
            for row in 0 .. <y:
                copyMem(offset(newData, row * texRowWidth), offset(data, row * rowWidth), rowWidth)
            pixelData = cast[ptr uint8](newData)
            texCoords[2] = x.Coord / texWidth.Coord
            texCoords[3] = y.Coord / texHeight.Coord

        glTexImage2D(GL_TEXTURE_2D, 0, format.cint, texWidth.GLsizei, texHeight.GLsizei, 0, format.GLenum, GL_UNSIGNED_BYTE, cast[pointer] (pixelData))
        setupTexParams(nil)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        size.width = x.Coord
        size.height = y.Coord
        if data != pixelData:
            dealloc(pixelData)

    proc initWithBitmap*(i: SelfContainedImage, data: ptr uint8, x, y, comp: int) =
        loadBitmapToTexture(data, x, y, comp, i.texture, i.mSize, i.texCoords)

    proc initWithContentsOfFile*(i: SelfContainedImage, path: string) =
        var x, y, comp: cint
        var data = stbi_load(path, addr x, addr y, addr comp, 0)
        i.initWithBitmap(data, x, y, comp)
        stbi_image_free(data)

        i.setFilePath(path)

    proc imageWithBitmap*(data: ptr uint8, x, y, comp: int): SelfContainedImage =
        result.new()
        result.initWithBitmap(data, x, y, comp)

    proc imageWithContentsOfFile*(path: string): SelfContainedImage =
        result.new()
        result.initWithContentsOfFile(path)

proc initWithResource*(i: SelfContainedImage, name: string) =
    when defined js:
        let nativeName : cstring = pathForResource(name)
        {.emit: """
        `i`.__image = new Image();
        `i`.__image.crossOrigin = '';
        `i`.__image.src = `nativeName`;
        """.}
    else:
        loadResourceAsync(name) do(s: Stream):
            var data = s.readAll()
            s.close()
            if name.endsWith(".pvr"):
                i.initWithPVR(data)
            else:
                var x, y, comp: cint

                var bitmap = stbi_load_from_memory(cast[ptr uint8](addr data[0]),
                    data.len.cint, addr x, addr y, addr comp, 0)
                i.initWithBitmap(bitmap, x, y, comp)
                stbi_image_free(bitmap)

            i.setFilePath(pathForResource(name))

proc imageWithResource*(name: string): SelfContainedImage =
    result = findCachedResource[SelfContainedImage](name)
    if result.isNil:
        resourceNotCached(name)
        result.new()
        result.initWithResource(name)

proc initSpriteImages(s: SpriteSheet, data: JsonNode) =
    let images = newTable[string, SpriteImage]()
    for k, v in data["frames"]:
        let fr = v["frame"]
        let r = newRect(fr["x"].getFNum(), fr["y"].getFNum(), fr["w"].getFNum(), fr["h"].getFNum())
        var si : SpriteImage
        if not s.images.isNil: si = s.images[k]
        if si.isNil: si.new()
        si.spriteSheet = s
        si.mSubRect = r
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
    result.texCoords[2] = size.width / texWidth.Coord
    result.texCoords[3] = size.height / texHeight.Coord

method isLoaded*(i: Image): bool {.base.} = false

method isLoaded*(i: SelfContainedImage): bool =
    when defined js:
        result = not i.texture.isEmpty
        if not result:
            asm "`result` = `i`.__image.complete;"
    else:
        result = true

method isLoaded*(i: SpriteImage): bool = i.spriteSheet.isLoaded
method isLoaded*(i: FixedTexCoordSpriteImage): bool = i.spriteSheet.isLoaded

method getTextureQuad*(i: Image, gl: GL, texCoords: var array[4, GLfloat]): TextureRef {.base.} =
    raise newException(Exception, "Abstract method called!")

method getTextureQuad*(i: SelfContainedImage, gl: GL, texCoords: var array[4, GLfloat]): TextureRef =
    when defined js:
        if i.texture.isEmpty and not gl.isNil:
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
                i.texCoords[2] = width / texWidth.Coord
                i.texCoords[3] = height / texHeight.Coord
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
                setupTexParams(gl)
    texCoords[0] = i.texCoords[0]
    texCoords[1] = i.texCoords[1]
    texCoords[2] = i.texCoords[2]
    texCoords[3] = i.texCoords[3]
    result = i.texture

method size*(i: Image): Size {.base.} = discard
method size*(i: SelfContainedImage): Size = i.mSize
method size*(i: SpriteImage): Size = i.mSubRect.size
method size*(i: FixedTexCoordSpriteImage): Size = i.mSize

method getTextureQuad*(i: SpriteImage, gl: GL, texCoords: var array[4, GLfloat]): TextureRef =
    result = i.spriteSheet.getTextureQuad(gl, texCoords)
    let superSize = i.spriteSheet.size
    let s0 = texCoords[0]
    let t0 = texCoords[1]
    let s1 = texCoords[2]
    let t1 = texCoords[3]
    texCoords[0] = s0 + (s1 - s0) * (i.mSubRect.x / superSize.width)
    texCoords[1] = t0 + (t1 - t0) * (i.mSubRect.y / superSize.height)
    texCoords[2] = s0 + (s1 - s0) * (i.mSubRect.maxX / superSize.width)
    texCoords[3] = t0 + (t1 - t0) * (i.mSubRect.maxY / superSize.height)

method getTextureQuad*(i: FixedTexCoordSpriteImage, gl: GL, texCoords: var array[4, GLfloat]): TextureRef =
    result = i.spriteSheet.getTextureQuad(gl, texCoords)
    texCoords[0] = i.texCoords[0]
    texCoords[1] = i.texCoords[1]
    texCoords[2] = i.texCoords[2]
    texCoords[3] = i.texCoords[3]

proc subimageWithRect*(i: Image, r: Rect): SpriteImage =
    result.new()
    result.spriteSheet = i
    result.mSubRect = r

proc subimageWithTexCoords*(i: Image, s: Size, texCoords: array[4, GLfloat]): FixedTexCoordSpriteImage =
    result.new()
    result.spriteSheet = i
    result.mSize = s
    result.texCoords = texCoords

proc imageNamed*(s: SpriteSheet, name: string): SpriteImage =
    if not s.images.isNil:
        result = s.images[name]
    if result.isNil and s.texture.isEmpty:
        result.new()
        result.spriteSheet = s
        if s.images.isNil: s.images = newTable[string, SpriteImage]()
        s.images[name] = result

template flipVertically*(i: SelfContainedImage) =
    swap(i.texCoords[1], i.texCoords[3])

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

const asyncResourceLoad = not defined(js) and not defined(android) and not defined(ios) and
    not defined(emscripten)

when asyncResourceLoad:
    import threadpool, sdl_perform_on_main_thread, sdl2
    import private.worker_queue

    var threadCtx : GlContextPtr
    var loadingQueue: WorkerQueue

    type ImageLoadingCtx = ref object
        path, name: string
        completionCallback: proc(i: SelfContainedImage)
        texture: TextureRef
        texCoords: array[4, GLfloat]
        size: Size
        glCtx: GlContextPtr
        wnd: WindowPtr

    proc loadComplete(ctx: pointer) {.cdecl.} =
        let c = cast[ImageLoadingCtx](ctx)
        GC_unref(c)
        var i : SelfContainedImage
        i.new()
        i.texture = c.texture
        i.texCoords = c.texCoords
        i.mSize = c.size
        c.completionCallback(i)

    var ctxIsCurrent = false

    proc loadResourceThreaded(ctx: pointer) {.cdecl.} =
        let c = cast[ImageLoadingCtx](ctx)
        if not ctxIsCurrent:
            if glMakeCurrent(c.wnd, c.glCtx) != 0:
                logi "Error in glMakeCurrent: ", getError()
            ctxIsCurrent = true
        let s = streamForResourceWithPath(c.path)
        var data = s.readAll()
        s.close()
        if c.name.endsWith(".pvr"):
            loadPVRDataToTexture(data, c.texture, c.size, c.texCoords)
        else:
            var x, y, comp: cint
            var bitmap = stbi_load_from_memory(cast[ptr uint8](addr data[0]),
                data.len.cint, addr x, addr y, addr comp, 0)
            loadBitmapToTexture(bitmap, x, y, comp, c.texture, c.size, c.texCoords)
            stbi_image_free(bitmap)

        let fenceId = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, GLbitfield(0))
        while true:
          let res = glClientWaitSync(fenceId, GL_SYNC_FLUSH_COMMANDS_BIT, GLuint64(5000000000)); # 5 Second timeout
          if res != GL_TIMEOUT_EXPIRED: break  # we ignore timeouts and wait until all OpenGL commands are processed!

        #discard glMakeCurrent(c.wnd, nil)
        let p = cast[pointer](loadComplete)
        performOnMainThread(cast[proc(data: pointer){.cdecl, gcsafe.}](p), ctx)

registerResourcePreloader(["png", "jpg", "jpeg", "gif", "tif", "tiff", "tga", "pvr"]) do(name: string, callback: proc(i: SelfContainedImage)):
    when defined(js):
        proc handler(r: ref RootObj) =
            var onImLoad = proc (im: ref RootObj) =
                var w, h: Coord
                {.emit: "`w` = im.width; `h` = im.height;".}
                let image = imageWithSize(newSize(w, h))
                {.emit: "`image`.__image = im;".}
                callback(image)
            {.emit:"""
            var im = new Image();
            im.onload = function(){`onImLoad`(im);};
            im.src = window.URL.createObjectURL(`r`);
            """.}

        loadJSResourceAsync(name, "blob", nil, nil, handler)
    elif asyncResourceLoad:
        var ctx: ImageLoadingCtx
        ctx.new()
        ctx.name = name
        ctx.path = pathForResource(name)
        ctx.completionCallback = callback
        let curWnd = glGetCurrentWindow()
        if threadCtx.isNil:
            let curCtx = glGetCurrentContext()
            threadCtx = glCreateContext(curWnd)
            discard glMakeCurrent(curWnd, curCtx)

        ctx.glCtx = threadCtx
        doAssert(not ctx.glCtx.isNil)
        ctx.wnd = curWnd
        GC_ref(ctx)

        if loadingQueue.isNil:
            loadingQueue = newWorkerQueue(1)

        loadingQueue.addTask(loadResourceThreaded, cast[pointer](ctx))
    else:
        callback(imageWithResource(name))
