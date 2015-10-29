import image
import portable_gl
import context
import math
import opengl

proc bindFramebuffer*(gl: GL, i: SelfContainedImage) =
    if i.framebuffer == 0:
        var texCoords : array[4, GLfloat]
        var texture = i.getTextureQuad(gl, texCoords)

        if texture == 0:
            texture = gl.createTexture()
            i.texture = texture

        i.framebuffer = gl.createFramebuffer()
        gl.bindFramebuffer(gl.FRAMEBUFFER, i.framebuffer)
        gl.bindTexture(gl.TEXTURE_2D, texture)
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

        let texWidth = if isPowerOfTwo(i.size.width.int): i.size.width.int else: nextPowerOfTwo(i.size.width.int)
        let texHeight = if isPowerOfTwo(i.size.height.int): i.size.height.int else: nextPowerOfTwo(i.size.height.int)

        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA.GLint, texWidth.GLsizei, texHeight.GLsizei, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture, 0)
        let depthBuffer = gl.createRenderbuffer()
        gl.bindRenderbuffer(gl.RENDERBUFFER, depthBuffer)

        let depthStencilFormat = when defined(js): gl.DEPTH_STENCIL else: gl.DEPTH24_STENCIL8

        gl.renderbufferStorage(gl.RENDERBUFFER, depthStencilFormat, texWidth.GLsizei, texHeight.GLsizei)
        gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, depthBuffer)
    else:
        gl.bindFramebuffer(gl.FRAMEBUFFER, i.framebuffer)

proc draw*(i: Image, drawProc: proc()) =
    let gl = sharedGL()

    let oldFb = gl.getParami(gl.FRAMEBUFFER_BINDING).GLuint
    let oldViewport = gl.getViewport()
    let oldRb = gl.getParami(gl.RENDERBUFFER_BINDING).GLuint
    var oldClearColor : array[4, GLfloat]
    gl.getClearColor(oldClearColor)

    let sci = SelfContainedImage(i)
    if sci.isNil:
        raise newException(Exception, "Not implemented: Can draw only to SelfContainedImage")
    bindFramebuffer(gl, sci)

    gl.viewport(0, 0, i.size.width.GLsizei, i.size.height.GLsizei)
    gl.stencilMask(0xFF) # Android requires setting stencil mask to clear
    gl.clearColor(0, 0, 0, 0)
    gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT)
    gl.stencilMask(0x00) # Android requires setting stencil mask to clear

    gl.disable(gl.STENCIL_TEST)

    # The coordinate system is flipped vertically. The following ortho is a hack. Why??
    currentContext().withTransform ortho(0, i.size.width, 0, i.size.height, -1, 1):
        drawProc()

    gl.clearColor(oldClearColor[0], oldClearColor[1], oldClearColor[2], oldClearColor[3])

    viewport(gl, oldViewport)
    gl.bindRenderbuffer(gl.RENDERBUFFER, oldRb)
    gl.bindFramebuffer(gl.FRAMEBUFFER, oldFb)
