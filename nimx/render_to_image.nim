
import image
import portable_gl
import context
import unsigned
import math
import opengl

proc draw*(i: Image, drawProc: proc()) =
    let gl = sharedGL()
    if i.texture == 0:
        i.texture = gl.createTexture()

    let oldFb = gl.getParami(gl.FRAMEBUFFER_BINDING).GLuint
    let oldViewport = gl.getViewport()

    let framebuffer = gl.createFramebuffer()
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer)

    gl.bindTexture(gl.TEXTURE_2D, i.texture)
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

    let texWidth = if isPowerOfTwo(i.size.width.int): i.size.width.int else: nextPowerOfTwo(i.size.width.int)
    let texHeight = if isPowerOfTwo(i.size.height.int): i.size.height.int else: nextPowerOfTwo(i.size.height.int)

    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA.GLint, texWidth.GLsizei, texHeight.GLsizei, 0, gl.RGBA, gl.UNSIGNED_BYTE, nil)
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, i.texture, 0)

    let oldRb = gl.getParami(gl.RENDERBUFFER_BINDING).GLuint
    let depthBuffer = gl.createRenderbuffer()
    gl.bindRenderbuffer(gl.RENDERBUFFER, depthBuffer)

    let depthStencilFormat = when defined(js): gl.DEPTH_STENCIL else: gl.DEPTH24_STENCIL8

    gl.renderbufferStorage(gl.RENDERBUFFER, depthStencilFormat, texWidth.GLsizei, texHeight.GLsizei)
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, depthBuffer)
    gl.viewport(0, 0, i.size.width.GLsizei, i.size.height.GLsizei)
    gl.stencilMask(0xFF) # Android requires setting stencil mask to clear
    gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT)
    gl.stencilMask(0x00) # Android requires setting stencil mask to clear

    gl.disable(gl.STENCIL_TEST)
    currentContext().withTransform ortho(0, i.size.width, i.size.height, 0, -1, 1):
        drawProc()

    gl.viewport(oldViewport[0], oldViewport[1], oldViewport[2], oldViewport[3])
    gl.bindRenderbuffer(gl.RENDERBUFFER, oldRb)
    gl.deleteRenderbuffer(depthBuffer)
    gl.bindFramebuffer(gl.FRAMEBUFFER, oldFb)
    gl.deleteFramebuffer(framebuffer)

