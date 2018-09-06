import context, types, portable_gl, image
import private/helper_macros
import strutils, tables, hashes
import nimsl/nimsl

export portable_gl
export context

const commonDefinitions = """
#define PI 3.14159265359
#define TWO_PI 6.28318530718

vec4 insetRect(vec4 rect, float by) {
    return vec4(rect.xy + by, rect.zw - by * 2.0);
}

"""

const distanceSetOperations = """
float sdAnd(float d1, float d2) {
    return max(d1, d2);
}

float sdOr(float d1, float d2) {
    return min(d1, d2);
}

float sdOr(float d1, float d2, float d3) {
    return sdOr(sdOr(d1, d2), d3);
}

float sdOr(float d1, float d2, float d3, float d4) {
    return sdOr(sdOr(d1, d2, d3), d4);
}

float sdOr(float d1, float d2, float d3, float d4, float d5) {
    return sdOr(sdOr(d1, d2, d3, d4), d5);
}

float sdOr(float d1, float d2, float d3, float d4, float d5, float d6) {
    return sdOr(sdOr(d1, d2, d3, d4, d5), d6);
}

float sdSub(float d1, float d2) {
    return max(d1, -d2);
}
"""

const distanceFunctions = """
float sdRect(vec2 p, vec4 rect) {
    vec2 b = rect.zw / 2.0;
    p -= rect.xy + b;
    vec2 d = abs(p) - b;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdRect(vec4 rect) {
    return sdRect(vPos, rect);
}

float sdCircle(vec2 pos, vec2 center, float radius) {
    return distance(pos, center) - radius;
}

float sdCircle(vec2 center, float radius) {
    return sdCircle(vPos, center, radius);
}

float sdRoundedRect(vec2 pos, vec4 rect, float radius) {
    vec4 hRect = vec4(rect.x + radius, rect.y, rect.z - radius * 2.0, rect.w);
    vec4 vRect = vec4(rect.x, rect.y + radius, rect.z, rect.w - radius * 2.0);
    return sdOr(
        sdRect(pos, hRect), sdRect(pos, vRect),
        sdCircle(pos, rect.xy + radius, radius),
        sdCircle(pos, vec2(rect.x + radius, rect.y + rect.w - radius), radius),
        sdCircle(pos, rect.xy + rect.zw - radius, radius),
        sdCircle(pos, vec2(rect.x + rect.z - radius, rect.y + radius), radius));
}

float sdRoundedRect(vec4 rect, float radius) {
    return sdRoundedRect(vPos, rect, radius);
}

float sdEllipseInRect(vec2 pos, vec4 rect) {
    vec2 ab = rect.zw / 2.0;
    vec2 center = rect.xy + ab;
    vec2 p = pos - center;
    float res = dot(p * p, 1.0 / (ab * ab)) - 1.0;
    res *= min(ab.x, ab.y);
    return res;
}

float sdEllipseInRect(vec4 rect) {
    return sdEllipseInRect(vPos, rect);
}

float sdRegularPolygon(vec2 st, vec2 center, float radius, int n, float angle) {
    st -= center;
    float innerAngle = float(n - 2) * PI / float(n);
    float pointAngle = atan(st.y, st.x) - angle;

    float s = floor(pointAngle / (PI - innerAngle));
    float iiAngle = PI - innerAngle;
    float startAngle = angle + iiAngle * s;
    float endAngle = startAngle + iiAngle;

    vec2 p1 = vec2(cos(startAngle), sin(startAngle));
    vec2 p2 = vec2(cos(endAngle), sin(endAngle));

    vec2 d = p2 - p1;

    return ((d.y * st.x - d.x * st.y) + (p2.x * p1.y - p2.y * p1.x)*radius) / distance(p1, p2);
}

float sdRegularPolygon(vec2 center, float radius, int n) {
    return sdRegularPolygon(vPos, center, radius, n, 0.0);
}

float sdRegularPolygon(vec2 center, float radius, int n, float angle) {
    return sdRegularPolygon(vPos, center, radius, n, angle);
}

float sdStrokeRect(vec2 pos, vec4 rect, float width) {
    return sdSub(sdRect(pos, rect),
                 sdRect(pos, insetRect(rect, width)));
}

float sdStrokeRect(vec4 rect, float width) {
    return sdStrokeRect(vPos, rect, width);
}

float sdStrokeRoundedRect(vec2 pos, vec4 rect, float radius, float width) {
    return sdSub(sdRoundedRect(pos, rect, radius),
                 sdRoundedRect(pos, insetRect(rect, width), radius - width));
}

float sdStrokeRoundedRect(vec4 rect, float radius, float width) {
    return sdStrokeRoundedRect(vPos, rect, radius, width);
}
"""

const colorOperations = """
vec4 newGrayColor(float v, float a) {
    return vec4(v, v, v, a);
}

vec4 newGrayColor(float v) {
    return newGrayColor(v, 1.0);
}

vec4 gradient(float pos, vec4 startColor, vec4 endColor) {
    return mix(startColor, endColor, pos);
}

vec4 gradient(float pos, vec4 startColor, float sN, vec4 cN, vec4 endColor) {
    return mix(gradient(pos / sN, startColor, cN),
        endColor, smoothstep(sN, 1.0, pos));
}

vec4 gradient(float pos, vec4 startColor, float s1, vec4 c1, float sN, vec4 cN, vec4 endColor) {
    return mix(gradient(pos / sN, startColor, s1 / sN, c1, cN),
        endColor, smoothstep(sN, 1.0, pos));
}

vec4 gradient(float pos, vec4 startColor, float s1, vec4 c1, float s2, vec4 c2, float sN, vec4 cN, vec4 endColor) {
    return mix(gradient(pos / sN, startColor, s1 / sN, c1, s2 / sN, c2, cN),
        endColor, smoothstep(sN, 1.0, pos));
}

// Color conversions
//http://gamedev.stackexchange.com/questions/59797/glsl-shader-change-hue-saturation-brightness
vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
"""

const compositionFragmentFunctions = """
float fillAlpha(float dist) {
    float d = fwidth(dist);
    return 1.0 - smoothstep(-d, d, dist);
//    return 1.0 - step(0.0, dist); // No antialiasing
}

vec4 composeDistanceFuncDebug(float dist) {
    vec4 result = vec4(smoothstep(-30.0, -10.0, dist), 0, 0, 1.0);
    if (dist > 0.0) {
        result = vec4(0.5, 0.5, 1.0 - smoothstep(0.0, 30.0, dist), 1.0);
    }
    if (dist > -5.0 && dist <= 0.0) result = vec4(0.0, 1, 0, 1);
    return result;
}

// Draw shape depending on underlying fragments
void drawShape(float dist, vec4 color) {
    gl_FragColor = mix(gl_FragColor, color, fillAlpha(dist));
}

// Draw shape without taking underlying fragments in account
void drawInitialShape(float dist, vec4 color) {
    gl_FragColor = color;
    gl_FragColor.w *= fillAlpha(dist);
}

// Same as drawShape, but respects source alpha
void blendShape(float dist, vec4 color) {
    gl_FragColor = mix(gl_FragColor, color, fillAlpha(dist) * color.a);
}
"""

proc fillAlpha*(dist: float32): float32 =
    let d = fwidth(dist)
    result = 1.0 - smoothstep(-d, d, dist)
    #    return 1.0 - step(0.0, dist); # No antialiasing

proc drawShape*(res: var Vec4, dist: float32, color: Vec4) =
    res = mix(res, color, fillAlpha(dist))

proc drawInitialShape*(res: var Vec4, dist: float32, color: Vec4) =
    res = color
    res.w *= fillAlpha(dist)

proc sdRect*(p: Vec2, rect: Vec4): float32 =
    let b = rect.zw / 2.0
    let dp = p - (rect.xy + b)
    let d = abs(dp) - b
    result = min(max(d.x, d.y), 0.0) + length(max(d, 0.0))

proc sdEllipseInRect*(pos: Vec2, rect: Vec4): float32 =
    let ab = rect.zw / 2.0
    let center = rect.xy + ab
    let p = pos - center
    result = dot(p * p, 1.0 / (ab * ab)) - 1.0
    result *= min(ab.x, ab.y)

proc insetRect*(r: Vec4, by: float32): Vec4 = newVec4(r.xy + by, r.zw - by * 2.0)

proc vertexShader(aPosition: Vec2, uModelViewProjectionMatrix: Mat4, uBounds: Vec4, vPos: var Vec2): Vec4 =
    vPos = uBounds.xy + aPosition * uBounds.zw
    result = uModelViewProjectionMatrix * newVec4(vPos, 0.0, 1.0);

const vertexShaderCode = getGLSLVertexShader(vertexShader)

type
    PostEffect* = ref object
        source*: string
        setupProc*: proc(cc: CompiledComposition)
        mainProcName*: string
        seenFlag: bool # Used on compilation phase, should not be used elsewhere.
        id*: int
        argTypes*: seq[string]

    CompiledComposition* = ref object
        program*: ProgramRef
        uniformLocations*: seq[UniformLocation]
        iTexIndex*: GLint
        iUniform*: int

    Composition* = object
        definition: string
        vsDefinition: string # Vertex shader source code
        precision: string
        requiresPrequel: bool
        options*: int
        id*: int

var programCache = initTable[Hash, CompiledComposition]()


const posAttr : GLuint = 0

proc replaceSymbolsInLine(syms: openarray[string], ln: string): string {.compileTime.} =
    result = ln
    if result.len != 0:
        for s in syms:
            result = result.replaceWord(s & ".tex", s & "_tex")
            result = result.replaceWord(s & ".texCoords", s & "_texCoords")

#[
proc uniforNamesFromShaderCode(code: string): seq[string] =
    result = newSeq[string]()
    var loc = 0
    while true:
        const prefix = "uniform "
        loc = code.find(prefix, loc)
        if loc < 0: break
        loc += prefix.len
        loc = code.find(" ", loc)
        if loc < 0: break
        inc loc
        let e = code.find(";", loc)
        if e < 0: break
        result.add(code.substr(loc, e - 1))
        loc = e
]#

proc preprocessDefinition(definition: string): string {.compileTime.} =
    result = ""
    var symbolsToReplace = newSeq[string]()
    for ln in definition.splitLines():
        const prefix = "uniform Image "
        if ln.startsWith(prefix):
            let uniformName = ln.substr(prefix.len, ln.len - 2)
            symbolsToReplace.add(uniformName)
            result &= "\Luniform sampler2D " & uniformName & "_tex;\Luniform vec4 " & uniformName & "_texCoords;"
        else:
            result &= "\L" & replaceSymbolsInLine(symbolsToReplace, ln)

proc newPostEffect*(definition: static[string], mainProcName: string, argTypes: openarray[string]): PostEffect =
    const preprocessedDefinition = preprocessDefinition(definition)
    result.new()
    result.source = preprocessedDefinition
    result.mainProcName = mainProcName
    result.argTypes = @argTypes
    result.id = hash(preprocessedDefinition)

template newPostEffect*(definition: static[string], mainProcName: string): PostEffect =
    newPostEffect(definition, mainProcName, [])

proc newComposition*(vsDef, fsDef: static[string], requiresPrequel: bool = true, precision: string = "highp"): Composition =
    const preprocessedDefinition = preprocessDefinition(fsDef)
    result.definition = preprocessedDefinition
    result.vsDefinition = vsDef
    result.requiresPrequel = requiresPrequel
    result.precision = precision
    result.id = hash(preprocessedDefinition)

template newComposition*(definition: static[string], requiresPrequel: bool = true): Composition =
    newComposition("", definition, requiresPrequel)

template newCompositionWithNimsl*(mainProc: typed): Composition =
    newComposition(getGLSLFragmentShader(mainProc, "compose"), false)

type PostEffectStackElem = object
    postEffect: PostEffect
    setupProc*: proc(cc: CompiledComposition)

var postEffectStack = newSeq[PostEffectStackElem]()
var postEffectIdStack = newSeq[Hash]()

proc getPostEffectUniformName(postEffectIndex, argIndex: int, output: var string) =
    output &= "uPE_"
    output &= $postEffectIndex
    output &= "_"
    output &= $argIndex

proc postEffectUniformName(postEffectIndex, argIndex: int): string =
    result = ""
    getPostEffectUniformName(postEffectIndex, argIndex, result)

proc compileComposition*(gl: GL, comp: Composition, cchash: Hash): CompiledComposition =
    var fragmentShaderCode = ""

    if (comp.definition.len != 0 and comp.definition.find("GL_OES_standard_derivatives") < 0) or comp.requiresPrequel:
        fragmentShaderCode &= """
            #ifdef GL_ES
            #extension GL_OES_standard_derivatives : enable
            precision """ & comp.precision & """ float;
            #endif
            """

    if comp.requiresPrequel:
        fragmentShaderCode &= """
            varying vec2 vPos;
            uniform vec4 bounds;
            """
        fragmentShaderCode &= commonDefinitions &
            distanceSetOperations &
            distanceFunctions &
            compositionFragmentFunctions &
            colorOperations

    var options = ""
    if comp.options != 0:
        for i in 0 ..< 32:
            if ((1 shl i) and comp.options) != 0:
                options &= "#define OPTION_" & $(i + 1) & "\n"
        fragmentShaderCode &= options

    fragmentShaderCode &= comp.definition

    let ln = postEffectStack.len
    var i = 0
    while i < ln:
        let pe = postEffectStack[i].postEffect
        if not pe.seenFlag:
            fragmentShaderCode &= pe.source
            pe.seenFlag = true
        for j, argType in pe.argTypes:
            fragmentShaderCode &= "uniform " & argType & " "
            getPostEffectUniformName(i, j, fragmentShaderCode)
            fragmentShaderCode &= ";";
        inc i

    i = 0
    while i < ln:
        postEffectStack[i].postEffect.seenFlag = false
        inc i

    fragmentShaderCode &= """void main() { gl_FragColor = vec4(0.0); compose(); """
    i = postEffectStack.len - 1
    while i >= 0:
        fragmentShaderCode &= postEffectStack[i].postEffect.mainProcName & "("
        for j in 0 ..< postEffectStack[i].postEffect.argTypes.len:
            if j != 0:
                fragmentShaderCode &= ","
            getPostEffectUniformName(i, j, fragmentShaderCode)
        fragmentShaderCode &= ");"
        dec i
    fragmentShaderCode &= "}"

    result.new()
    let vsCode = if comp.vsDefinition.len == 0:
            options & vertexShaderCode
        else:
            options & comp.vsDefinition
    result.program = gl.newShaderProgram(vsCode, fragmentShaderCode, [(posAttr, "aPosition")])
    result.uniformLocations = newSeq[UniformLocation]()
    programCache[cchash] = result

proc unwrapPointArray(a: openarray[Point]): seq[GLfloat] =
    result = newSeq[GLfloat](a.len * 2)
    var i = 0
    for p in a:
        result[i] = p.x
        inc i
        result[i] = p.y
        inc i

var texQuad : array[4, GLfloat]

template compositionDrawingDefinitions*(cc: CompiledComposition, ctx: GraphicsContext, gl: GL) =
    template uniformLocation(name: string): UniformLocation =
        inc cc.iUniform
        if cc.uniformLocations.len - 1 < cc.iUniform:
            cc.uniformLocations.add(gl.getUniformLocation(cc.program, name))
        cc.uniformLocations[cc.iUniform]

    template setUniform(name: string, v: Rect) {.hint[XDeclaredButNotUsed]: off.} =
        ctx.setRectUniform(uniformLocation(name), v)

    template setUniform(name: string, v: Point) {.hint[XDeclaredButNotUsed]: off.} =
        ctx.setPointUniform(uniformLocation(name), v)

    template setUniform(name: string, v: Size) {.hint[XDeclaredButNotUsed]: off.} =
        setUniform(name, newPoint(v.width, v.height))

    template setUniform(name: string, v: openarray[Point]) {.hint[XDeclaredButNotUsed]: off.} =
        when defined(js):
            gl.uniform2fv(uniformLocation(name), unwrapPointArray(v))
        else:
            gl.uniform2fv(uniformLocation(name), GLsizei(v.len), cast[ptr GLfloat](unsafeAddr v[0]))

    template setUniform(name: string, v: Color) {.hint[XDeclaredButNotUsed]: off.} =
        ctx.setColorUniform(uniformLocation(name), v)

    template setUniform(name: string, v: GLfloat) {.hint[XDeclaredButNotUsed]: off.}  =
        gl.uniform1f(uniformLocation(name), v)

    template setUniform(name: string, v: GLint) {.hint[XDeclaredButNotUsed]: off.}  =
        gl.uniform1i(uniformLocation(name), v)

    template setUniform(name: string, v: Vector3) {.hint[XDeclaredButNotUsed]: off.}  =
        gl.uniform3fv(uniformLocation(name), v)

    template setUniform(name: string, v: Vector2) {.hint[XDeclaredButNotUsed]: off.}  =
        gl.uniform2fv(uniformLocation(name), v)

    template setUniform(name: string, v: Matrix4) {.hint[XDeclaredButNotUsed]: off.}  =
        gl.uniformMatrix4fv(uniformLocation(name), false, v)

    template setUniform(name: string, tex: TextureRef) {.hint[XDeclaredButNotUsed]: off.} =
        gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
        gl.bindTexture(gl.TEXTURE_2D, tex)
        gl.uniform1i(uniformLocation(name), cc.iTexIndex)
        inc cc.iTexIndex

    template setUniform(name: string, i: Image) {.hint[XDeclaredButNotUsed]: off.} =
        gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
        gl.bindTexture(gl.TEXTURE_2D, getTextureQuad(i, gl, texQuad))
        gl.uniform4fv(uniformLocation(name & "_texCoords"), texQuad)
        gl.uniform1i(uniformLocation(name & "_tex"), cc.iTexIndex)
        inc cc.iTexIndex

template pushPostEffect*(pe: PostEffect, body: untyped) {.deprecated.} =
    # Usage of this template implies explicit uniforms, which doesn't work in
    # general case. This template will be deleted soon.
    postEffectStack.add(PostEffectStackElem(postEffect: pe, setupProc: proc(cc: CompiledComposition) =
        let ctx = currentContext()
        let gl = ctx.gl
        compositionDrawingDefinitions(cc, ctx, gl)
        body
    ))

    let oh = if postEffectIdStack.len > 0: postEffectIdStack[^1] else: 0
    postEffectIdStack.add(oh !& pe.id)

template pushPostEffect*(pe: PostEffect, args: varargs[untyped]) =
    let stackLen = postEffectIdStack.len
    postEffectStack.add(PostEffectStackElem(postEffect: pe, setupProc: proc(cc: CompiledComposition) =
        let ctx = currentContext()
        let gl = ctx.gl
        compositionDrawingDefinitions(cc, ctx, gl)
        var j = 0
        staticFor uni in args:
            setUniform(postEffectUniformName(stackLen, j), uni)
            inc j
    ))

    let oh = if stackLen > 0: postEffectIdStack[^1] else: 0
    postEffectIdStack.add(oh !& pe.id)

template popPostEffect*() =
    postEffectStack.setLen(postEffectStack.len - 1)
    postEffectIdStack.setLen(postEffectIdStack.len - 1)

template hasPostEffect*(): bool =
    postEffectStack.len > 0

template getCompiledComposition*(gl: GL, comp: Composition): CompiledComposition =
    let pehash = if postEffectIdStack.len > 0: postEffectIdStack[^1] else: 0
    let cchash = !$(pehash !& comp.id !& comp.options)
    var cc = programCache.getOrDefault(cchash)
    if cc.isNil:
        cc = gl.compileComposition(comp, cchash)
    cc.iUniform = -1
    cc.iTexIndex = 0
    cc

template setupPosteffectUniforms*(cc: CompiledComposition) =
    for pe in postEffectStack:
        pe.setupProc(cc)

var overdrawValue = 0'f32
template GetOverdrawValue*() : float32 = overdrawValue / 1000

template ResetOverdrawValue*() =
    overdrawValue = 0

var DIPValue = 0
template GetDIPValue*() : int =
    DIPValue

template ResetDIPValue*() =
    DIPValue = 0

template draw*(comp: var Composition, r: Rect, code: untyped): typed =
    let ctx = currentContext()
    let gl = ctx.gl
    let cc = gl.getCompiledComposition(comp)
    gl.useProgram(cc.program)

    overdrawValue += r.size.width * r.size.height
    DIPValue += 1

    const componentCount = 2
    const vertexCount = 4
    gl.bindBuffer(gl.ARRAY_BUFFER, ctx.singleQuadBuffer)
    gl.enableVertexAttribArray(posAttr)
    gl.vertexAttribPointer(posAttr, componentCount, gl.FLOAT, false, 0, 0)

    compositionDrawingDefinitions(cc, ctx, gl)

    gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, ctx.transform)

    setUniform("bounds", r) # This is for fragment shader
    setUniform("uBounds", r) # This is for vertex shader

    setupPosteffectUniforms(cc)

    code
    gl.drawArrays(gl.TRIANGLE_FAN, 0, vertexCount)
    gl.bindBuffer(gl.ARRAY_BUFFER, invalidBuffer)

template draw*(comp: var Composition, r: Rect): typed =
    comp.draw r:
        discard
