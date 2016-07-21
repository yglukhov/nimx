import types
import opengl
import system_logger
import matrixes
import font
import image
import unicode
import portable_gl
import nimsl.nimsl

export matrixes

type ShaderAttribute = enum
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

proc newShaderProgram(gl: GL, vs, fs: string): ProgramRef {.inline.} = # Deprecated. kinda.
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
    testPolyShaderProgram: ProgramRef
    debugClipColor: Color
    alpha*: Coord
    quadIndexBuffer: BufferRef
    gridIndexBuffer4x4: BufferRef
    vertexes: array[4 * 4 * 128, Coord]

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

proc createQuadIndexBuffer(c: GraphicsContext, numberOfQuads: static[int]): BufferRef =
    result = c.gl.createBuffer()
    c.gl.bindBuffer(c.gl.ELEMENT_ARRAY_BUFFER, result)

    var indexData : array[128 * 6, GLushort]
    var i : GLushort
    while i < 128:
        let id = i * 6
        let vd = i * 4
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

proc newGraphicsContext*(canvas: ref RootObj = nil): GraphicsContext =
    result.new()
    result.gl = newGL(canvas)
    when not defined(ios) and not defined(android) and not defined(js) and not defined(emscripten):
        loadExtensions()

    #result.testPolyShaderProgram = result.gl.newShaderProgram(testPolygonVertexShader, testPolygonFragmentShader)
    result.gl.clearColor(0.93, 0.93, 0.93, 0.0)
    result.alpha = 1.0

    result.gl.enable(result.gl.BLEND)
    result.gl.blendFunc(result.gl.SRC_ALPHA, result.gl.ONE_MINUS_SRC_ALPHA)

    #result.gl.enable(result.gl.CULL_FACE)
    #result.gl.cullFace(result.gl.BACK)

    result.quadIndexBuffer = result.createQuadIndexBuffer(128)
    result.gridIndexBuffer4x4 = result.createGridIndexBuffer(4, 4)

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

template setFillColorUniform(c: GraphicsContext, program: ProgramRef) =
    c.setColorUniform(program, "fillColor", c.fillColor)

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

proc drawRect(bounds, uFillColor, uStrokeColor: vec4,
                    uStrokeWidth: float32,
                    vPos: vec2): vec4 =
    result.drawShape(sdRect(vPos, bounds), uStrokeColor);
    result.drawShape(sdRect(vPos, insetRect(bounds, uStrokeWidth)), uFillColor);

var rectComposition = newCompositionWithNimsl(drawRect)

proc drawRect*(c: GraphicsContext, r: Rect) =
    rectComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)

proc drawEllipse(bounds, uFillColor, uStrokeColor: vec4,
                    uStrokeWidth: float32,
                    vPos: vec2): vec4 =
    result.drawShape(sdEllipseInRect(vPos, bounds), uStrokeColor);
    result.drawShape(sdEllipseInRect(vPos, insetRect(bounds, uStrokeWidth)), uFillColor);

var ellipseComposition = newCompositionWithNimsl(drawEllipse)

proc drawEllipseInRect*(c: GraphicsContext, r: Rect) =
    ellipseComposition.draw r:
        setUniform("uFillColor", c.fillColor)
        setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
        setUniform("uStrokeWidth", c.strokeWidth)

let fontComposition = newComposition("""
attribute vec4 aPosition;

uniform mat4 uModelViewProjectionMatrix;
varying vec2 vTexCoord;

void main() {
    vTexCoord = aPosition.zw;
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);
}
""",
"""
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform sampler2D texUnit;
uniform vec4 fillColor;
uniform float preScale;

varying vec2 vTexCoord;

float thresholdFunc(float glyphScale)
{
    float base = 0.5;
    float baseDev = 0.065;
    float devScaleMin = 0.15;
    float devScaleMax = 0.3;
    return base - ((clamp(glyphScale, devScaleMin, devScaleMax) - devScaleMin) / (devScaleMax - devScaleMin) * -baseDev + baseDev);
}

float spreadFunc(float glyphScale)
{
    float range = 0.06;
    return range / glyphScale;
}

void compose()
{
    float scale = preScale / fwidth(vTexCoord.x);
    scale = abs(scale);
    float aBase = thresholdFunc(scale);
    float aRange = spreadFunc(scale);
    float aMin = max(0.0, aBase - aRange);
    float aMax = min(aBase + aRange, 1.0);

    float dist = texture2D(texUnit, vTexCoord).a;
    float alpha = smoothstep(aMin, aMax, dist);
    gl_FragColor = vec4(fillColor.rgb, alpha * fillColor.a);
}
""", false)

let fontSubpixelComposition = newComposition("""
attribute vec4 aPosition;

uniform mat4 uModelViewProjectionMatrix;
varying vec2 vTexCoord;

void main() {
    vTexCoord = aPosition.zw;
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);
}
""",
"""
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform sampler2D texUnit;
uniform vec4 fillColor;
uniform float alphaMin;
uniform float alphaMax;

varying vec2 vTexCoord;

void subpixelCompose()
{
    vec4 n;
    float shift = dFdx(vTexCoord.x);

    n.x = texture2D(texUnit, vTexCoord.xy - vec2(0.667 * shift, 0.0)).a;
    n.y = texture2D(texUnit, vTexCoord.xy - vec2(0.333 * shift, 0.0)).a;
    n.z = texture2D(texUnit, vTexCoord.xy + vec2(0.333 * shift, 0.0)).a;
    n.w = texture2D(texUnit, vTexCoord.xy + vec2(0.667 * shift, 0.0)).a;
    float c = texture2D(texUnit, vTexCoord.xy).a;

#if 0
    // Blurrier, faster.
    n = smoothstep(alphaMin, alphaMax, n);
    c = smoothstep(alphaMin, alphaMax, c);
#else
    // Sharper, slower.
    vec2 d = min(abs(n.yw - n.xz) * 2., 0.67);
    vec2 lo = mix(vec2(alphaMin), vec2(0.5), d);
    vec2 hi = mix(vec2(alphaMax), vec2(0.5), d);
    n = smoothstep(lo.xxyy, hi.xxyy, n);
    c = smoothstep(lo.x + lo.y, hi.x + hi.y, 2. * c);
#endif

    gl_FragColor = vec4(0.333 * (n.xyz + n.yzw + c), c) * fillColor.a;
}

void compose()
{
    subpixelCompose();
}
""", false)

let fontSubpixelCompositionWithDynamicBase = newComposition("""
attribute vec4 aPosition;

uniform mat4 uModelViewProjectionMatrix;
varying vec2 vTexCoord;

void main() {
    vTexCoord = aPosition.zw;
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);
}
""",
"""
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

uniform sampler2D texUnit;
uniform vec4 fillColor;
uniform float preScale;

varying vec2 vTexCoord;

float thresholdFunc(float glyphScale)
{
    float base = 0.5;
    float baseDev = 0.065;
    float devScaleMin = 0.15;
    float devScaleMax = 0.3;
    return base - ((clamp(glyphScale, devScaleMin, devScaleMax) - devScaleMin) / (devScaleMax - devScaleMin) * -baseDev + baseDev);
}

float spreadFunc(float glyphScale)
{
    float range = 0.06;
    return range / glyphScale;
}

void subpixelCompose()
{
    float scale = preScale / fwidth(vTexCoord.x); // 0.25 * 1.0 / (dFdx(vTexCoord.x) / (16.0 / 1280.0));
    scale = abs(scale);
    float aBase = thresholdFunc(scale);
    float aRange = spreadFunc(scale);
    float aMin = max(0.0, aBase - aRange);
    float aMax = min(aBase + aRange, 1.0);

    vec4 n;
    vec2 shift_vec = dFdx(vTexCoord.xy);
    n.x = texture2D(texUnit, vTexCoord.xy - shift_vec * 0.667).a;
    n.y = texture2D(texUnit, vTexCoord.xy - shift_vec * 0.333).a;
    n.z = texture2D(texUnit, vTexCoord.xy + shift_vec * 0.333).a;
    n.w = texture2D(texUnit, vTexCoord.xy + shift_vec * 0.667).a;
    float c = texture2D(texUnit, vTexCoord.xy).a;

#if 0
    // Blurrier, faster.
    n = smoothstep(aMin, aMax, n);
    c = smoothstep(aMin, aMax, c);
#else
    // Sharper, slower.
    vec2 d = min(abs(n.yw - n.xz) * 2., 0.67);
    vec2 lo = mix(vec2(aMin), vec2(0.5), d);
    vec2 hi = mix(vec2(aMax), vec2(0.5), d);
    n = smoothstep(lo.xxyy, hi.xxyy, n);
    c = smoothstep(lo.x + lo.y, hi.x + hi.y, 2. * c);
#endif

    gl_FragColor = vec4(0.333 * (n.xyz + n.yzw + c), c) * fillColor.a;
}

void compose()
{
    subpixelCompose();
}
""", false)

import math

proc drawTextBase*(c: GraphicsContext, font: Font, pt: var Point, text: string) =
    let gl = c.gl

    gl.enableVertexAttribArray(saPosition.GLuint)
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, c.quadIndexBuffer)

    var texture: TextureRef
    var newTexture: TextureRef
    var n : GLint = 0

    template flush() =
        gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, c.vertexes)
        gl.drawElements(gl.TRIANGLES, n * 6, gl.UNSIGNED_SHORT)

    for ch in text.runes:
        if n > 127:
            flush()
            n = 0

        let off = n * 16
        font.getQuadDataForRune(ch, c.vertexes, off, newTexture, pt)
        if texture != newTexture:
            if n > 0:
                flush()
                for i in 0 ..< 16: c.vertexes[i] = c.vertexes[i + off]
                n = 0

            texture = newTexture
            gl.bindTexture(gl.TEXTURE_2D, texture)
        inc n
        pt.x += font.horizontalSpacing

    if n > 0: flush()

proc drawText(c: GraphicsContext, font: Font, pt: var Point, text: string) =
    # assume orthographic projection with units = screen pixels, origin at top left
    let gl = c.gl
    var cc = gl.getCompiledComposition(fontComposition)
    var subpixelDraw = true

    if hasPostEffect():
        subpixelDraw = false

    when defined(android):
        subpixelDraw = false

    let preScale = 1.0 / 320.0 # magic constant...

    if subpixelDraw:
        cc = gl.getCompiledComposition(fontSubpixelCompositionWithDynamicBase)

        gl.blendColor(c.fillColor.r, c.fillColor.g, c.fillColor.b, c.fillColor.a)
        gl.blendFunc(gl.CONSTANT_COLOR, gl.ONE_MINUS_SRC_COLOR)

    gl.useProgram(cc.program)

    compositionDrawingDefinitions(cc, c, gl)
    setUniform("fillColor", c.fillColor)
    setUniform("preScale", preScale)

    gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
    setupPosteffectUniforms(cc)

    gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
    gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)

    c.drawTextBase(font, pt, text)

    if subpixelDraw:
        gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

proc drawText*(c: GraphicsContext, font: Font, pt: Point, text: string) =
    var p = pt
    c.drawText(font, p, text)

var imageComposition = newComposition """
uniform Image uImage;
uniform vec4 uFromRect;
uniform float uAlpha;

void compose() {
    vec2 destuv = (vPos - bounds.xy) / bounds.zw;
    vec2 duv = uImage.texCoords.zw - uImage.texCoords.xy;
    vec2 srcxy = uImage.texCoords.xy + duv * uFromRect.xy;
    vec2 srczw = uImage.texCoords.xy + duv * uFromRect.zw;
    vec2 uv = srcxy + (srczw - srcxy) * destuv;
    gl_FragColor = texture2D(uImage.tex, uv);
    gl_FragColor.a *= uAlpha;
}
"""

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

let ninePartImageComposition = newComposition("""
attribute vec4 aPosition;

uniform mat4 uModelViewProjectionMatrix;
varying vec2 vTexCoord;

void main() {
    vTexCoord = aPosition.zw;
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);
}
""",
"""
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision mediump float;
#endif

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

        var fr = fromRect
        let sz = i.size
        if fr == zeroRect:
            fr = newRect(zeroPoint, sz)
        else:
            fuv[0] = fuv[0] + fromRect.x / sz.width
            fuv[1] = fuv[1] + fromRect.y / sz.height
            fuv[2] = fuv[2] - (sz.width - fromRect.maxX) / sz.width
            fuv[3] = fuv[3] - (sz.height - fromRect.maxY) / sz.height

        var vertexData: array[16 * 2 * 2, GLfloat]

        template setVertex(index: int, x, y, u, v: GLfloat) =
            vertexData[index * 2 * 2 + 0] = x
            vertexData[index * 2 * 2 + 1] = y
            vertexData[index * 2 * 2 + 2] = u
            vertexData[index * 2 * 2 + 3] = v

        let tml = ml / sz.width
        let tmr = mr / sz.width
        let tmt = mt / sz.height
        let tmb = mb / sz.height

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

        setUniform("uAlpha", alpha)

        gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
        setupPosteffectUniforms(cc)

        gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
        gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)
        gl.bindTexture(gl.TEXTURE_2D, tex)

        gl.enableVertexAttribArray(saPosition.GLuint)
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, c.gridIndexBuffer4x4)

        gl.vertexAttribPointer(saPosition.GLuint, 4, false, 0, vertexData)
        gl.drawElements(gl.TRIANGLE_STRIP, (4 - 1) * 4 * 2, gl.UNSIGNED_SHORT)

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


var lineComposition = newComposition """
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
