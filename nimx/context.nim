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

proc loadShader(gl: GL, shaderSrc: string, kind: GLenum): GLuint =
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
        logi "Shader compile error: ", info
        gl.deleteShader(result)
    elif info.len > 0:
        logi "Shader compile log: ", info

proc newShaderProgram(gl: GL, vs, fs: string): GLuint =
    result = gl.createProgram()
    if result == 0:
        logi "Could not create program: ", gl.getError().int
        return
    var s = gl.loadShader(vs, gl.VERTEX_SHADER)
    if s == 0:
        gl.deleteProgram(result)
        return 0
    gl.attachShader(result, s)
    s = gl.loadShader(fs, gl.FRAGMENT_SHADER)
    if s == 0:
        gl.deleteProgram(result)
        return 0
    gl.attachShader(result, s)
    gl.linkProgram(result)
    let linked = gl.isProgramLinked(result)
    let info = gl.programInfoLog(result)
    if not linked:
        logi "Could not link: ", info
        result = 0
    elif info.len > 0:
        logi "Program linked: ", info
    gl.bindAttribLocation(result, saPosition.GLuint, "position")

when defined js:
    type Transform3DRef = ref Transform3D
else:
    type Transform3DRef = ptr Transform3D

type GraphicsContext* = ref object of RootObj
    gl*: GL
    pTransform: Transform3DRef
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

proc transformToRef(t: Transform3D): Transform3DRef =
    when defined js:
        asm "`result` = `t`;"
    else:
        {.emit: "`result` = `t`;".}

template withTransform*(c: GraphicsContext, t: Transform3DRef, body: stmt) =
    let old = c.pTransform
    c.pTransform = t
    body
    c.pTransform = old

template withTransform*(c: GraphicsContext, t: Transform3D, body: stmt) = c.withTransform(transformToRef(t), body)

template transform*(c: GraphicsContext): var Transform3D = c.pTransform[]

proc newGraphicsContext*(canvasId: cstring = nil): GraphicsContext =
    result.new()
    result.gl = newGL(canvasId)
    when not defined(ios) and not defined(android) and not defined(js):
        loadExtensions()

    #result.gl = newGL(canvasId)
    result.shaderProgram = result.gl.newShaderProgram(vertexShader, fragmentShader)
    result.roundedRectShaderProgram = result.gl.newShaderProgram(roundedRectVertexShader, roundedRectFragmentShader)
    result.ellipseShaderProgram = result.gl.newShaderProgram(roundedRectVertexShader, ellipseFragmentShader)
    result.fontShaderProgram = result.gl.newShaderProgram(fontVertexShader, fontFragmentShader)
    #result.testPolyShaderProgram = result.gl.newShaderProgram(testPolygonVertexShader, testPolygonFragmentShader)
    result.imageShaderProgram = result.gl.newShaderProgram(imageVertexShader, imageFragmentShader)
    result.gl.clearColor(1.0, 0.0, 1.0, 1.0)


proc setCurrentContext*(c: GraphicsContext): GraphicsContext {.discardable.} =
    result = gCurrentContext
    gCurrentContext = c

proc currentContext*(): GraphicsContext = gCurrentContext

proc setTransformUniform(c: GraphicsContext, program: GLuint) =
    c.gl.uniformMatrix4fv(c.gl.getUniformLocation(program, "modelViewProjectionMatrix"), false, c.transform)

proc setFillColorUniform(c: GraphicsContext, program: GLuint) =
    let loc = c.gl.getUniformLocation(program, "fillColor")
    when defined js:
        c.gl.uniform4fv(loc, [c.fillColor.r, c.fillColor.g, c.fillColor.b, c.fillColor.a])
    else:
        glUniform4fv(loc, 1, cast[ptr GLfloat](addr c.fillColor))

proc setRectUniform(c: GraphicsContext, prog: GLuint, name: cstring, r: Rect) =
    let loc = c.gl.getUniformLocation(prog, name)
    when defined js:
        c.gl.uniform4fv(loc, [r.x, r.y, r.width, r.height])
    else:
        var p: ptr GLfloat
        {.emit: "`p` = &`r`;".}
        glUniform4fv(loc, 1, p);

proc setStrokeParamsUniform(c: GraphicsContext, program: GLuint) =
    let loc = c.gl.getUniformLocation(program, "strokeColor")
    when defined js:
        c.gl.uniform4fv(loc, [c.strokeColor.r, c.strokeColor.g, c.strokeColor.b, c.strokeColor.a])
    else:
        glUniform4fv(loc, 1, cast[ptr GLfloat](addr c.strokeColor))
    c.gl.uniform1f(c.gl.getUniformLocation(program, "strokeWidth"), c.strokeWidth)

proc drawVertexes(c: GraphicsContext, componentCount: int, points: openarray[Coord], pt: GLenum) =
    assert(points.len mod componentCount == 0)
    c.gl.useProgram(c.shaderProgram)
    c.gl.enableVertexAttribArray(saPosition.GLuint)
    c.gl.vertexAttribPointer(saPosition.GLuint, componentCount.GLint, false, 0, points)
    c.setTransformUniform(c.shaderProgram)
    c.setFillColorUniform(c.shaderProgram)
    c.gl.drawArrays(pt, 0, GLsizei(points.len / componentCount))

proc drawRectAsQuad(c: GraphicsContext, r: Rect) =
    let points = [r.minX, r.minY,
                r.maxX, r.minY,
                r.maxX, r.maxY,
                r.minX, r.maxY]
    let componentCount = 2
    c.gl.enableVertexAttribArray(saPosition.GLuint)
    c.gl.vertexAttribPointer(saPosition.GLuint, componentCount.GLint, false, 0, points)
    c.gl.drawArrays(c.gl.TRIANGLE_FAN, 0, GLsizei(points.len / componentCount))

proc drawRoundedRect*(c: GraphicsContext, r: Rect, radius: Coord) =
    c.gl.enable(c.gl.BLEND)
    c.gl.blendFunc(c.gl.SRC_ALPHA, c.gl.ONE_MINUS_SRC_ALPHA)
    c.gl.useProgram(c.roundedRectShaderProgram)
    c.setFillColorUniform(c.roundedRectShaderProgram)
    c.setTransformUniform(c.roundedRectShaderProgram)
    c.setRectUniform(c.roundedRectShaderProgram, "rect", r)
    c.gl.uniform1f(c.gl.getUniformLocation(c.roundedRectShaderProgram, "radius"), radius)
    c.drawRectAsQuad(r)

proc drawRect*(c: GraphicsContext, r: Rect) =
    let points = [r.minX, r.minY,
                r.maxX, r.minY,
                r.maxX, r.maxY,
                r.minX, r.maxY]
    c.drawVertexes(2, points, c.gl.TRIANGLE_FAN)

proc drawEllipseInRect*(c: GraphicsContext, r: Rect) =
    c.gl.enable(c.gl.BLEND)
    c.gl.blendFunc(c.gl.SRC_ALPHA, c.gl.ONE_MINUS_SRC_ALPHA)
    c.gl.useProgram(c.ellipseShaderProgram)
    c.setFillColorUniform(c.ellipseShaderProgram)
    c.setStrokeParamsUniform(c.ellipseShaderProgram)
    c.setTransformUniform(c.ellipseShaderProgram)
    c.setRectUniform(c.ellipseShaderProgram, "rect", r)
    c.drawRectAsQuad(r)

proc drawText*(c: GraphicsContext, font: Font, pt: var Point, text: string) =
    # assume orthographic projection with units = screen pixels, origin at top left
    # TODO: Here follows a quick hack to move font origin to it's upper left corner.
    pt.y += font.size
    c.gl.useProgram(c.fontShaderProgram)
    c.setFillColorUniform(c.fontShaderProgram)

    c.gl.enableVertexAttribArray(saPosition.GLuint)
    c.setTransformUniform(c.fontShaderProgram)

    var vertexes: array[4 * 4, Coord]
    c.gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, vertexes)

    var texture: GLuint = 0
    var newTexture: GLuint = 0

    for ch in text.runes:
        font.getQuadDataForRune(ch, vertexes, newTexture, pt)
        if texture != newTexture:
            texture = newTexture
            c.gl.bindTexture(c.gl.TEXTURE_2D, texture)
        c.gl.drawArrays(c.gl.TRIANGLE_FAN, 0, 4)
    # Undo the hack
    pt.y -= font.size

proc drawImage*(c: GraphicsContext, i: Image, toRect: Rect, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
    let t = i.getTexture(c.gl)
    if t != 0:
        c.gl.useProgram(c.imageShaderProgram)
        c.gl.bindTexture(c.gl.TEXTURE_2D, t)
        let points = [toRect.minX, toRect.minY, 0, 0,
                    toRect.maxX, toRect.minY, i.sizeInTexels.width, 0,
                    toRect.maxX, toRect.maxY, i.sizeInTexels.width, i.sizeInTexels.height,
                    toRect.minX, toRect.maxY, 0, i.sizeInTexels.height]
        c.gl.enableVertexAttribArray(saPosition.GLuint)
        c.setTransformUniform(c.imageShaderProgram)
        c.gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, points)
        c.gl.drawArrays(c.gl.TRIANGLE_FAN, 0, 4)


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
    c.gl.useProgram(shaderProg)
    c.gl.enable(c.gl.BLEND)
    c.gl.blendFunc(c.gl.SRC_ALPHA, c.gl.ONE_MINUS_SRC_ALPHA)
    c.gl.enableVertexAttribArray(saPosition.GLuint)
    const componentCount = 2
    let numberOfVertices = points.len / componentCount
    c.gl.vertexAttribPointer(saPosition.GLuint, componentCount.GLint, false, 0, points)
    #c.setFillColorUniform(c.shaderProg)
    #glUniform1i(c.gl.getUniformLocation(shaderProg, "numberOfVertices"), GLint(numberOfVertices))
    c.setTransformUniform(shaderProg)
    #glUniform4fv(c.gl.getUniformLocation(shaderProg, "fillColor"), 1, cast[ptr GLfloat](addr c.fillColor))
    #c.gl.drawArrays(cast[GLenum](c.gl.TRIANGLE_FAN), 0, GLsizei(numberOfVertices))

proc testPoly*(c: GraphicsContext) =
    let points = [
        Coord(500.0), 400,
        #600, 400,

        #700, 450,

        600, 500,
        500, 500
        ]
    c.drawPoly(points)

