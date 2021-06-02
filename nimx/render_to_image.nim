import image, types, context, portable_gl
import opengl

type
    RTIContext* = tuple
        clearColor: array[4, GLfloat]
        viewportSize: array[4, GLint]
        framebuffer: FramebufferRef
        bStencil: bool
        skipClear: bool

    GlFrameState* {.deprecated.} = RTIContext

    ImageRenderTarget* = ref ImageRenderTargetObj
    ImageRenderTargetObj = object
        gfxCtx*: GraphicsContext
        framebuffer*: FramebufferRef
        depthbuffer*: RenderbufferRef
        stencilbuffer*: RenderbufferRef
        vpX*, vpY*: GLint # Viewport geometry
        vpW*, vpH*: GLsizei
        texWidth*, texHeight*: int16
        needsDepthStencil*: bool

proc disposeObj(r: var ImageRenderTargetObj) =
    let gl = r.gfxCtx.gl
    if r.framebuffer != invalidFrameBuffer:
        gl.deleteFramebuffer(r.framebuffer)
        r.framebuffer = invalidFrameBuffer
    if r.depthbuffer != invalidRenderbuffer:
        gl.deleteRenderbuffer(r.depthbuffer)
        r.depthbuffer = invalidRenderbuffer
    if r.stencilbuffer != invalidRenderbuffer:
        gl.deleteRenderbuffer(r.stencilbuffer)
        r.stencilbuffer = invalidRenderbuffer

proc dispose*(r: ImageRenderTarget) = disposeObj(r[])

when defined(gcDestructors):
    proc `=destroy`(r: var ImageRenderTargetObj) = disposeObj(r)

proc newImageRenderTarget*(ctx: GraphicsContext, needsDepthStencil: bool = true): ImageRenderTarget {.inline.} =
    when defined(js):
        result.new()
    else:
        when defined(gcDestructors):
            result.new()
        else:
            result.new(dispose)
    result.gfxCtx = ctx
    result.needsDepthStencil = needsDepthStencil

proc init(rt: ImageRenderTarget, texWidth, texHeight: int16) =
    let gl = rt.gfxCtx.gl
    rt.texWidth = texWidth
    rt.texHeight = texHeight
    rt.framebuffer = gl.createFramebuffer()

    if rt.needsDepthStencil:
        let oldFramebuffer = gl.boundFramebuffer()
        let oldRB = gl.boundRenderBuffer()
        gl.bindFramebuffer(gl.FRAMEBUFFER, rt.framebuffer)

        let depthBuffer = gl.createRenderbuffer()
        gl.bindRenderbuffer(gl.RENDERBUFFER, depthBuffer)
        let depthStencilFormat = when defined(js) or defined(emscripten): gl.DEPTH_STENCIL else: gl.DEPTH24_STENCIL8

        # The following tries to use DEPTH_STENCIL_ATTACHMENT, but it may fail on some devices,
        # so for those we're creating a separate stencil buffer.
        var needsStencil = false
        when NoAutoGLerrorCheck:
            discard gl.getError()
            gl.renderbufferStorage(gl.RENDERBUFFER, depthStencilFormat, texWidth, texHeight)
            if gl.getError() == 0.GLenum:
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, depthBuffer)
            else:
                gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, texWidth, texHeight)
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depthBuffer)
                needsStencil = true
        else:
            try:
                gl.renderbufferStorage(gl.RENDERBUFFER, depthStencilFormat, texWidth, texHeight)
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, depthBuffer)
            except:
                gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, texWidth, texHeight)
                gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, depthBuffer)
                needsStencil = true

        rt.depthbuffer = depthBuffer

        if needsStencil:
            let stencilBuffer = gl.createRenderbuffer()
            gl.bindRenderbuffer(gl.RENDERBUFFER, stencilBuffer)
            gl.renderbufferStorage(gl.RENDERBUFFER, gl.STENCIL_INDEX8, texWidth, texHeight)
            gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.STENCIL_ATTACHMENT, gl.RENDERBUFFER, stencilBuffer)
            rt.stencilbuffer = stencilBuffer

        gl.bindFramebuffer(gl.FRAMEBUFFER, oldFramebuffer)
        gl.bindRenderbuffer(gl.RENDERBUFFER, oldRB)

proc resize(rt: ImageRenderTarget, texWidth, texHeight: int16) =
    let gl = rt.gfxCtx.gl
    rt.texWidth = max(rt.texWidth, texWidth)
    rt.texHeight = max(rt.texHeight, texHeight)

    if rt.depthbuffer != invalidRenderbuffer:
        let depthStencilFormat = if rt.stencilbuffer == invalidRenderbuffer:
                when defined(js) or defined(emscripten): gl.DEPTH_STENCIL else: gl.DEPTH24_STENCIL8
            else:
                gl.DEPTH_COMPONENT16

        gl.bindRenderbuffer(gl.RENDERBUFFER, rt.depthbuffer)
        gl.renderbufferStorage(gl.RENDERBUFFER, depthStencilFormat, rt.texWidth, rt.texHeight)

    if rt.stencilBuffer != invalidRenderbuffer:
        gl.bindRenderbuffer(gl.RENDERBUFFER, rt.stencilBuffer)
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.STENCIL_INDEX8, rt.texWidth, rt.texHeight)

proc setImage*(rt: ImageRenderTarget, i: SelfContainedImage) =
    assert(i.texWidth != 0 and i.texHeight != 0)

    let gl = rt.gfxCtx.gl
    var texCoords: array[4, GLfloat]
    var texture = i.getTextureQuad(gl, texCoords)
    if texture.isEmpty:
        texture = gl.createTexture()
        i.texture = texture
        gl.bindTexture(gl.TEXTURE_2D, texture)
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA.GLint, i.texWidth, i.texHeight, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)

    if rt.framebuffer.isEmpty:
        rt.init(i.texWidth, i.texHeight)
    elif rt.texWidth < i.texWidth or rt.texHeight < i.texHeight:
        rt.resize(i.texWidth, i.texHeight)

    let br = i.backingRect()

    rt.vpX = br.x.GLint
    rt.vpY = br.y.GLint
    rt.vpW = br.width.GLsizei
    rt.vpH = br.height.GLsizei

    let oldFramebuffer = gl.boundFramebuffer()

    gl.bindFramebuffer(gl.FRAMEBUFFER, rt.framebuffer)
    gl.bindTexture(gl.TEXTURE_2D, texture)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0)

    gl.bindFramebuffer(gl.FRAMEBUFFER, oldFramebuffer)

proc beginDraw*(t: ImageRenderTarget, state: var RTIContext) =
    assert(t.vpW != 0 and t.vpH != 0)

    let gl = t.gfxCtx.gl
    state.framebuffer = gl.boundFramebuffer()
    state.viewportSize = gl.getViewport()
    state.bStencil = gl.getParamb(gl.STENCIL_TEST)
    if not state.skipClear:
        gl.getClearColor(state.clearColor)

    gl.bindFramebuffer(gl.FRAMEBUFFER, t.framebuffer)
    gl.viewport(t.vpX, t.vpY, t.vpW, t.vpH)
    if not state.skipClear:
        gl.stencilMask(0xFF) # Android requires setting stencil mask to clear
        gl.clearColor(0, 0, 0, 0)
        gl.clear(gl.COLOR_BUFFER_BIT or gl.DEPTH_BUFFER_BIT or gl.STENCIL_BUFFER_BIT)
        gl.stencilMask(0x00) # Android requires setting stencil mask to clear
        gl.disable(gl.STENCIL_TEST)

proc beginDrawNoClear*(t: ImageRenderTarget, state: var RTIContext) =
    state.skipClear = true
    t.beginDraw(state)

proc endDraw*(t: ImageRenderTarget, state: var RTIContext) =
    let gl = t.gfxCtx.gl
    if state.bStencil:
        gl.enable(gl.STENCIL_TEST)
    if not state.skipClear:
        gl.clearColor(state.clearColor[0], state.clearColor[1], state.clearColor[2], state.clearColor[3])
    gl.viewport(state.viewportSize)
    gl.bindFramebuffer(gl.FRAMEBUFFER, state.framebuffer)

template draw*(rt: ImageRenderTarget, sci: SelfContainedImage, drawBody: untyped) =
    var gfs: RTIContext
    rt.setImage(sci)
    rt.beginDraw(gfs)

    rt.gfxCtx.withTransform ortho(0, sci.size.width, sci.size.height, 0, -1, 1):
        drawBody

    rt.endDraw(gfs)
    # OpenGL framebuffer coordinate system is flipped comparing to how we load
    # and handle the rest of images. Compensate for that by flipping texture
    # coords here.
    if not sci.flipped:
        sci.flipVertically()

template draw*(ctx: GraphicsContext, sci: SelfContainedImage, drawBody: untyped) =
    let rt = newImageRenderTarget(ctx)
    rt.draw(sci, drawBody)
    rt.dispose()

proc draw*(ctx: GraphicsContext, sci: SelfContainedImage, drawProc: proc()) {.deprecated.} =
    draw ctx, sci:
        drawProc()
