import std/[tables, hashes, strutils]
import types, matrixes, context, gpu_types
import wgpu except Color
import nimsl/nimsl

export context

type
  UniformDesc = object
    name: string

  Composition* = object
    definition: string
    id*: int

  CompiledComposition* = ref object
    pipeline*: RenderPipeline
    bindGroupLayout*: BindGroupLayout
    uniforms*: seq[UniformDesc]
    uniformIndex*: Table[string, int]
    iTexIndex*: int

  CompositionDrawState = ref object
    values: Table[string, array[4, float32]]

var programCache {.threadvar.}: Table[Hash, CompiledComposition]
var drawState {.threadvar.}: CompositionDrawState

const commonWgsl = """
const PI: f32 = 3.14159265359;
const TWO_PI: f32 = 6.28318530718;

fn insetRect(rect: vec4f, by: f32) -> vec4f {
  return vec4f(rect.xy + vec2f(by), rect.zw - vec2f(by * 2.0));
}

fn sdAnd(d1: f32, d2: f32) -> f32 { return max(d1, d2); }
fn sdOr(d1: f32, d2: f32) -> f32 { return min(d1, d2); }
fn sdOr3(d1: f32, d2: f32, d3: f32) -> f32 { return sdOr(sdOr(d1, d2), d3); }
fn sdOr4(d1: f32, d2: f32, d3: f32, d4: f32) -> f32 { return sdOr(sdOr3(d1, d2, d3), d4); }
fn sdOr5(d1: f32, d2: f32, d3: f32, d4: f32, d5: f32) -> f32 { return sdOr(sdOr4(d1, d2, d3, d4), d5); }
fn sdOr6(d1: f32, d2: f32, d3: f32, d4: f32, d5: f32, d6: f32) -> f32 { return sdOr(sdOr5(d1, d2, d3, d4, d5), d6); }
fn sdSub(d1: f32, d2: f32) -> f32 { return max(d1, -d2); }

fn sdRect(p0: vec2f, rect: vec4f) -> f32 {
  var p = p0;
  let b = rect.zw / vec2f(2.0);
  p -= rect.xy + b;
  let d = abs(p) - b;
  return min(max(d.x, d.y), 0.0) + length(max(d, vec2f(0.0)));
}
fn sdRectAt(rect: vec4f) -> f32 { return sdRect(vPos, rect); }

fn sdCircle(pos: vec2f, center: vec2f, radius: f32) -> f32 { return distance(pos, center) - radius; }
fn sdCircleAt(center: vec2f, radius: f32) -> f32 { return sdCircle(vPos, center, radius); }

fn sdRoundedRect(pos: vec2f, rect: vec4f, radius: f32) -> f32 {
  let hRect = vec4f(rect.x + radius, rect.y, rect.z - radius * 2.0, rect.w);
  let vRect = vec4f(rect.x, rect.y + radius, rect.z, rect.w - radius * 2.0);
  return sdOr6(
    sdRect(pos, hRect), sdRect(pos, vRect),
    sdCircle(pos, rect.xy + vec2f(radius), radius),
    sdCircle(pos, vec2f(rect.x + radius, rect.y + rect.w - radius), radius),
    sdCircle(pos, rect.xy + rect.zw - vec2f(radius), radius),
    sdCircle(pos, vec2f(rect.x + rect.z - radius, rect.y + radius), radius));
}
fn sdRoundedRectAt(rect: vec4f, radius: f32) -> f32 { return sdRoundedRect(vPos, rect, radius); }

fn sdEllipseInRect(pos: vec2f, rect: vec4f) -> f32 {
  let ab = rect.zw / vec2f(2.0);
  let center = rect.xy + ab;
  let p = pos - center;
  var res = dot(p * p, vec2f(1.0) / (ab * ab)) - 1.0;
  res *= min(ab.x, ab.y);
  return res;
}
fn sdEllipseInRectAt(rect: vec4f) -> f32 { return sdEllipseInRect(vPos, rect); }

fn sdRegularPolygon(st0: vec2f, center: vec2f, radius: f32, n: i32, angle: f32) -> f32 {
  var st = st0 - center;
  let innerAngle = f32(n - 2) * PI / f32(n);
  let pointAngle = atan2(st.y, st.x) - angle;
  let s = floor(pointAngle / (PI - innerAngle));
  let iiAngle = PI - innerAngle;
  let startAngle = angle + iiAngle * s;
  let endAngle = startAngle + iiAngle;
  let p1 = vec2f(cos(startAngle), sin(startAngle));
  let p2 = vec2f(cos(endAngle), sin(endAngle));
  let d = p2 - p1;
  return ((d.y * st.x - d.x * st.y) + (p2.x * p1.y - p2.y * p1.x) * radius) / distance(p1, p2);
}
fn sdRegularPolygonAt(center: vec2f, radius: f32, n: i32, angle: f32) -> f32 { return sdRegularPolygon(vPos, center, radius, n, angle); }

fn newGrayColor(v: f32) -> vec4f { return vec4f(v, v, v, 1.0); }
fn newGrayColorA(v: f32, a: f32) -> vec4f { return vec4f(v, v, v, a); }
fn gradient(pos: f32, startColor: vec4f, endColor: vec4f) -> vec4f { return mix(startColor, endColor, pos); }
fn gradient5(pos: f32, startColor: vec4f, sN: f32, cN: vec4f, endColor: vec4f) -> vec4f { return mix(gradient(pos / sN, startColor, cN), endColor, smoothstep(sN, 1.0, pos)); }
fn gradient7(pos: f32, startColor: vec4f, s1: f32, c1: vec4f, sN: f32, cN: vec4f, endColor: vec4f) -> vec4f { return mix(gradient5(pos / sN, startColor, s1 / sN, c1, cN), endColor, smoothstep(sN, 1.0, pos)); }
fn gradient9(pos: f32, startColor: vec4f, s1: f32, c1: vec4f, s2: f32, c2: vec4f, sN: f32, cN: vec4f, endColor: vec4f) -> vec4f { return mix(gradient7(pos / sN, startColor, s1 / sN, c1, s2 / sN, c2, cN), endColor, smoothstep(sN, 1.0, pos)); }

fn rgb2hsv(c: vec3f) -> vec3f {
  let K = vec4f(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
  let p = mix(vec4f(c.bg, K.wz), vec4f(c.gb, K.xy), step(c.b, c.g));
  let q = mix(vec4f(p.xyw, c.r), vec4f(c.r, p.yzx), step(p.x, c.r));
  let d = q.x - min(q.w, q.y);
  let e = 1.0e-10;
  return vec3f(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

fn hsv2rgb(c: vec3f) -> vec3f {
  let K = vec4f(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  let p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, vec3f(0.0), vec3f(1.0)), c.y);
}

fn fillAlpha(dist: f32) -> f32 {
  let d = fwidth(dist);
  return 1.0 - smoothstep(-d, d, dist);
}

fn drawShape(dist: f32, color: vec4f) {
  outColor = mix(outColor, color, fillAlpha(dist));
}
fn drawInitialShape(dist: f32, color: vec4f) {
  outColor = color;
  outColor.a *= fillAlpha(dist);
}
fn blendShape(dist: f32, color: vec4f) {
  outColor = mix(outColor, color, fillAlpha(dist) * color.a);
}
"""

proc newComposition*(vsDef, fsDef: static[string], requiresPrequel: bool = true, precision: string = "highp"): Composition =
  result.definition = fsDef
  result.id = hash(fsDef) !& hash(vsDef) !& hash(requiresPrequel) !& hash(precision)

template newComposition*(definition: static[string], requiresPrequel: bool = true): Composition =
  newComposition("", definition, requiresPrequel)

template newCompositionWithNimsl*(mainProc: typed): Composition =
  newComposition(wgslShader(mainProc), false)

proc extractUniforms(src: string): seq[UniformDesc] =
  var seen = initTable[string, bool]()
  var i = 0
  while true:
    let p = src.find("uni.", i)
    if p < 0: break
    var j = p + 4
    while j < src.len and (src[j].isAlphaNumeric or src[j] == '_'): inc j
    let name = src[p + 4 ..< j]
    if name notin ["uModelViewProjectionMatrix", "bounds", "uBounds"] and not seen.hasKey(name):
      seen[name] = true
      result.add(UniformDesc(name: name))
    i = j

proc buildShader(comp: Composition, uniforms: seq[UniformDesc]): string =
  result = "struct Uniforms {\n"
  result &= "  uModelViewProjectionMatrix: mat4x4f,\n  bounds: vec4f,\n  uBounds: vec4f,\n"
  for u in uniforms:
    result &= "  " & u.name & ": vec4f,\n"
  result &= "}\n@group(0) @binding(0) var<uniform> uni: Uniforms;\n"
  result &= "var<private> vPos: vec2f;\nvar<private> outColor: vec4f;\n"
  result &= "struct VertexOutput { @builtin(position) position: vec4f, @location(0) vPos: vec2f }\n"
  result &= "@vertex fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> VertexOutput {\n"
  result &= "  var positions = array<vec2f, 4>(vec2f(0.0, 0.0), vec2f(0.0, 1.0), vec2f(1.0, 0.0), vec2f(1.0, 1.0));\n"
  result &= "  let aPosition = positions[vertexIndex];\n  var out: VertexOutput;\n  out.vPos = uni.uBounds.xy + aPosition * uni.uBounds.zw;\n  out.position = uni.uModelViewProjectionMatrix * vec4f(out.vPos, 0.0, 1.0);\n  return out;\n}\n"
  result &= commonWgsl
  result &= comp.definition & "\n"
  result &= "@fragment fn fs_main(in: VertexOutput) -> @location(0) vec4f { vPos = in.vPos; outColor = vec4f(0.0); compose(); return outColor; }\n"

proc createPipeline(ctx: GraphicsContext, shaderCode: string, bgl: BindGroupLayout): RenderPipeline =
  let shader = ctx.device.createShaderModule(shaderCode)
  var frag: FragmentState
  frag.module = shader
  frag.entryPoint = "fs_main"
  var blend: BlendState
  blend.color.srcFactor = bfSrcAlpha
  blend.color.dstFactor = bfOneMinusSrcAlpha
  blend.color.operation = boAdd
  blend.alpha.srcFactor = bfOne
  blend.alpha.dstFactor = bfOneMinusSrcAlpha
  blend.alpha.operation = boAdd
  var target: ColorTargetState
  target.format = ctx.surfaceFormat
  target.blend = addr blend
  target.writeMask = cwmAll
  frag.targetCount = 1
  frag.targets = cast[ptr UncheckedArray[ColorTargetState]](addr target)
  var layouts: array[1, BindGroupLayout]
  layouts[0] = bgl
  var pld: PipelineLayoutDescriptor
  pld.bindGroupLayoutCount = 1
  pld.bindGroupLayouts = addr layouts[0]
  var desc: RenderPipelineDescriptor
  desc.layout = ctx.device.createPipelineLayout(pld)
  desc.vertex.module = shader
  desc.vertex.entryPoint = "vs_main"
  desc.fragment = addr frag
  desc.primitive.topology = ptTriangleStrip
  desc.primitive.stripIndexFormat = ifUndefined
  desc.primitive.frontFace = ffCCW
  desc.primitive.cullMode = cmNone
  desc.multisample.count = 1
  desc.multisample.mask = uint32.high
  ctx.device.createRenderPipeline(desc)

proc compileComposition*(ctx: GraphicsContext, comp: Composition, cchash: Hash, options: int): CompiledComposition =
  result.new()
  result.uniforms = extractUniforms(comp.definition)
  for i, u in result.uniforms: result.uniformIndex[u.name] = i
  var entries: array[1, BindGroupLayoutEntry]
  entries[0].binding = 0
  entries[0].visibility = {ssVertex, ssFragment}
  entries[0].buffer.typ = bbtUniform
  var bglDesc: BindGroupLayoutDescriptor
  bglDesc.entryCount = 1
  bglDesc.entries = cast[ptr UncheckedArray[BindGroupLayoutEntry]](addr entries)
  result.bindGroupLayout = ctx.device.createBindGroupLayout(bglDesc)
  result.pipeline = ctx.createPipeline(buildShader(comp, result.uniforms), result.bindGroupLayout)
  programCache[cchash] = result

proc getCompiledComposition*(ctx: GraphicsContext, comp: Composition, options: int = 0): CompiledComposition =
  let cchash = !$(comp.id !& options !& hash(ctx.surfaceFormat.int))
  result = programCache.getOrDefault(cchash)
  if result.isNil:
    result = ctx.compileComposition(comp, cchash, options)
  result.iTexIndex = 0

proc setCompositionUniform*(name: string, v: float32) =
  if drawState.isNil: return
  drawState.values[name] = [v, 0, 0, 0]
proc setCompositionUniform*(name: string, v: int32) = setCompositionUniform(name, v.float32)
proc setCompositionUniform*(name: string, v: int) = setCompositionUniform(name, v.float32)
proc setCompositionUniform*(name: string, v: Point) =
  if drawState.isNil: return
  drawState.values[name] = [v.x, v.y, 0, 0]
proc setCompositionUniform*(name: string, v: Size) =
  if drawState.isNil: return
  drawState.values[name] = [v.width, v.height, 0, 0]
proc setCompositionUniform*(name: string, v: Rect) =
  if drawState.isNil: return
  drawState.values[name] = [v.x, v.y, v.width, v.height]
proc setCompositionUniform*(name: string, v: Color) =
  if drawState.isNil: return
  drawState.values[name] = [v.r, v.g, v.b, v.a]
proc setCompositionUniform*(name: string, v: Vector2) =
  if drawState.isNil: return
  drawState.values[name] = [v[0], v[1], 0, 0]
proc setCompositionUniform*(name: string, v: Vector3) =
  if drawState.isNil: return
  drawState.values[name] = [v[0], v[1], v[2], 0]
proc setCompositionUniform*(name: string, v: Matrix4) = discard

template setUniform*(name: string, value: untyped) = setCompositionUniform(name, value)

proc drawCompiled(ctx: GraphicsContext, cc: CompiledComposition, r: Rect) =
  if not ctx.frameActive or cc.pipeline.isNil: return
  var data = newSeq[float32](16 + 4 + 4 + cc.uniforms.len * 4)
  for i in 0 ..< 16: data[i] = ctx.transform[i]
  data[16] = r.x; data[17] = r.y; data[18] = r.width; data[19] = r.height
  data[20] = r.x; data[21] = r.y; data[22] = r.width; data[23] = r.height
  for i, u in cc.uniforms:
    let val = if not drawState.isNil and drawState.values.hasKey(u.name): drawState.values[u.name] else: [0'f32, 0, 0, 0]
    let off = 24 + i * 4
    data[off + 0] = val[0]; data[off + 1] = val[1]; data[off + 2] = val[2]; data[off + 3] = val[3]
  var bd: BufferDescriptor
  bd.size = (data.len * sizeof(float32)).uint64
  bd.usage = {buCopyDst, buUniform}
  let ub = ctx.device.createBuffer(bd)
  ctx.device.getQueue().writeBuffer(ub, 0, addr data[0], data.len * sizeof(float32))
  var bge: array[1, BindGroupEntry]
  bge[0].binding = 0
  bge[0].buffer = ub
  bge[0].size = bd.size
  var bgd: BindGroupDescriptor
  bgd.layout = cc.bindGroupLayout
  bgd.entryCount = 1
  bgd.entries = cast[ptr UncheckedArray[BindGroupEntry]](addr bge)
  let bg = ctx.device.createBindGroup(bgd)
  ctx.renderPass.setPipeline(cc.pipeline)
  ctx.renderPass.setBindGroup(0, bg)
  ctx.renderPass.draw(4, 1, 0, 0)

var overdrawValue {.threadvar.}: float32
var DIPValue {.threadvar.}: int
proc GetOverdrawValue*(): float32 = overdrawValue / 1000
proc ResetOverdrawValue*() = overdrawValue = 0
proc GetDIPValue*(): int = DIPValue
proc ResetDIPValue*() = DIPValue = 0

template draw*(comp: Composition, r: Rect, code: untyped) =
  block:
    let ctx = currentContext()
    let cc = ctx.getCompiledComposition(comp)
    overdrawValue += r.size.width * r.size.height
    DIPValue += 1
    drawState = CompositionDrawState(values: initTable[string, array[4, float32]]())
    code
    ctx.drawCompiled(cc, r)
    drawState = nil

template draw*(comp: Composition, r: Rect) =
  comp.draw r:
    discard

type PostEffect* = ref object
proc newPostEffect*(definition: static[string], mainProcName: string, argTypes: openarray[string]): PostEffect = PostEffect()
template newPostEffect*(definition: static[string], mainProcName: string): PostEffect = newPostEffect(definition, mainProcName, [])
template pushPostEffect*(pe: PostEffect, args: varargs[untyped]) = discard
template popPostEffect*() = discard
template hasPostEffect*(): bool = false
proc setupPosteffectUniforms*(cc: CompiledComposition) = discard

template compositionDrawingDefinitions*(cc: CompiledComposition, ctx: GraphicsContext, gpu: untyped) =
  template setUniform(name: string, value: untyped) = setCompositionUniform(name, value)
  template uniformLocation(name: string): int = 0
