import types
import opengl
import system_logger
import matrixes
import image
import math
import portable_gl
import nimsl/nimsl

export matrixes

type ShaderAttribute* = enum
    saPosition
    saColor

type Transform3D* = Matrix4


proc loadShader(gl: GL, shaderSrc: string, kind: GLenum): ShaderRef =
    result = gl.createShader(kind)
    if result == invalidShader:
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
        logi "The shader: ", shaderSrc
        gl.deleteShader(result)
    elif info.len > 0:
        logi "Shader compile log: ", info

proc newShaderProgram*(gl: GL, vs, fs: string,
        attributes: openarray[tuple[index: GLuint, name: string]]): ProgramRef =
    result = gl.createProgram()
    if result == invalidProgram:
        logi "Could not create program: ", gl.getError().int
        return
    let vShader = gl.loadShader(vs, gl.VERTEX_SHADER)
    if vShader == invalidShader:
        gl.deleteProgram(result)
        return invalidProgram
    gl.attachShader(result, vShader)
    let fShader = gl.loadShader(fs, gl.FRAGMENT_SHADER)
    if fShader == invalidShader:
        gl.deleteProgram(result)
        return invalidProgram
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
        result = invalidProgram
    elif info.len > 0:
        logi "Program linked: ", info

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
    debugClipColor: Color
    alpha*: Coord
    quadIndexBuffer*: BufferRef
    gridIndexBuffer4x4: BufferRef
    singleQuadBuffer*: BufferRef
    sharedBuffer*: BufferRef
    vertexes*: array[4 * 4 * 128, Coord]

var gCurrentContext {.threadvar.}: GraphicsContext

proc transformToRef(t: Transform3D): Transform3DRef =
    when defined js:
        asm "`result` = `t`;"
    else:
        {.emit: "`result` = `t`;".}

template withTransform*(c: GraphicsContext, t: Transform3DRef, body: typed) =
    let old = c.pTransform
    c.pTransform = t
    body
    c.pTransform = old

template withTransform*(c: GraphicsContext, t: Transform3D, body: typed) = c.withTransform(transformToRef(t), body)

template transform*(c: GraphicsContext): var Transform3D = c.pTransform[]

proc createQuadIndexBuffer*(c: GraphicsContext, numberOfQuads: int): BufferRef =
    result = c.gl.createBuffer()
    c.gl.bindBuffer(c.gl.ELEMENT_ARRAY_BUFFER, result)

    var indexData = newSeq[GLushort](numberOfQuads * 6)
    var i = 0
    while i < numberOfQuads:
        let id = i * 6
        let vd = GLushort(i * 4)
        indexData[id + 0] = vd + 0
        indexData[id + 1] = vd + 1
        indexData[id + 2] = vd + 2
        indexData[id + 3] = vd + 2
        indexData[id + 4] = vd + 3
        indexData[id + 5] = vd + 0
        inc i

    c.gl.bufferData(c.gl.ELEMENT_ARRAY_BUFFER, indexData, c.gl.STATIC_DRAW)

proc createGridIndexBuffer(c: GraphicsContext, width, height: static[int]): BufferRef =
    result = c.gl.createBuffer()
    c.gl.bindBuffer(c.gl.ELEMENT_ARRAY_BUFFER, result)

    const numberOfQuadColumns = width - 1
    const numberOIndices = numberOfQuadColumns * height * 2

    var indexData : array[numberOIndices, GLushort]
    var i = 0

    var y, toRow: int
    var dir = 1

    for iCol in 0 ..< numberOfQuadColumns:
        if dir == 1:
            y = 0
            toRow = height
        else:
            y = height - 1
            toRow = -1

        while y != toRow:
            indexData[i] = GLushort(y * width + iCol)
            inc i
            indexData[i] = GLushort(y * width + iCol + 1)
            inc i
            y += dir
        dir = -dir

    c.gl.bufferData(c.gl.ELEMENT_ARRAY_BUFFER, indexData, c.gl.STATIC_DRAW)

proc createQuadBuffer(c: GraphicsContext): BufferRef =
    result = c.gl.createBuffer()
    c.gl.bindBuffer(c.gl.ARRAY_BUFFER, result)
    let vertexes = [0.GLfloat, 0, 0, 1, 1, 1, 1, 0]
    c.gl.bufferData(c.gl.ARRAY_BUFFER, vertexes, c.gl.STATIC_DRAW)

proc newGraphicsContext*(canvas: ref RootObj = nil): GraphicsContext =
    result.new()
    result.gl = newGL(canvas)
    when not defined(ios) and not defined(android) and not defined(js) and not defined(emscripten) and not defined(wasm):
        loadExtensions()

    result.gl.clearColor(0, 0, 0, 0.0)
    result.alpha = 1.0

    result.gl.enable(result.gl.BLEND)
    # We're using 1s + (1-s)d for alpha for proper alpha blending e.g. when rendering to texture.
    result.gl.blendFuncSeparate(result.gl.SRC_ALPHA, result.gl.ONE_MINUS_SRC_ALPHA, result.gl.ONE, result.gl.ONE_MINUS_SRC_ALPHA)

    #result.gl.enable(result.gl.CULL_FACE)
    #result.gl.cullFace(result.gl.BACK)

    result.quadIndexBuffer = result.createQuadIndexBuffer(128)
    result.gridIndexBuffer4x4 = result.createGridIndexBuffer(4, 4)
    result.singleQuadBuffer = result.createQuadBuffer()
    result.sharedBuffer = result.gl.createBuffer()

    if gCurrentContext.isNil:
        gCurrentContext = result

proc setCurrentContext*(c: GraphicsContext): GraphicsContext {.discardable.} =
    result = gCurrentContext
    gCurrentContext = c

template currentContext*(): GraphicsContext = gCurrentContext

proc setTransformUniform*(c: GraphicsContext, program: ProgramRef) =
    c.gl.uniformMatrix4fv(c.gl.getUniformLocation(program, "modelViewProjectionMatrix"), false, c.transform)

proc setColorUniform*(c: GraphicsContext, loc: UniformLocation, color: Color) =
    when defined js:
        c.gl.uniform4fv(loc, [color.r, color.g, color.b, color.a * c.alpha])
    else:
        var arr = [color.r, color.g, color.b, color.a * c.alpha]
        glUniform4fv(loc, 1, addr arr[0]);

proc setColorUniform*(c: GraphicsContext, program: ProgramRef, name: cstring, color: Color) =
    c.setColorUniform(c.gl.getUniformLocation(program, name), color)

proc setRectUniform*(c: GraphicsContext, loc: UniformLocation, r: Rect) =
    when defined js:
        c.gl.uniform4fv(loc, [r.x, r.y, r.width, r.height])
    else:
        glUniform4fv(loc, 1, cast[ptr GLfloat](unsafeAddr r));

template setRectUniform*(c: GraphicsContext, prog: ProgramRef, name: cstring, r: Rect) =
    c.setRectUniform(c.gl.getUniformLocation(prog, name), r)

proc setPointUniform*(c: GraphicsContext, loc: UniformLocation, r: Point) =
    when defined js:
        c.gl.uniform2fv(loc, [r.x, r.y])
    else:
        glUniform2fv(loc, 1, cast[ptr GLfloat](unsafeAddr r));

template setPointUniform*(c: GraphicsContext, prog: ProgramRef, name: cstring, r: Point) =
    c.setPointUniform(c.gl.getUniformLocation(prog, name), r)

import composition

const roundedRectComposition = newComposition """
uniform vec4 uFillColor;
uniform vec4 uStrokeColor;
uniform float uStrokeWidth;
uniform float uRadius;

void compose() {
    drawInitialShape(sdRoundedRect(bounds, uRadius), uStrokeColor);
    drawShape(sdRoundedRect(insetRect(bounds, uStrokeWidth), uRadius - uStrokeWidth), uFillColor);
}
"""

proc drawRoundedRect*(c: GraphicsContext, r: Rect, radius: Coord) =
    roundedRectComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)
        setUniform("uRadius", radius)

proc drawRect(bounds, uFillColor, uStrokeColor: Vec4,
                    uStrokeWidth: float32,
                    vPos: Vec2): Vec4 =
    result.drawInitialShape(sdRect(vPos, bounds), uStrokeColor);
    result.drawShape(sdRect(vPos, insetRect(bounds, uStrokeWidth)), uFillColor);

const rectComposition = newCompositionWithNimsl(drawRect)

proc drawRect*(c: GraphicsContext, r: Rect) =
    rectComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)

proc drawEllipse(bounds, uFillColor, uStrokeColor: Vec4,
                    uStrokeWidth: float32,
                    vPos: Vec2): Vec4 =
    result.drawInitialShape(sdEllipseInRect(vPos, bounds), uStrokeColor);
    result.drawShape(sdEllipseInRect(vPos, insetRect(bounds, uStrokeWidth)), uFillColor);

const ellipseComposition = newCompositionWithNimsl(drawEllipse)

proc drawEllipseInRect*(c: GraphicsContext, r: Rect) =
    ellipseComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)

proc imageVertexShader(aPosition: Vec2, uModelViewProjectionMatrix: Mat4, uBounds, uImage_texCoords, uFromRect: Vec4, vPos, vImageUV: var Vec2): Vec4 =
    let f = uFromRect
    let t = uImage_texCoords
    vPos = uBounds.xy + aPosition * uBounds.zw
    vImageUV = t.xy + (t.zw - t.xy) * (f.xy + (f.zw - f.xy) * aPosition)
    result = uModelViewProjectionMatrix * newVec4(vPos, 0.0, 1.0)

const imageVertexShaderCode = getGLSLVertexShader(imageVertexShader)

const imageComposition = newComposition(imageVertexShaderCode, """
uniform sampler2D uImage_tex;
uniform float uAlpha;
varying vec2 vImageUV;

void compose() {
    gl_FragColor = texture2D(uImage_tex, vImageUV);
    gl_FragColor.a *= uAlpha;
}
""")

proc bindVertexData*(c: GraphicsContext, length: int) =
    let gl = c.gl
    gl.bindBuffer(gl.ARRAY_BUFFER, c.sharedBuffer)
    gl.bufferData(gl.ARRAY_BUFFER, c.vertexes, length, gl.DYNAMIC_DRAW)

proc drawImage*(c: GraphicsContext, i: Image, toRect: Rect, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
    if i.isLoaded:
        var fr = newRect(0, 0, 1, 1)
        if fromRect != zeroRect:
            let s = i.size
            fr = newRect(fromRect.x / s.width, fromRect.y / s.height, fromRect.maxX / s.width, fromRect.maxY / s.height)
        imageComposition.draw toRect:
            setUniform("uImage", i)
            setUniform("uAlpha", alpha * c.alpha)
            setUniform("uFromRect", fr)

const ninePartImageComposition = newComposition("""
attribute vec4 aPosition;

uniform mat4 uModelViewProjectionMatrix;
varying vec2 vTexCoord;

void main() {
    vTexCoord = aPosition.zw;
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);
}
""",
"""
varying vec2 vTexCoord;

uniform sampler2D texUnit;
uniform float uAlpha;

void compose() {
    gl_FragColor = texture2D(texUnit, vTexCoord);
    gl_FragColor.a *= uAlpha;
}
""", false)

proc drawNinePartImage*(c: GraphicsContext, i: Image, toRect: Rect, ml, mt, mr, mb: Coord, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
    if i.isLoaded:
        let gl = c.gl
        var cc = gl.getCompiledComposition(ninePartImageComposition)

        var fuv : array[4, GLfloat]
        let tex = getTextureQuad(i, gl, fuv)

        let sz = i.size
        if fromRect != zeroRect:
            fuv[0] = fuv[0] + fromRect.x / sz.width
            fuv[1] = fuv[1] + fromRect.y / sz.height
            fuv[2] = fuv[2] - (sz.width - fromRect.maxX) / sz.width
            fuv[3] = fuv[3] - (sz.height - fromRect.maxY) / sz.height

        template setVertex(index: int, x, y, u, v: GLfloat) =
            c.vertexes[index * 2 * 2 + 0] = x
            c.vertexes[index * 2 * 2 + 1] = y
            c.vertexes[index * 2 * 2 + 2] = u
            c.vertexes[index * 2 * 2 + 3] = v

        let duvx = fuv[2] - fuv[0]
        let duvy = fuv[3] - fuv[1]

        let tml = ml / sz.width * duvx
        let tmr = mr / sz.width * duvx
        let tmt = mt / sz.height * duvy
        let tmb = mb / sz.height * duvy

        0.setVertex(toRect.x, toRect.y, fuv[0], fuv[1])
        1.setVertex(toRect.x + ml, toRect.y, fuv[0] + tml, fuv[1])
        2.setVertex(toRect.maxX - mr, toRect.y, fuv[2] - tmr, fuv[1])
        3.setVertex(toRect.maxX, toRect.y, fuv[2], fuv[1])

        4.setVertex(toRect.x, toRect.y + mt, fuv[0], fuv[1] + tmt)
        5.setVertex(toRect.x + ml, toRect.y + mt, fuv[0] + tml, fuv[1] + tmt)
        6.setVertex(toRect.maxX - mr, toRect.y + mt, fuv[2] - tmr, fuv[1] + tmt)
        7.setVertex(toRect.maxX, toRect.y + mt, fuv[2], fuv[1] + tmt)

        8.setVertex(toRect.x, toRect.maxY - mb, fuv[0], fuv[3] - tmb)
        9.setVertex(toRect.x + ml, toRect.maxY - mb, fuv[0] + tml, fuv[3] - tmb)
        10.setVertex(toRect.maxX - mr, toRect.maxY - mb, fuv[2] - tmr, fuv[3] - tmb)
        11.setVertex(toRect.maxX, toRect.maxY - mb, fuv[2], fuv[3] - tmb)

        12.setVertex(toRect.x, toRect.maxY, fuv[0], fuv[3])
        13.setVertex(toRect.x + ml, toRect.maxY, fuv[0] + tml, fuv[3])
        14.setVertex(toRect.maxX - mr, toRect.maxY, fuv[2] - tmr, fuv[3])
        15.setVertex(toRect.maxX, toRect.maxY, fuv[2], fuv[3])

        gl.useProgram(cc.program)
        compositionDrawingDefinitions(cc, c, gl)

        setUniform("uAlpha", alpha * c.alpha)

        gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
        setupPosteffectUniforms(cc)

        gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
        gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)
        gl.bindTexture(gl.TEXTURE_2D, tex)

        gl.enableVertexAttribArray(ShaderAttribute.saPosition.GLuint)
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, c.gridIndexBuffer4x4)

        const componentsCount = 4
        const vertexCount = (4 - 1) * 4 * 2
        c.bindVertexData(componentsCount * vertexCount)
        gl.vertexAttribPointer(ShaderAttribute.saPosition.GLuint, componentsCount, gl.FLOAT, false, 0, 0)
        gl.drawElements(gl.TRIANGLE_STRIP, vertexCount, gl.UNSIGNED_SHORT)


const simpleComposition = newComposition("""
attribute vec4 aPosition;
uniform mat4 uModelViewProjectionMatrix;

void main() {
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);
}
""",
"""
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif
uniform vec4 uStrokeColor;

void compose() {
    gl_FragColor = uStrokeColor;
}
""", false)

proc bezierPoint(p0, p1, p2, p3, t: float32): float32 =
  result = (pow((1-t), 3.0) * p0) +
    (3 * pow((1-t),2) * t * p1) +
    (3 * (1-t) * t * t * p2) +
    (pow(t, 3) * p3)

proc drawBezier*(c: GraphicsContext, p0, p1, p2, p3: Point) =
    let gl = c.gl
    var cc = gl.getCompiledComposition(simpleComposition)

    template setVertex(index: int, p: Point) =
        c.vertexes[index * 2 + 0] = p.x.GLfloat
        c.vertexes[index * 2 + 1] = p.y.GLfloat

    let vertexCount = 300
    for i in 0..<vertexCount:
        let t = i / (vertexCount - 1)
        let p = newPoint(bezierPoint(p0.x, p1.x, p2.x, p3.x, t), bezierPoint(p0.y, p1.y, p2.y, p3.y, t))
        setVertex(i, p)

    gl.useProgram(cc.program)
    compositionDrawingDefinitions(cc, c, gl)

    gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
    setUniform("uStrokeColor", c.strokeColor)
    setupPosteffectUniforms(cc)

    const componentsCount = 2
    gl.enableVertexAttribArray(ShaderAttribute.saPosition.GLuint)
    c.bindVertexData(componentsCount * vertexCount)
    gl.vertexAttribPointer(ShaderAttribute.saPosition.GLuint, componentsCount, gl.FLOAT, false, 0, 0)

    gl.enable(GL_LINE_SMOOTH)
    when not defined(js):
      glHint(GL_LINE_SMOOTH_HINT, GL_NICEST)

      glLineWidth(c.strokeWidth)

    gl.drawArrays(GL_LINE_STRIP, 0.GLint, vertexCount.GLsizei)
    when not defined(js):
      glLineWidth(1.0)


const lineComposition = newComposition """
uniform float uStrokeWidth;
uniform vec4  uStrokeColor;
uniform vec2  A;
uniform vec2  B;

float drawLine(vec2 p1, vec2 p2) {
  vec2 va = B - A;
  vec2 vb = vPos - A;
  vec2 vc = vPos - B;

  vec3 tri = vec3(distance(A, B), distance(vPos, A), distance(vPos, B));
  float p = (tri.x + tri.y + tri.z) / 2.0;
  float h = 2.0 * sqrt(p * (p - tri.x) * (p - tri.y) * (p - tri.z)) / tri.x;

  vec2 angles = acos(vec2(dot(normalize(-va), normalize(vc)), dot(normalize(va), normalize(vb))));
  vec2 anglem = 1.0 - step(PI / 2.0, angles);
  float pixelValue = 1.0 - smoothstep(0.0, uStrokeWidth, h);

  float res = anglem.x * anglem.y * pixelValue;
  return res;
}

void compose() {
  gl_FragColor = vec4(uStrokeColor.xyz, uStrokeColor.a * drawLine(A, B));
}
"""

proc drawLine*(c: GraphicsContext, pointFrom: Point, pointTo: Point) =
    let xfrom = min(pointFrom.x, pointTo.x)
    let yfrom = min(pointFrom.y, pointTo.y)
    let xsize = max(pointFrom.x, pointTo.x) - xfrom
    let ysize = max(pointFrom.y, pointTo.y) - yfrom
    let r = newRect(xfrom - c.strokeWidth, yfrom - c.strokeWidth, xsize + 2 * c.strokeWidth, ysize + 2 * c.strokeWidth)

    lineComposition.draw r:
        setUniform("uStrokeWidth", c.strokeWidth)
        setUniform("uStrokeColor", c.strokeColor)
        setUniform("A", pointFrom)
        setUniform("B", pointTo)

const arcComposition = newComposition """
uniform float uStrokeWidth;
uniform vec4 uStrokeColor;
uniform vec4 uFillColor;
uniform float uStartAngle;
uniform float uEndAngle;

void compose() {
    vec2 center = bounds.xy + bounds.zw / 2.0;
    float radius = min(bounds.z, bounds.w) / 2.0 - 1.0;
    float centerDist = distance(vPos, center);
    vec2 delta = vPos - center;
    float angle = atan(delta.y, delta.x);
    angle += step(angle, 0.0) * PI * 2.0;

    float angleDist1 = step(step(angle, uStartAngle) + step(uEndAngle, angle), 0.0);
    angle += PI * 2.0;
    float angleDist2 = step(step(angle, uStartAngle) + step(uEndAngle, angle), 0.0);

    drawInitialShape((centerDist - radius) / radius, uStrokeColor);
    drawShape((centerDist - radius + uStrokeWidth) / radius, uFillColor);
    gl_FragColor.a *= max(angleDist1, angleDist2);
}
"""

proc drawArc*(c: GraphicsContext, center: Point, radius: Coord, fromAngle, toAngle: Coord) =
    if abs(fromAngle - toAngle) < 0.0001: return
    var fromAngle = fromAngle
    var toAngle = toAngle
    fromAngle = fromAngle mod (2 * Pi)
    toAngle = toAngle mod (2 * Pi)
    if fromAngle < 0: fromAngle += Pi * 2
    if toAngle < 0: toAngle += Pi * 2
    if toAngle < fromAngle:
         toAngle += Pi * 2

    let rad = radius + 1
    let r = newRect(center.x - rad, center.y - rad, rad * 2, rad * 2)
    arcComposition.draw r:
        setUniform("uStrokeWidth", c.strokeWidth)
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStartAngle", fromAngle)
        setUniform("uEndAngle", toAngle)

const triangleComposition = newComposition """
uniform float uAngle;
uniform vec4 uColor;
void compose() {
    vec2 center = vec2(bounds.x + bounds.z / 2.0, bounds.y + bounds.w / 2.0 - 1.0);
    float triangle = sdRegularPolygon(center, 4.0, 3, uAngle);
    drawShape(triangle, uColor);
}
"""

proc drawTriangle*(c: GraphicsContext, rect: Rect, angleRad: Coord) =
    ## Draws equilateral triangle with current `fillColor`, pointing at `angleRad`
    var color = c.fillColor
    color.a *= c.alpha
    triangleComposition.draw rect:
        setUniform("uAngle", angleRad)
        setUniform("uColor", color)

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

template withClippingRect*(c: GraphicsContext, r: Rect, body: typed) =
    c.applyClippingRect(r, true)
    body
    c.applyClippingRect(r, false)

import private/text_drawing
export text_drawing
