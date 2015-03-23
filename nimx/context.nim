import types
import opengl
from opengl import GLuint, GLint, GLfloat, GLenum
import unsigned
import logging
import matrixes
import font
import image
import unicode
import portable_gl

export matrixes

type ShaderAttribute = enum
    saPosition


type Transform3D* = Matrix4

include shaders


var gl: GL = newGL(nil)

proc loadShader(shaderSrc: string, kind: GLenum): GLuint =
    result = gl.createShader(kind)
    if result == 0:
        return

    # Load the shader source
    gl.shaderSource(result, shaderSrc)
    # Compile the shader
    gl.compileShader(result)
    # Check the compile status
    let compiled = gl.isShaderCompiled(result)
    let info = gl.shaderInfoLog(result)
    if not compiled:
        log "Shader compile error: ", info
        gl.deleteShader(result)
    elif info.len > 0:
        log "Shader compile log: ", info

proc newShaderProgram(vs, fs: string): GLuint =
    result = gl.createProgram()
    if result == 0:
        log "Could not create program: ", gl.getError()
        return
    var s = loadShader(vs, gl.VERTEX_SHADER)
    if s == 0:
        gl.deleteProgram(result)
        return 0
    gl.attachShader(result, s)
    s = loadShader(fs, gl.FRAGMENT_SHADER)
    if s == 0:
        gl.deleteProgram(result)
        return 0
    gl.attachShader(result, s)
    gl.linkProgram(result)
    let linked = gl.isProgramLinked(result)
    let info = gl.programInfoLog(result)
    if not linked:
        log "Could not link: ", info
        result = 0
    elif info.len > 0:
        log "Program linked: ", info
    gl.bindAttribLocation(result, saPosition.GLuint, "position")

when defined js:
    type Transform = Transform3D
else:
    type Transform = ptr Transform3D

type GraphicsContext* = ref object of RootObj
    pTransform: Transform
    fillColor*: Color
    strokeColor*: Color
    strokeWidth*: Coord
    shaderProgram: GLuint
    roundedRectShaderProgram: GLuint
    ellipseShaderProgram: GLuint
    fontShaderProgram: GLuint
    testPolyShaderProgram: GLuint
    imageShaderProgram: GLuint

var gCurrentContext: GraphicsContext

template setScopeTransform*(c: GraphicsContext, t: var Transform3D): expr =
    let old = c.pTransform
    when defined js:
        c.pTransform = t
    else:
        c.pTransform = addr t
    old

template revertTransform*(c: GraphicsContext, t: Transform) =
    c.pTransform = t

proc setTransform*(c: GraphicsContext, t: var Transform3D): Transform {.discardable.}=
    result = c.pTransform
    when defined js:
        c.pTransform = t
    else:
        c.pTransform = addr t

proc setTransform*(c: GraphicsContext, t: Transform): Transform {.discardable.} =
    result = c.pTransform
    c.pTransform = t

template transform*(c: GraphicsContext): expr = c.pTransform[]

proc newGraphicsContext*(canvasId: string = nil): GraphicsContext =
    result.new()
    when not defined(ios) and not defined(android) and not defined(js):
        loadExtensions()

    #result.gl = newGL(canvasId)
    result.shaderProgram = newShaderProgram(vertexShader, fragmentShader)
    result.roundedRectShaderProgram = newShaderProgram(roundedRectVertexShader, roundedRectFragmentShader)
    result.ellipseShaderProgram = newShaderProgram(roundedRectVertexShader, ellipseFragmentShader)
    result.fontShaderProgram = newShaderProgram(fontVertexShader, fontFragmentShader)
    #result.testPolyShaderProgram = newShaderProgram(testPolygonVertexShader, testPolygonFragmentShader)
    result.imageShaderProgram = newShaderProgram(imageVertexShader, imageFragmentShader)
    gl.clearColor(1.0, 0.0, 1.0, 1.0)


proc setCurrentContext*(c: GraphicsContext): GraphicsContext {.discardable.} =
    result = gCurrentContext
    gCurrentContext = c

proc currentContext*(): GraphicsContext = gCurrentContext

proc setTransformUniform(c: GraphicsContext, program: GLuint) =
    when defined js:
        gl.uniformMatrix(gl.getUniformLocation(program, "modelViewProjectionMatrix"), 1, false, cast[ptr GLfloat](c.pTransform))
    else:
        gl.uniformMatrix(gl.getUniformLocation(program, "modelViewProjectionMatrix"), 1, false, c.pTransform[])

proc setFillColorUniform(c: GraphicsContext, program: GLuint) =
    when defined js:
        gl.uniform4fv(gl.getUniformLocation(program, "fillColor"), 1,
            [c.fillColor.r, c.fillColor.g, c.fillColor.b, c.fillColor.a])
    else:
        glUniform4fv(gl.getUniformLocation(program, "fillColor"), 1, cast[ptr GLfloat](addr c.fillColor))

proc setRectUniform(prog: GLuint, name: cstring, r: Rect) =
    when defined js:
        gl.uniform4fv(gl.getUniformLocation(prog, name), 1, [r.x, r.y, r.width, r.height])
    else:
        {.emit: """
        glUniform4fv(glGetUniformLocation(`prog`, `name`), 1, `r`);
        """.}

proc setStrokeParamsUniform(c: GraphicsContext, program: GLuint) =
    when defined js:
        gl.uniform4fv(gl.getUniformLocation(program, "strokeColor"), 1,
            [c.strokeColor.r, c.strokeColor.g, c.strokeColor.b, c.strokeColor.a])
    else:
        glUniform4fv(gl.getUniformLocation(program, "strokeColor"), 1, cast[ptr GLfloat](addr c.strokeColor))
    gl.uniform1f(gl.getUniformLocation(program, "strokeWidth"), c.strokeWidth)


proc drawVertexes(c: GraphicsContext, componentCount: int, points: openarray[Coord], pt: GLenum) =
    assert(points.len mod componentCount == 0)
    gl.useProgram(c.shaderProgram)
    gl.enableVertexAttribArray(saPosition.GLuint)
    gl.vertexAttribPointer(saPosition.GLuint, componentCount.GLint, false, 0, points)
    #glVertexAttribPointer(GLuint(saPosition), GLint(componentCount), cGL_FLOAT, false, 0, cast[pointer](points))
    c.setTransformUniform(c.shaderProgram)
    c.setFillColorUniform(c.shaderProgram)
    gl.drawArrays(pt, 0, GLsizei(points.len / componentCount))

proc drawRectAsQuad(c: GraphicsContext, r: Rect) =
    let points = [r.minX, r.minY,
                r.maxX, r.minY,
                r.maxX, r.maxY,
                r.minX, r.maxY]
    let componentCount = 2
    gl.enableVertexAttribArray(saPosition.GLuint)
    gl.vertexAttribPointer(saPosition.GLuint, componentCount.GLint, false, 0, points)
    gl.drawArrays(gl.TRIANGLE_FAN, 0, GLsizei(points.len / componentCount))

proc drawRoundedRect*(c: GraphicsContext, r: Rect, radius: Coord) =
    var rect = r
    var rad = radius
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.useProgram(c.roundedRectShaderProgram)
    c.setFillColorUniform(c.roundedRectShaderProgram)
    c.setTransformUniform(c.roundedRectShaderProgram)
    glUniform4fv(gl.getUniformLocation(c.roundedRectShaderProgram, "rect"), 1, cast[ptr GLfloat](addr rect))
    gl.uniform1f(gl.getUniformLocation(c.roundedRectShaderProgram, "radius"), rad)
    c.drawRectAsQuad(r)

proc drawRect*(c: GraphicsContext, r: Rect) =
    let points = [r.minX, r.minY,
                r.maxX, r.minY,
                r.maxX, r.maxY,
                r.minX, r.maxY]
    c.drawVertexes(2, points, gl.TRIANGLE_FAN)

proc drawEllipseInRect*(c: GraphicsContext, r: Rect) =
    var rect = r
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.useProgram(c.ellipseShaderProgram)
    c.setFillColorUniform(c.ellipseShaderProgram)
    c.setStrokeParamsUniform(c.ellipseShaderProgram)
    c.setTransformUniform(c.ellipseShaderProgram)
    glUniform4fv(gl.getUniformLocation(c.ellipseShaderProgram, "rect"), 1, cast[ptr GLfloat](addr rect))
    c.drawRectAsQuad(r)

proc drawText*(c: GraphicsContext, font: Font, pt: var Point, text: string) =
    # assume orthographic projection with units = screen pixels, origin at top left
    # TODO: Here follows a quick hack to move font origin to it's upper left corner.
    pt.y += font.size
    gl.useProgram(c.fontShaderProgram)
    c.setFillColorUniform(c.fontShaderProgram)

    gl.enableVertexAttribArray(saPosition.GLuint)
    c.setTransformUniform(c.fontShaderProgram)

    var vertexes: array[4 * 4, Coord]
    gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, vertexes)

    var texture: GLuint = 0
    var newTexture: GLuint = 0

    for ch in text.runes:
        font.getQuadDataForRune(ch, vertexes, newTexture, pt)
        if texture != newTexture:
            texture = newTexture
            gl.bindTexture(gl.TEXTURE_2D, texture)
        gl.drawArrays(gl.TRIANGLE_FAN, 0, 4)
    # Undo the hack
    pt.y -= font.size

proc drawImage*(c: GraphicsContext, i: Image, toRect: Rect, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
    c.imageShaderProgram.glUseProgram()
    gl.bindTexture(gl.TEXTURE_2D, i.texture)
    let points = [toRect.minX, toRect.minY, 0, 0,
                toRect.maxX, toRect.minY, i.sizeInTexels.width, 0,
                toRect.maxX, toRect.maxY, i.sizeInTexels.width, i.sizeInTexels.height,
                toRect.minX, toRect.maxY, 0, i.sizeInTexels.height]
    gl.enableVertexAttribArray(saPosition.GLuint)
    c.setTransformUniform(c.imageShaderProgram)
    gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, points)
    gl.drawArrays(gl.TRIANGLE_FAN, 0, 4)


discard """
proc beginStencil(c: GraphicsContext) =
    glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)
    glDepthMask(GL_FALSE)
    glStencilFunc(GL_NEVER, 1, 0xFF)
    glStencilOp(GL_REPLACE, GL_KEEP, GL_KEEP)  # draw 1s on test fail (always)
 
    # draw stencil pattern
    glStencilMask(0xFF)
    glClear(GL_STENCIL_BUFFER_BIT)  # needs mask=0xFF
    
proc endStencil(c: GraphicsContext) =
    glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glDepthMask(GL_TRUE);
    glStencilMask(0x00);

proc enableStencil(c: GraphicsContext) =
    gl.enable(GL_STENCIL_TEST)

proc disableStencil(c: GraphicsContext) =
    gl.disable(GL_STENCIL_TEST)

proc drawGradientInRect(c: GraphicsContext) =
    discard
    """

proc drawPoly*(c: GraphicsContext, points: openArray[Coord]) =
    let shaderProg = c.testPolyShaderProgram
    gl.useProgram(shaderProg)
    gl.enable(gl.BLEND)
    gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.enableVertexAttribArray(saPosition.GLuint)
    const componentCount = 2
    let numberOfVertices = points.len / componentCount
    gl.vertexAttribPointer(saPosition.GLuint, componentCount.GLint, false, 0, points)
    #c.setFillColorUniform(c.shaderProg)
    #glUniform1i(gl.getUniformLocation(shaderProg, "numberOfVertices"), GLint(numberOfVertices))
    c.setTransformUniform(shaderProg)
    #glUniform4fv(gl.getUniformLocation(shaderProg, "fillColor"), 1, cast[ptr GLfloat](addr c.fillColor))
    #gl.drawArrays(cast[GLenum](gl.TRIANGLE_FAN), 0, GLsizei(numberOfVertices))

proc testPoly*(c: GraphicsContext) =
    let points = [
        Coord(500.0), 400,
        #600, 400,

        #700, 450,

        600, 500,
        500, 500
        ]
    c.drawPoly(points)

