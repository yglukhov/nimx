import types
import opengl
import math, strutils, tables, json, streams, logging
import portable_gl
import resource
import resource_cache
import system_logger
import mini_profiler

import nimx.assets.asset_loading
import nimx.assets.url_stream
import nimx.assets.asset_manager # Required to register "res" url handler

const web = defined(js) or defined(emscripten)

when web:
    import jsbind
else:
    import load_image_impl
    import write_image_impl

type
    Image* = ref object of RootObj
        texCoords*: array[4, GLfloat]
        mSize: Size
        texWidth*, texHeight*: int16

    SelfContainedImage* = ref object of Image
        texture*: TextureRef
        mFilePath: string
        mRenderTarget*: ImageRenderTarget

    FixedTexCoordSpriteImage* = ref object of Image
        spriteSheet: Image

    ImageRenderTarget* = ref object # This will be moved to render_to_image soon
        framebuffer*: FramebufferRef
        depthbuffer*: RenderbufferRef
        stencilbuffer*: RenderbufferRef
        vpX*, vpY*: GLint # Viewport geometry
        vpW*, vpH*: GLsizei
        texWidth*, texHeight*: int16
        needsDepthStencil*: bool

template setupTexParams(gl: GL) =
    when defined(android) or defined(ios):
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    else:
        gl.generateMipmap(gl.TEXTURE_2D)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)

when not web:
    include private.image_pvr

method setFilePath*(i: Image, path: string) {.base.} = discard
method setFilePath*(i: SelfContainedImage, path: string) =
    i.mFilePath = path

method filePath*(i: Image): string {.base.} = discard
method filePath*(i: SelfContainedImage): string = i.mFilePath

when not defined(js):
    let totalImages = sharedProfiler().newDataSource(int, "Images")
    proc finalize(i: SelfContainedImage) =
        if i.texture != invalidTexture:
            glDeleteTextures(1, addr i.texture)
        dec totalImages

proc newSelfContainedImage(): SelfContainedImage {.inline.} =
    when defined(js):
        result.new()
    else:
        inc totalImages
        result.new(finalize)

proc framebuffer*(i: SelfContainedImage): FramebufferRef {.inline, deprecated.} =
    let rt = i.mRenderTarget
    if not rt.isNil:
        result = rt.framebuffer

proc `framebuffer=`*(i: SelfContainedImage, b: FramebufferRef) {.inline, deprecated.} =
    let rt = i.mRenderTarget
    assert(b == invalidFrameBuffer or not rt.isNil)
    if not rt.isNil:
        rt.framebuffer = b

proc renderbuffer*(i: SelfContainedImage): RenderbufferRef {.inline, deprecated.} =
    let rt = i.mRenderTarget
    if not rt.isNil:
        result = rt.depthbuffer

proc `renderbuffer=`*(i: SelfContainedImage, b: RenderbufferRef) {.inline, deprecated.} =
    let rt = i.mRenderTarget
    assert(b == invalidRenderbuffer or not rt.isNil)
    if not rt.isNil:
        rt.depthbuffer = b

when not web:
    template offset(p: pointer, off: int): pointer =
        cast[pointer](cast[int](p) + off)

    proc loadBitmapToTexture(data: ptr uint8, x, y, comp: int, texture: var TextureRef, size: var Size, texCoords: var array[4, GLfloat], texWidth, texHeight: var int16) =
        glGenTextures(1, addr texture)
        glBindTexture(GL_TEXTURE_2D, texture)
        let format : GLenum = case comp:
            of 1: GL_ALPHA
            of 2: GL_LUMINANCE_ALPHA
            of 3: GL_RGB
            of 4: GL_RGBA
            else: GLenum(0)
        size = newSize(x.Coord, y.Coord)
        texWidth = nextPowerOfTwo(x).int16
        texHeight = nextPowerOfTwo(y).int16

        var pixelData = data

        texCoords[2] = 1.0
        texCoords[3] = 1.0

        if texWidth != x or texHeight != y:
            let texRowWidth = texWidth * comp
            let newData = alloc(texRowWidth * texHeight)
            let rowWidth = x * comp
            let xExtrusion = min(2, texWidth - x)
            let yExtrusion = min(2, texHeight - y)

            for row in 0 .. <y:
                copyMem(offset(newData, row * texRowWidth), offset(data, row * rowWidth), rowWidth)
                let lastRowPixel = offset(data, row * rowWidth - comp)
                for i in 0 ..< xExtrusion:
                    copyMem(offset(newData, row * texRowWidth + rowWidth + i * comp), lastRowPixel, comp)

            let lastRow = offset(data, (y - 1) * rowWidth)
            for i in 0 ..< yExtrusion:
                copyMem(offset(newData, (y + i) * texRowWidth), lastRow, rowWidth)

            pixelData = cast[ptr uint8](newData)
            texCoords[2] = x.Coord / texWidth.Coord
            texCoords[3] = y.Coord / texHeight.Coord

        glTexImage2D(GL_TEXTURE_2D, 0, format.cint, texWidth.GLsizei, texHeight.GLsizei, 0, format, GL_UNSIGNED_BYTE, cast[pointer](pixelData))
        setupTexParams(nil)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)

        size.width = x.Coord
        size.height = y.Coord
        if data != pixelData:
            dealloc(pixelData)

    proc initWithBitmap*(i: SelfContainedImage, data: ptr uint8, x, y, comp: int) =
        loadBitmapToTexture(data, x, y, comp, i.texture, i.mSize, i.texCoords, i.texWidth, i.texHeight)

    proc initWithContentsOfFile*(i: SelfContainedImage, path: string) =
        var x, y, comp: cint
        var data = stbi_load(path, addr x, addr y, addr comp, 0)
        if data.isNil:
            raise newException(Exception, "Could not load image from: " & path)

        i.initWithBitmap(data, x, y, comp)
        stbi_image_free(data)
        i.setFilePath(path)

    proc imageWithBitmap*(data: ptr uint8, x, y, comp: int): SelfContainedImage =
        result = newSelfContainedImage()
        result.initWithBitmap(data, x, y, comp)

    proc imageWithContentsOfFile*(path: string): SelfContainedImage =
        result = newSelfContainedImage()
        result.initWithContentsOfFile(path)

when not web:
    proc initWithStream(i: SelfContainedImage, s: Stream) =
        var data = s.readAll()
        s.close()
        if isPVRData(data):
            i.initWithPVR(cast[ptr uint8](addr data[0]))
        else:
            var x, y, comp: cint

            var bitmap = stbi_load_from_memory(cast[ptr uint8](addr data[0]),
                data.len.cint, addr x, addr y, addr comp, 0)
            i.initWithBitmap(bitmap, x, y, comp)
            stbi_image_free(bitmap)

proc imageWithResource*(name: string): Image =
    result = sharedAssetManager().cachedAsset(Image, name)

proc imageWithSize*(size: Size): SelfContainedImage =
    result = newSelfContainedImage()
    result.mSize = size
    result.texWidth = nextPowerOfTwo(size.width.int).int16
    result.texHeight = nextPowerOfTwo(size.height.int).int16
    result.texCoords[2] = size.width / result.texWidth.Coord
    result.texCoords[3] = size.height / result.texHeight.Coord

method isLoaded*(i: Image): bool {.base.} = false

method isLoaded*(i: SelfContainedImage): bool =
    when defined(js):
        result = not i.texture.isEmpty
        if not result:
            asm "`result` = `i`.__image.complete;"
    else:
        result = true

method isLoaded*(i: FixedTexCoordSpriteImage): bool = i.spriteSheet.isLoaded

method getTextureQuad*(i: Image, gl: GL, texCoords: var array[4, GLfloat]): TextureRef {.base.} =
    raise newException(Exception, "Abstract method called!")

when defined(js):
    proc initWithJSImage(i: SelfContainedImage, gl: GL, jsImg: RootRef) =
        var width, height : Coord
        {.emit: """
        `width` = `jsImg`.width;
        `height` = `jsImg`.height;
        """.}

        i.texture = gl.createTexture()
        gl.bindTexture(gl.TEXTURE_2D, i.texture)
        {.emit: """
        `gl`.pixelStorei(`gl`.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
        """.}
        let texWidth = nextPowerOfTwo(width.int)
        let texHeight = nextPowerOfTwo(height.int)
        i.texWidth = texWidth.int16
        i.texHeight = texHeight.int16
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
            {.emit:"`gl`.texImage2D(`gl`.TEXTURE_2D, 0, `gl`.RGBA, `gl`.RGBA, `gl`.UNSIGNED_BYTE, `i`.__image);".}
        setupTexParams(gl)

        let err = gl.getError()
        if err != 0.GLenum:
            logi "GL error in texture load: ", err.int.toHex(), ": ", if i.mFilePath.isNil: "nil" else: i.mFilePath

method getTextureQuad*(i: SelfContainedImage, gl: GL, texCoords: var array[4, GLfloat]): TextureRef =
    when defined js:
        if i.texture.isEmpty and not gl.isNil:
            var loadingComplete = false
            var jsImg: RootRef
            asm """
            if (`i`.__image !== undefined) {
                `jsImg` = `i`.__image;
                `loadingComplete` = `i`.__image.complete;
            }
            """
            if loadingComplete:
                i.initWithJSImage(gl, jsImg)

    texCoords[0] = i.texCoords[0]
    texCoords[1] = i.texCoords[1]
    texCoords[2] = i.texCoords[2]
    texCoords[3] = i.texCoords[3]
    result = i.texture

proc size*(i: Image): Size {.inline.} = i.mSize

method getTextureQuad*(i: FixedTexCoordSpriteImage, gl: GL, texCoords: var array[4, GLfloat]): TextureRef =
    result = i.spriteSheet.getTextureQuad(gl, texCoords)
    texCoords[0] = i.texCoords[0]
    texCoords[1] = i.texCoords[1]
    texCoords[2] = i.texCoords[2]
    texCoords[3] = i.texCoords[3]

proc subimageWithTexCoords*(i: Image, s: Size, texCoords: array[4, GLfloat]): FixedTexCoordSpriteImage =
    result.new()
    result.spriteSheet = i
    result.mSize = s
    result.texCoords = texCoords
    result.texWidth = i.texWidth
    result.texHeight = i.texHeight

proc flipVertically*(i: SelfContainedImage) {.inline.} =
    swap(i.texCoords[1], i.texCoords[3])

proc flipped*(i: Image): bool {.inline.} = i.texCoords[1] > i.texCoords[3]

proc backingSize*(i: Image): Size =
    result.width = i.texWidth.float32 * (i.texCoords[2] - i.texCoords[0])
    result.height = i.texHeight.float32 * abs(i.texCoords[1] - i.texCoords[3])

proc backingRect*(i: Image): Rect =
    result.origin.x = i.texWidth.float32 * i.texCoords[0]
    result.origin.y = i.texHeight.float32 * min(i.texCoords[0], i.texCoords[3])
    result.size = i.backingSize

proc resetToSize*(i: SelfContainedImage, size: Size, gl: GL) =
    i.mSize = size

    let flipped = i.flipped

    let texWidth = nextPowerOfTwo(size.width.int)
    let texHeight = nextPowerOfTwo(size.height.int)
    i.texWidth = texWidth.int16
    i.texHeight = texHeight.int16

    i.texCoords[0] = 0
    i.texCoords[1] = 0
    i.texCoords[2] = size.width / texWidth.Coord
    i.texCoords[3] = size.height / texHeight.Coord

    if flipped:
        i.flipVertically()

    if i.texture != invalidTexture:
        gl.bindTexture(gl.TEXTURE_2D, i.texture)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA.GLint, texWidth.GLsizei, texHeight.GLsizei, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)

proc generateMipmap*(i: SelfContainedImage, gl: GL) =
    if i.texture != invalidTexture:
        gl.bindTexture(gl.TEXTURE_2D, i.texture)
        gl.generateMipmap(gl.TEXTURE_2D)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_NEAREST)

when not web:
    type ImageFileFormat = enum tga, hdr, bmp, png

    proc writeToFile(i: Image, path: string, format: ImageFileFormat) =
        when not defined(js) and not defined(emscripten) and not defined(android):
            var texCoords : array[4, GLfloat]
            let texture = i.getTextureQuad(nil, texCoords)
            glBindTexture(GL_TEXTURE_2D, texture)
            var w, h, fmti: GLint
            glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH, addr w)
            glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, addr h)
            glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_INTERNAL_FORMAT, addr fmti)

            var fmt = GLenum(fmti)
            var comp = 0
            case fmt
            of GL_RGB, GL_RGB8:
                comp = 3
                fmt = GL_RGB
            of GL_RGBA, GL_RGBA8:
                comp = 4
                fmt = GL_RGBA
            else: discard

            if comp == 0:
                raise newException(Exception, "Unsupported format: " & $int(fmt))

            var data = alloc(comp * w * h)
            glGetTexImage(GL_TEXTURE_2D, 0, fmt, GL_UNSIGNED_BYTE, data)

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

const asyncResourceLoad = not defined(js) and not defined(emscripten) and not defined(nimxAvoidSDL)

when asyncResourceLoad:
    const loadAsyncTextureInMainThread = defined(android) or defined(ios)

    import threadpool, perform_on_main_thread, sdl2
    import private.worker_queue

    var threadCtx : GlContextPtr
    var loadingQueue: WorkerQueue

    type ImageLoadingCtx = ref object
        url: string
        completionCallback: proc(i: Image)
        when loadAsyncTextureInMainThread:
            data: ptr uint8
            width: cint
            height: cint
            comp: cint
            compressed: bool
        else:
            texCoords: array[4, GLfloat]
            size: Size
            texture: TextureRef
            glCtx: GlContextPtr
            wnd: WindowPtr
            texWidth, texHeight: int16

    proc loadComplete(ctx: pointer) {.cdecl.} =
        let c = cast[ImageLoadingCtx](ctx)
        GC_unref(c)
        var i = newSelfContainedImage()
        when loadAsyncTextureInMainThread:
            if c.compressed:
                i.initWithPVR(c.data)
                deallocShared(c.data)
            else:
                i.initWithBitmap(c.data, c.width, c.height, c.comp)
                stbi_image_free(c.data)
        else:
            i.texture = c.texture
            i.texCoords = c.texCoords
            i.mSize = c.size
            i.texWidth = c.texWidth
            i.texHeight = c.texHeight
        i.setFilePath(c.url)
        c.completionCallback(i)

    var ctxIsCurrent = false

    proc loadResourceThreaded(ctx: pointer) {.cdecl.} =
        var url = cast[ImageLoadingCtx](ctx).url
        openStreamForUrl(url) do(s: Stream, err: string):
            if not err.isNil:
                logi "Could not load url: ", url
                logi "Error: ", err
            var data = s.readAll()
            s.close()

            let c = cast[ImageLoadingCtx](ctx)

            when loadAsyncTextureInMainThread:
                if url.endsWith(".pvr"):
                    c.data = cast[ptr uint8](allocShared(data.len))
                    copyMem(c.data, addr data[0], data.len)
                    c.compressed = true
                else:
                    c.data = stbi_load_from_memory(cast[ptr uint8](addr data[0]),
                        data.len.cint, addr c.width, addr c.height, addr c.comp, 0)
            else:
                if not ctxIsCurrent:
                    if glMakeCurrent(c.wnd, c.glCtx) != 0:
                        logi "Error in glMakeCurrent: ", getError()
                    ctxIsCurrent = true
                if url.endsWith(".pvr"):
                    loadPVRDataToTexture(cast[ptr uint8](addr data[0]), c.texture, c.size, c.texCoords)
                else:
                    var x, y, comp: cint
                    var bitmap = stbi_load_from_memory(cast[ptr uint8](addr data[0]),
                        data.len.cint, addr x, addr y, addr comp, 0)
                    loadBitmapToTexture(bitmap, x, y, comp, c.texture, c.size, c.texCoords, c.texWidth, c.texHeight)
                    stbi_image_free(bitmap)

                let fenceId = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, GLbitfield(0))
                while true:
                    let res = glClientWaitSync(fenceId, GL_SYNC_FLUSH_COMMANDS_BIT, GLuint64(5000000000)); # 5 Second timeout
                    if res != GL_TIMEOUT_EXPIRED: break  # we ignore timeouts and wait until all OpenGL commands are processed!

            #discard glMakeCurrent(c.wnd, nil)
            let p = cast[pointer](loadComplete)
            performOnMainThread(cast[proc(data: pointer){.cdecl, gcsafe.}](p), ctx)

when defined(emscripten):
    import jsbind.emscripten

    type ImageLoadingCtx = ref object
        path: string
        callback: proc(i: Image)
        image: SelfContainedImage

    proc nimxImagePrepareTexture(c: pointer, x, y, texWidth, texHeight: cint) {.EMSCRIPTEN_KEEPALIVE.} =
        handleJSExceptions:
            let ctx = cast[ImageLoadingCtx](c)
            ctx.image = newSelfContainedImage()
            glGenTextures(1, addr ctx.image.texture)
            glBindTexture(GL_TEXTURE_2D, ctx.image.texture)
            ctx.image.mSize = newSize(x.Coord, y.Coord)
            ctx.image.texWidth = texWidth.int16
            ctx.image.texHeight = texHeight.int16

            ctx.image.texCoords[2] = 1.0
            ctx.image.texCoords[3] = 1.0

            if texWidth != x or texHeight != y:
                ctx.image.texCoords[2] = x.Coord / texWidth.Coord
                ctx.image.texCoords[3] = y.Coord / texHeight.Coord

    proc nimxImageLoaded(c: pointer) {.EMSCRIPTEN_KEEPALIVE.} =
        handleJSExceptions:
            let ctx = cast[ImageLoadingCtx](c)
            setupTexParams(nil)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
            GC_unref(ctx)
            ctx.image.setFilePath(ctx.path)
            ctx.callback(ctx.image)

    proc nimxImageLoadError(c: pointer) {.EMSCRIPTEN_KEEPALIVE.} =
        handleJSExceptions:
            let ctx = cast[ImageLoadingCtx](c)
            GC_unref(ctx)
            logi "Error loading image: ", ctx.path
            ctx.callback(nil)

    proc nimxNextPowerOf2(x: cint): cint {.EMSCRIPTEN_KEEPALIVE,} =
        nextPowerOfTwo(x).cint

    proc loadImageFromURL*(url: string, callback: proc(i: Image)) =
        var ctx: ImageLoadingCtx
        ctx.new()
        ctx.path = url
        ctx.callback = callback
        GC_ref(ctx)
        discard EM_ASM_INT("""
        var i = new Image();
        i.crossOrigin = '';
        i.onload = function () {
            try {
                var texWidth = _nimxNextPowerOf2(i.width);
                var texHeight = _nimxNextPowerOf2(i.height);
                _nimxImagePrepareTexture($0, i.width, i.height, texWidth, texHeight);
                GLctx.pixelStorei(GLctx.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
                if (texWidth != i.width || texHeight != i.height) {
                    var canvas = document.createElement('canvas');
                    canvas.width = texWidth;
                    canvas.height = texHeight;
                    var ctx2d = canvas.getContext('2d');
                    ctx2d.globalCompositeOperation = "copy";
                    ctx2d.drawImage(i, 0, 0);
                    GLctx.texImage2D(GLctx.TEXTURE_2D, 0, GLctx.RGBA, GLctx.RGBA, GLctx.UNSIGNED_BYTE, canvas);
                }
                else {
                    GLctx.texImage2D(GLctx.TEXTURE_2D, 0, GLctx.RGBA, GLctx.RGBA, GLctx.UNSIGNED_BYTE, i);
                }
                _nimxImageLoaded($0);
            }
            catch(e) {
                _nimem_e(e); // This function is defined in `jsbind.emscripten`
            }
        };
        var url = UTF8ToString($1);
        i.onerror = function() {
            console.log("image load failed: " + url);
            _nimxImageLoadError($0);
        };
        i.src = url;
        """, cast[pointer](ctx), cstring(ctx.path))

    proc nimxImageLoadFromURL*(url: string, name: string, callback: proc(i: SelfContainedImage)) {.deprecated.} =
        loadImageFromURL(url) do(i: Image):
            if i.isNil:
                callback(nil)
            else:
                callback(SelfContainedImage(i))

elif defined(js):
    proc loadImageFromURL*(url: string, callback: proc(i: Image)) =
        let nativeURL: cstring = url
        let onLoad = proc(jsImg: RootRef) =
            if jsImg.isNil:
                callback(nil)
            else:
                let i = newSelfContainedImage()
                i.setFilePath(url)
                {.emit: """
                `i`.__image = `jsImg`;
                """.}
                callback(i)

        {.emit: """
        var jsImg = new Image();
        jsImg.crossOrigin = '';
        jsImg.src = `nativeURL`;
        jsImg.onload = function(){`onLoad`(jsImg)};
        jsImg.onerror = function(){`onLoad`(null)};
        """.}

else:
    import nimx.http_request
    proc loadImageFromURL*(url: string, callback: proc(i: Image)) =
        sendRequest("GET", url, nil, []) do(r: Response):
            if r.statusCode >= 200 and r.statusCode < 300:
                let i = newSelfContainedImage()
                var x, y, comp: cint
                var bitmap = stbi_load_from_memory(cast[ptr uint8](unsafeAddr r.body[0]),
                        r.body.len.cint, addr x, addr y, addr comp, 0)
                i.initWithBitmap(bitmap, x, y, comp)
                stbi_image_free(bitmap)
                i.setFilePath(url)
                callback(i)
            else:
                callback(nil)

proc loadImageFromURL*(url: string, callback: proc(i: SelfContainedImage)) {.deprecated.} =
    loadImageFromURL(url) do(i: Image):
        if i.isNil:
            callback(nil)
        else:
            callback(SelfContainedImage(i))

when defined(js) or defined(emscripten):
    registerAssetLoader(["file", "http", "https"], ["png", "jpg", "jpeg", "gif", "tif", "tiff", "tga"]) do(url: string, handler: proc(i: Image)):
        loadImageFromURL(url, handler)
else:
    registerAssetLoader(["png", "jpg", "jpeg", "gif", "tif", "tiff", "tga", "pvr"]) do(url: string, handler: proc(i: Image)):
        when asyncResourceLoad:
            var ctx: ImageLoadingCtx
            ctx.new()
            ctx.url = url
            ctx.completionCallback = handler
            when not loadAsyncTextureInMainThread:
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
            openStreamForURL(url) do(s: Stream, err: string):
                let i = newSelfContainedImage()
                i.initWithStream(s)
                i.setFilePath(url)
                handler(i)

registerResourcePreloader(["png", "jpg", "jpeg", "gif", "tif", "tiff", "tga", "pvr"]) do(name: string, callback: proc(i: SelfContainedImage)):
    sharedAssetManager().getAssetAtPath(name, false) do(i: Image, err: string):
        if i.isNil:
            callback(nil)
        else:
            callback(SelfContainedImage(i))
