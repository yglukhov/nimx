import types
import opengl
from opengl import GLuint, GLint, GLfloat, GLenum
import unsigned
import system_logger
import matrixes
import font
import image
import unicode
import portable_gl

export matrixes

type ShaderAttribute = enum
    saPosition
    saColor

type Transform3D* = Matrix4


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

proc newShaderProgram*(gl: GL, vs, fs: string,
        attributes: openarray[tuple[index: GLuint, name: string]]): GLuint =
    result = gl.createProgram()
    if result == 0:
        logi "Could not create program: ", gl.getError().int
        return
    let vShader = gl.loadShader(vs, gl.VERTEX_SHADER)
    if vShader == 0:
        gl.deleteProgram(result)
        return 0
    gl.attachShader(result, vShader)
    let fShader = gl.loadShader(fs, gl.FRAGMENT_SHADER)
    if fShader == 0:
        gl.deleteProgram(result)
        return 0
    gl.attachShader(result, fShader)

    for a in attributes:
        gl.bindAttribLocation(result, a.index, a.name)

    gl.linkProgram(result)
    gl.deleteShader(vShader)
    gl.deleteShader(fShader)

    let linked = gl.isProgramLinked(result)
    let info = gl.programInfoLog(result)
    if not linked:
        logi "Could not link: ", info
        result = 0
    elif info.len > 0:
        logi "Program linked: ", info

proc newShaderProgram(gl: GL, vs, fs: string): GLuint {.inline.} = # Deprecated. kinda.
    gl.newShaderProgram(vs, fs, [(saPosition.GLuint, "position")])

include shaders

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
    fontShaderProgram: GLuint
    testPolyShaderProgram: GLuint
    imageShaderProgram: GLuint
    debugClipColor: Color

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

proc newGraphicsContext*(canvas: ref RootObj = nil): GraphicsContext =
    result.new()
    result.gl = newGL(canvas)
    when not defined(ios) and not defined(android) and not defined(js):
        loadExtensions()

    result.fontShaderProgram = result.gl.newShaderProgram(fontVertexShader, fontFragmentShader)
    #result.testPolyShaderProgram = result.gl.newShaderProgram(testPolygonVertexShader, testPolygonFragmentShader)
    result.imageShaderProgram = result.gl.newShaderProgram(imageVertexShader, imageFragmentShader)
    result.gl.clearColor(0.93, 0.93, 0.93, 1.0)

proc setCurrentContext*(c: GraphicsContext): GraphicsContext {.discardable.} =
    result = gCurrentContext
    gCurrentContext = c

template currentContext*(): GraphicsContext = gCurrentContext

proc setTransformUniform*(c: GraphicsContext, program: GLuint) =
    c.gl.uniformMatrix4fv(c.gl.getUniformLocation(program, "modelViewProjectionMatrix"), false, c.transform)

proc setColorUniform*(c: GraphicsContext, program: GLuint, name: cstring, color: Color) =
    let loc = c.gl.getUniformLocation(program, name)
    when defined js:
        c.gl.uniform4fv(loc, [color.r, color.g, color.b, color.a])
    else:
        glUniform4fv(loc, 1, cast[ptr GLfloat](unsafeAddr color));

template setFillColorUniform(c: GraphicsContext, program: GLuint) =
    c.setColorUniform(program, "fillColor", c.fillColor)

proc setRectUniform*(c: GraphicsContext, prog: GLuint, name: cstring, r: Rect) =
    let loc = c.gl.getUniformLocation(prog, name)
    when defined js:
        c.gl.uniform4fv(loc, [r.x, r.y, r.width, r.height])
    else:
        glUniform4fv(loc, 1, cast[ptr GLfloat](unsafeAddr r));

proc setPointUniform*(c: GraphicsContext, prog: GLuint, name: cstring, r: Point) =
    let loc = c.gl.getUniformLocation(prog, name)
    when defined js:
        c.gl.uniform2fv(loc, [r.x, r.y])
    else:
        glUniform2fv(loc, 1, cast[ptr GLfloat](unsafeAddr r));

proc setStrokeParamsUniform(c: GraphicsContext, program: GLuint) =
    if c.strokeWidth == 0:
        c.setColorUniform(program, "strokeColor", c.fillColor)
    else:
        c.setColorUniform(program, "strokeColor", c.strokeColor)
    c.gl.uniform1f(c.gl.getUniformLocation(program, "strokeWidth"), c.strokeWidth)

import composition

var roundedRectComposition = newComposition """
uniform vec4 uFillColor;
uniform vec4 uStrokeColor;
uniform float uStrokeWidth;
uniform float uRadius;

void compose() {
    drawShape(sdRoundedRect(bounds, uRadius), uStrokeColor);
    drawShape(sdRoundedRect(insetRect(bounds, uStrokeWidth), uRadius - uStrokeWidth), uFillColor);
}
"""

proc drawRoundedRect*(c: GraphicsContext, r: Rect, radius: Coord) =
    roundedRectComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)
        setUniform("uRadius", radius)

var rectComposition = newComposition """
uniform vec4 uFillColor;
uniform vec4 uStrokeColor;
uniform float uStrokeWidth;

void compose() {
    drawShape(sdRect(bounds), uStrokeColor);
    drawShape(sdRect(insetRect(bounds, uStrokeWidth)), uFillColor);
}
"""

proc drawRect*(c: GraphicsContext, r: Rect) =
    rectComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)

var ellipseComposition = newComposition """
uniform vec4 uFillColor;
uniform vec4 uStrokeColor;
uniform float uStrokeWidth;

void compose() {
    drawShape(sdEllipseInRect(bounds), uStrokeColor);
    drawShape(sdEllipseInRect(insetRect(bounds, uStrokeWidth)), uFillColor);
}
"""

proc drawEllipseInRect*(c: GraphicsContext, r: Rect) =
    ellipseComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)

proc drawText*(c: GraphicsContext, font: Font, pt: var Point, text: string) =
    # assume orthographic projection with units = screen pixels, origin at top left
    c.gl.useProgram(c.fontShaderProgram)
    c.setFillColorUniform(c.fontShaderProgram)

    c.gl.enableVertexAttribArray(saPosition.GLuint)
    c.setTransformUniform(c.fontShaderProgram)
    c.gl.enable(c.gl.BLEND)
    c.gl.blendFunc(c.gl.SRC_ALPHA, c.gl.ONE_MINUS_SRC_ALPHA)

    var vertexes: array[4 * 4, Coord]

    var texture: GLuint = 0
    var newTexture: GLuint = 0

    for ch in text.runes:
        font.getQuadDataForRune(ch, vertexes, newTexture, pt)
        if texture != newTexture:
            texture = newTexture
            c.gl.bindTexture(c.gl.TEXTURE_2D, texture)
        c.gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, vertexes)
        c.gl.drawArrays(c.gl.TRIANGLE_FAN, 0, 4)

proc drawText*(c: GraphicsContext, font: Font, pt: Point, text: string) =
    var p = pt
    c.drawText(font, p, text)

proc drawImage*(c: GraphicsContext, i: Image, toRect: Rect, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
    let t = i.getTexture(c.gl)
    if t != 0:
        c.gl.useProgram(c.imageShaderProgram)
        c.gl.bindTexture(c.gl.TEXTURE_2D, t)
        c.gl.enable(c.gl.BLEND)
        c.gl.blendFunc(c.gl.SRC_ALPHA, c.gl.ONE_MINUS_SRC_ALPHA)

        var s0 : Coord
        var t0 : Coord
        var s1 : Coord = i.sizeInTexels.width
        var t1 : Coord = i.sizeInTexels.height
        if fromRect != zeroRect:
            s0 = fromRect.x / i.size.width * i.sizeInTexels.width
            t0 = fromRect.y / i.size.height * i.sizeInTexels.height
            s1 = fromRect.maxX / i.size.width * i.sizeInTexels.width
            t1 = fromRect.maxY / i.size.height * i.sizeInTexels.height

        let points = [toRect.minX, toRect.minY, s0, t0,
                    toRect.maxX, toRect.minY, s1, t0,
                    toRect.maxX, toRect.maxY, s1, t1,
                    toRect.minX, toRect.maxY, s0, t1]
        c.gl.enableVertexAttribArray(saPosition.GLuint)
        c.setTransformUniform(c.imageShaderProgram)
        c.gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, points)
        c.gl.drawArrays(c.gl.TRIANGLE_FAN, 0, 4)

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

# TODO: This should probaly be a property of current context!
var clippingDepth: GLint = 0

# Clipping
proc applyClippingRect*(c: GraphicsContext, r: Rect, on: bool) =
    c.gl.enable(c.gl.STENCIL_TEST)
    c.gl.colorMask(false, false, false, false)
    c.gl.depthMask(false)
    c.gl.stencilMask(0xFF)
    if on:
        inc clippingDepth
        c.gl.stencilOp(c.gl.INCR, c.gl.KEEP, c.gl.KEEP)
    else:
        dec clippingDepth
        c.gl.stencilOp(c.gl.DECR, c.gl.KEEP, c.gl.KEEP)

    c.gl.stencilFunc(c.gl.NEVER, 1, 0xFF)
    c.drawRect(r)

    c.gl.colorMask(true, true, true, true)
    c.gl.depthMask(true)
    c.gl.stencilMask(0x00)

    c.gl.stencilOp(c.gl.KEEP, c.gl.KEEP, c.gl.KEEP)
    c.gl.stencilFunc(c.gl.EQUAL, clippingDepth, 0xFF)
    if clippingDepth == 0:
        c.gl.disable(c.gl.STENCIL_TEST)

template withClippingRect*(c: GraphicsContext, r: Rect, body: stmt) =
    c.applyClippingRect(r, true)
    body
    c.applyClippingRect(r, false)
