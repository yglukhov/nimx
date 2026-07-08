import std/[math]
import ./[types, matrixes, image, gpu_types]
import wgpu except Color

export matrixes
export gpu_types

type
  ShaderAttribute* = enum
    saPosition
    saColor

  Transform3D* = Matrix4

  ColorVertex = object
    x, y: float32
    r, g, b, a: float32

  TexturedVertex = object
    x, y: float32
    u, v: float32
    r, g, b, a: float32

  GraphicsContext* = ref object of RootObj
    fillColor*: Color
    strokeColor*: Color
    strokeWidth*: Coord
    alpha*: Coord
    pTransform: Transform3D
    vertexes*: array[4 * 4 * 128, Coord]
    device*: Device
    surface*: Surface
    surfaceFormat*: TextureFormat
    surfaceWidth*, surfaceHeight*: int
    configured*: bool
    frameActive*: bool
    currentTexture: Texture
    currentView: TextureView
    encoder: CommandEncoder
    renderPass*: RenderPassEncoder
    triPipeline, linePipeline, stripPipeline: RenderPipeline
    texturedPipeline, sdfTexturedPipeline: RenderPipeline
    textureBindGroupLayout: BindGroupLayout
    sampler: Sampler

var gCurrentContext {.threadvar.}: GraphicsContext

const colorShader = """
struct VertexInput {
  @location(0) position: vec2f,
  @location(1) color: vec4f,
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) color: vec4f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
  var out: VertexOutput;
  out.position = vec4f(in.position, 0.0, 1.0);
  out.color = in.color;
  return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
  return in.color;
}
"""

const texturedShader = """
struct VertexInput {
  @location(0) position: vec2f,
  @location(1) uv: vec2f,
  @location(2) color: vec4f,
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
  @location(1) color: vec4f,
};

@group(0) @binding(0) var texSampler: sampler;
@group(0) @binding(1) var tex: texture_2d<f32>;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
  var out: VertexOutput;
  out.position = vec4f(in.position, 0.0, 1.0);
  out.uv = in.uv;
  out.color = in.color;
  return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
  return textureSample(tex, texSampler, in.uv) * in.color;
}
"""

const sdfTexturedShader = """
struct VertexInput {
  @location(0) position: vec2f,
  @location(1) uv: vec2f,
  @location(2) color: vec4f,
};

struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
  @location(1) color: vec4f,
};

@group(0) @binding(0) var texSampler: sampler;
@group(0) @binding(1) var tex: texture_2d<f32>;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
  var out: VertexOutput;
  out.position = vec4f(in.position, 0.0, 1.0);
  out.uv = in.uv;
  out.color = in.color;
  return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
  let dist = textureSample(tex, texSampler, in.uv).r;
  let d = fwidth(dist);
  let alpha = smoothstep(0.5 - d, 0.5 + d, dist);
  return vec4f(in.color.rgb, alpha * in.color.a);
}
"""

proc newGraphicsContext*(canvas: ref RootObj = nil): GraphicsContext =
  result.new()
  result.fillColor = blackColor()
  result.strokeColor = blackColor()
  result.strokeWidth = 1
  result.alpha = 1
  result.pTransform.loadIdentity()
  if gCurrentContext.isNil:
    gCurrentContext = result

proc setCurrentContext*(c: GraphicsContext): GraphicsContext {.discardable.} =
  result = gCurrentContext
  gCurrentContext = c

template currentContext*(): GraphicsContext = gCurrentContext

template transform*(c: GraphicsContext): var Transform3D = c.pTransform

template withTransform*(c: GraphicsContext, t: Transform3D, body: typed) =
  let oldTransform = c.pTransform
  c.pTransform = t
  body
  c.pTransform = oldTransform

template withTransform*(c: GraphicsContext, t: ptr Transform3D, body: typed) =
  let oldTransform = c.pTransform
  c.pTransform = t[]
  body
  c.pTransform = oldTransform

proc configureSurface*(c: GraphicsContext, device: Device, surface: Surface, format: TextureFormat, width, height: int) =
  c.device = device
  currentWgpuDevice = device
  c.surface = surface
  c.surfaceFormat = format
  c.surfaceWidth = max(1, width)
  c.surfaceHeight = max(1, height)
  when not defined(wasm):
    if not device.isNil and not surface.isNil:
      var cfg: SurfaceConfiguration
      cfg.device = device
      cfg.format = format
      cfg.usage = {tuRenderAttachment}
      cfg.width = c.surfaceWidth.uint32
      cfg.height = c.surfaceHeight.uint32
      cfg.presentMode = pmFifo
      cfg.alphaMode = camAuto
      surface.configure(cfg)
      c.configured = true

proc resizeSurface*(c: GraphicsContext, width, height: int) =
  if not c.device.isNil and not c.surface.isNil:
    c.configureSurface(c.device, c.surface, c.surfaceFormat, width, height)

proc createColorPipeline(c: GraphicsContext, topology: PrimitiveTopology): RenderPipeline =
  let shader = c.device.createShaderModule(colorShader)

  var attrs: array[2, VertexAttribute]
  attrs[0].shaderLocation = 0
  attrs[0].format = vfFloat32x2
  attrs[0].offset = 0
  attrs[1].shaderLocation = 1
  attrs[1].format = vfFloat32x4
  attrs[1].offset = (sizeof(float32) * 2).uint64

  var layout: VertexBufferLayout
  layout.arrayStride = sizeof(ColorVertex).uint64
  layout.stepMode = vsmVertex
  layout.attributeCount = attrs.len.uint32
  layout.attributes = cast[ptr UncheckedArray[VertexAttribute]](addr attrs)

  var fragment: FragmentState
  fragment.module = shader
  fragment.entryPoint = "fs_main"

  var blend: BlendState
  blend.color.srcFactor = bfSrcAlpha
  blend.color.dstFactor = bfOneMinusSrcAlpha
  blend.color.operation = boAdd
  blend.alpha.srcFactor = bfOne
  blend.alpha.dstFactor = bfOneMinusSrcAlpha
  blend.alpha.operation = boAdd

  var target: ColorTargetState
  target.format = c.surfaceFormat
  target.blend = addr blend
  target.writeMask = cwmAll

  fragment.targetCount = 1
  fragment.targets = cast[ptr UncheckedArray[ColorTargetState]](addr target)

  var desc: RenderPipelineDescriptor
  desc.layout = c.device.createPipelineLayout()
  desc.vertex.module = shader
  desc.vertex.entryPoint = "vs_main"
  desc.vertex.bufferCount = 1
  desc.vertex.buffers = cast[ptr UncheckedArray[VertexBufferLayout]](addr layout)
  desc.fragment = addr fragment
  desc.primitive.topology = topology
  desc.primitive.stripIndexFormat = ifUndefined
  desc.primitive.frontFace = ffCCW
  desc.primitive.cullMode = cmNone
  desc.multisample.count = 1
  desc.multisample.mask = uint32.high
  c.device.createRenderPipeline(desc)

proc createTextureBindGroupLayout(c: GraphicsContext): BindGroupLayout =
  var entries: array[2, BindGroupLayoutEntry]
  entries[0].binding = 0
  entries[0].visibility = {ssFragment}
  entries[0].sampler.typ = sbtFiltering
  entries[1].binding = 1
  entries[1].visibility = {ssFragment}
  entries[1].texture.sampleType = tstFloat
  entries[1].texture.viewDimension = tvd2D
  var desc: BindGroupLayoutDescriptor
  desc.entryCount = entries.len.csize_t
  desc.entries = cast[ptr UncheckedArray[BindGroupLayoutEntry]](addr entries)
  c.device.createBindGroupLayout(desc)

proc textureLayout(c: GraphicsContext): BindGroupLayout =
  if c.textureBindGroupLayout.isNil:
    c.textureBindGroupLayout = c.createTextureBindGroupLayout()
  c.textureBindGroupLayout

proc textureSampler(c: GraphicsContext): Sampler =
  if c.sampler.isNil:
    var desc: SamplerDescriptor
    desc.addressModeU = amClampToEdge
    desc.addressModeV = amClampToEdge
    desc.addressModeW = amClampToEdge
    desc.magFilter = fmLinear
    desc.minFilter = fmLinear
    desc.mipmapFilter = mfmNearest
    desc.maxAnisotropy = 1
    c.sampler = c.device.createSampler(desc)
  c.sampler

proc createTexturedPipeline(c: GraphicsContext, shaderCode: string = texturedShader): RenderPipeline =
  let shader = c.device.createShaderModule(shaderCode)

  var attrs: array[3, VertexAttribute]
  attrs[0].shaderLocation = 0
  attrs[0].format = vfFloat32x2
  attrs[0].offset = 0
  attrs[1].shaderLocation = 1
  attrs[1].format = vfFloat32x2
  attrs[1].offset = (sizeof(float32) * 2).uint64
  attrs[2].shaderLocation = 2
  attrs[2].format = vfFloat32x4
  attrs[2].offset = (sizeof(float32) * 4).uint64

  var layout: VertexBufferLayout
  layout.arrayStride = sizeof(TexturedVertex).uint64
  layout.stepMode = vsmVertex
  layout.attributeCount = attrs.len.uint32
  layout.attributes = cast[ptr UncheckedArray[VertexAttribute]](addr attrs)

  var fragment: FragmentState
  fragment.module = shader
  fragment.entryPoint = "fs_main"

  var blend: BlendState
  blend.color.srcFactor = bfSrcAlpha
  blend.color.dstFactor = bfOneMinusSrcAlpha
  blend.color.operation = boAdd
  blend.alpha.srcFactor = bfOne
  blend.alpha.dstFactor = bfOneMinusSrcAlpha
  blend.alpha.operation = boAdd

  var target: ColorTargetState
  target.format = c.surfaceFormat
  target.blend = addr blend
  target.writeMask = cwmAll
  fragment.targetCount = 1
  fragment.targets = cast[ptr UncheckedArray[ColorTargetState]](addr target)

  var layouts: array[1, BindGroupLayout]
  layouts[0] = c.textureLayout()
  var pld: PipelineLayoutDescriptor
  pld.bindGroupLayoutCount = 1
  pld.bindGroupLayouts = addr layouts[0]

  var desc: RenderPipelineDescriptor
  desc.layout = c.device.createPipelineLayout(pld)
  desc.vertex.module = shader
  desc.vertex.entryPoint = "vs_main"
  desc.vertex.bufferCount = 1
  desc.vertex.buffers = cast[ptr UncheckedArray[VertexBufferLayout]](addr layout)
  desc.fragment = addr fragment
  desc.primitive.topology = ptTriangleList
  desc.primitive.stripIndexFormat = ifUndefined
  desc.primitive.frontFace = ffCCW
  desc.primitive.cullMode = cmNone
  desc.multisample.count = 1
  desc.multisample.mask = uint32.high
  c.device.createRenderPipeline(desc)

proc texturedPipelineFor(c: GraphicsContext): RenderPipeline =
  if c.texturedPipeline.isNil:
    c.texturedPipeline = c.createTexturedPipeline(texturedShader)
  c.texturedPipeline

proc sdfTexturedPipelineFor(c: GraphicsContext): RenderPipeline =
  if c.sdfTexturedPipeline.isNil:
    c.sdfTexturedPipeline = c.createTexturedPipeline(sdfTexturedShader)
  c.sdfTexturedPipeline

proc pipelineFor(c: GraphicsContext, topology: PrimitiveTopology): RenderPipeline =
  case topology
  of ptTriangleList:
    if c.triPipeline.isNil: c.triPipeline = c.createColorPipeline(topology)
    c.triPipeline
  of ptLineList:
    if c.linePipeline.isNil: c.linePipeline = c.createColorPipeline(topology)
    c.linePipeline
  of ptTriangleStrip:
    if c.stripPipeline.isNil: c.stripPipeline = c.createColorPipeline(topology)
    c.stripPipeline
  else:
    if c.triPipeline.isNil: c.triPipeline = c.createColorPipeline(ptTriangleList)
    c.triPipeline

proc beginFrame*(c: GraphicsContext, clearColor: Color): bool {.discardable.} =
  when defined(wasm):
    return false
  else:
    if c.isNil or c.frameActive or c.device.isNil or c.surface.isNil or not c.configured:
      return c != nil and c.frameActive
    var st: SurfaceTexture
    c.surface.getCurrentTexture(st)
    if st.status notin {gctsSuccessOptimal, gctsSuccessSuboptimal} or st.texture.isNil:
      return false
    c.currentTexture = st.texture
    c.currentView = c.currentTexture.createView()
    c.encoder = c.device.createCommandEncoder()

    var attachment: RenderPassColorAttachment
    attachment.view = c.currentView
    attachment.depthSlice = DEPTH_SLICE_UNDEFINED
    attachment.loadOp = loClear
    attachment.storeOp = soStore
    attachment.clearValue = wgpu.Color(r: clearColor.r, g: clearColor.g, b: clearColor.b, a: clearColor.a)

    var passDesc: RenderPassDescriptor
    passDesc.colorAttachmentCount = 1
    passDesc.colorAttachments = cast[ptr UncheckedArray[RenderPassColorAttachment]](addr attachment)
    c.renderPass = c.encoder.beginRenderPass(passDesc)
    c.frameActive = true
    result = true

proc endFrame*(c: GraphicsContext) =
  when not defined(wasm):
    if c.isNil or not c.frameActive: return
    c.renderPass.finish()
    c.device.getQueue().submit(c.encoder.finish())
    discard c.surface.present()
    c.renderPass = RenderPassEncoder()
    c.encoder = CommandEncoder()
    c.currentView = TextureView()
    c.currentTexture = Texture()
    c.frameActive = false

proc clearFrame*(c: GraphicsContext, color: Color) =
  if c.isNil: return
  if c.frameActive: return
  if c.beginFrame(color): c.endFrame()

proc toVertex(c: GraphicsContext, p: Point, color: Color): ColorVertex =
  let v = c.transform * newVector4(p.x, p.y, 0, 1)
  let iw = if abs(v[3]) > 0.000001: 1 / v[3] else: 1
  ColorVertex(x: v[0] * iw, y: v[1] * iw,
              r: color.r, g: color.g, b: color.b, a: color.a * c.alpha)

proc makeBuffer(c: GraphicsContext, data: openarray[ColorVertex]): Buffer =
  var desc: BufferDescriptor
  desc.size = (sizeof(ColorVertex) * data.len).uint64
  desc.usage = {buCopyDst, buVertex}
  result = c.device.createBuffer(desc)
  if data.len > 0:
    c.device.getQueue().writeBuffer(result, 0, unsafeAddr data[0], sizeof(ColorVertex) * data.len)

proc makeTextureBuffer(c: GraphicsContext, data: openarray[TexturedVertex]): Buffer =
  var desc: BufferDescriptor
  desc.size = (sizeof(TexturedVertex) * data.len).uint64
  desc.usage = {buCopyDst, buVertex}
  result = c.device.createBuffer(desc)
  if data.len > 0:
    c.device.getQueue().writeBuffer(result, 0, unsafeAddr data[0], sizeof(TexturedVertex) * data.len)

proc ensureGpuTexture(c: GraphicsContext, i: SelfContainedImage): Texture =
  if i.texture.isNil and i.pixels.len != 0 and i.pixelWidth > 0 and i.pixelHeight > 0:
    var desc: TextureDescriptor
    desc.usage = {tuCopyDst, tuTextureBinding}
    desc.dimension = td2D
    desc.size = Extent3D(width: i.pixelWidth.uint32, height: i.pixelHeight.uint32, depthOrArrayLayers: 1)
    desc.format = tfRGBA8Unorm
    desc.mipLevelCount = 1
    desc.sampleCount = 1
    i.texture = c.device.createTexture(desc)

    var dst: TexelCopyTextureInfo
    dst.texture = i.texture
    dst.aspect = taAll
    dst.mipLevel = 0
    var layout: TexelCopyBufferLayout
    layout.offset = 0
    layout.bytesPerRow = (i.pixelWidth * 4).uint32
    layout.rowsPerImage = i.pixelHeight.uint32
    c.device.getQueue().writeTexture(dst, unsafeAddr i.pixels[0], i.pixels.len, layout, desc.size)
  result = i.texture

proc bindGroupForTexture(c: GraphicsContext, texture: Texture): BindGroup =
  let view = texture.createView()
  var entries: array[2, BindGroupEntry]
  entries[0].binding = 0
  entries[0].sampler = c.textureSampler()
  entries[1].binding = 1
  entries[1].textureView = view
  var desc: BindGroupDescriptor
  desc.layout = c.textureLayout()
  desc.entryCount = entries.len.csize_t
  desc.entries = cast[ptr UncheckedArray[BindGroupEntry]](addr entries)
  c.device.createBindGroup(desc)

proc toTexturedVertex(c: GraphicsContext, p: Point, uv: Point, color: Color): TexturedVertex =
  let v = c.transform * newVector4(p.x, p.y, 0, 1)
  let iw = if abs(v[3]) > 0.000001: 1 / v[3] else: 1
  TexturedVertex(x: v[0] * iw, y: v[1] * iw, u: uv.x, v: uv.y,
                 r: color.r, g: color.g, b: color.b, a: color.a * c.alpha)

proc drawTexturedVertices(c: GraphicsContext, texture: Texture, data: openarray[TexturedVertex], sdf: bool = false) =
  when not defined(wasm):
    if c.isNil or not c.frameActive or data.len == 0 or texture.isNil: return
    let vb = c.makeTextureBuffer(data)
    c.renderPass.setPipeline(if sdf: c.sdfTexturedPipelineFor() else: c.texturedPipelineFor())
    c.renderPass.setBindGroup(0, c.bindGroupForTexture(texture))
    c.renderPass.setVertexBuffer(0, vb)
    c.renderPass.draw(data.len.uint32, 1, 0, 0)

proc drawVertices(c: GraphicsContext, data: openarray[ColorVertex], topology: PrimitiveTopology) =
  when not defined(wasm):
    if c.isNil or not c.frameActive or data.len == 0: return
    let vb = c.makeBuffer(data)
    c.renderPass.setPipeline(c.pipelineFor(topology))
    c.renderPass.setVertexBuffer(0, vb)
    c.renderPass.draw(data.len.uint32, 1, 0, 0)

import ./composition

const roundedRectComposition = newComposition """
fn compose() {
  drawInitialShape(sdRoundedRectAt(uni.bounds, uni.uRadius.x), uni.uStrokeColor);
  drawShape(sdRoundedRectAt(insetRect(uni.bounds, uni.uStrokeWidth.x), uni.uRadius.x - uni.uStrokeWidth.x), uni.uFillColor);
}
"""

proc drawRoundedRect*(c: GraphicsContext, r: Rect, radius: Coord) =
  roundedRectComposition.draw r:
    setUniform("uFillColor", c.fillColor)
    setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
    setUniform("uStrokeWidth", c.strokeWidth)
    setUniform("uRadius", radius)

const rectComposition = newComposition """
fn compose() {
  drawInitialShape(sdRectAt(uni.bounds), uni.uStrokeColor);
  drawShape(sdRectAt(insetRect(uni.bounds, uni.uStrokeWidth.x)), uni.uFillColor);
}
"""

proc drawRect*(c: GraphicsContext, r: Rect) =
  rectComposition.draw r:
    setUniform("uFillColor", c.fillColor)
    setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
    setUniform("uStrokeWidth", c.strokeWidth)

const ellipseComposition = newComposition """
fn compose() {
  drawInitialShape(sdEllipseInRectAt(uni.bounds), uni.uStrokeColor);
  drawShape(sdEllipseInRectAt(insetRect(uni.bounds, uni.uStrokeWidth.x)), uni.uFillColor);
}
"""

proc drawEllipseInRect*(c: GraphicsContext, r: Rect) =
  ellipseComposition.draw r:
    setUniform("uFillColor", c.fillColor)
    setUniform("uStrokeColor", if c.strokeWidth == 0: c.fillColor else: c.strokeColor)
    setUniform("uStrokeWidth", c.strokeWidth)

proc bindVertexData*(c: GraphicsContext, length: int) = discard

proc drawTextureQuad*(c: GraphicsContext, texture: TextureRef, quad: openarray[Coord], color: Color, sdf: bool = false) =
  if texture.isNil or quad.len < 16: return
  let p0 = newPoint(quad[0], quad[1])
  let uv0 = newPoint(quad[2], quad[3])
  let p1 = newPoint(quad[4], quad[5])
  let uv1 = newPoint(quad[6], quad[7])
  let p2 = newPoint(quad[8], quad[9])
  let uv2 = newPoint(quad[10], quad[11])
  let p3 = newPoint(quad[12], quad[13])
  let uv3 = newPoint(quad[14], quad[15])
  let verts = [c.toTexturedVertex(p0, uv0, color), c.toTexturedVertex(p1, uv1, color), c.toTexturedVertex(p2, uv2, color),
               c.toTexturedVertex(p2, uv2, color), c.toTexturedVertex(p3, uv3, color), c.toTexturedVertex(p0, uv0, color)]
  c.drawTexturedVertices(texture, verts, sdf)

proc drawImage*(c: GraphicsContext, i: Image, toRect: Rect, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
  if i.isNil or not i.isLoaded: return
  if i of SelfContainedImage:
    let sci = SelfContainedImage(i)
    let tex = c.ensureGpuTexture(sci)
    if not tex.isNil:
      var tc = sci.texCoords
      if fromRect != zeroRect and sci.size.width > 0 and sci.size.height > 0:
        tc[0] = fromRect.x / sci.size.width
        tc[1] = fromRect.y / sci.size.height
        tc[2] = fromRect.maxX / sci.size.width
        tc[3] = fromRect.maxY / sci.size.height
      let col = newColor(1, 1, 1, alpha)
      let p0 = newPoint(toRect.x, toRect.y)
      let p1 = newPoint(toRect.maxX, toRect.y)
      let p2 = newPoint(toRect.maxX, toRect.maxY)
      let p3 = newPoint(toRect.x, toRect.maxY)
      let uv0 = newPoint(tc[0], tc[1])
      let uv1 = newPoint(tc[2], tc[1])
      let uv2 = newPoint(tc[2], tc[3])
      let uv3 = newPoint(tc[0], tc[3])
      let verts = [c.toTexturedVertex(p0, uv0, col), c.toTexturedVertex(p1, uv1, col), c.toTexturedVertex(p2, uv2, col),
                   c.toTexturedVertex(p2, uv2, col), c.toTexturedVertex(p3, uv3, col), c.toTexturedVertex(p0, uv0, col)]
      c.drawTexturedVertices(tex, verts)
      return
  let oldFill = c.fillColor
  let oldStroke = c.strokeColor
  let oldWidth = c.strokeWidth
  c.fillColor = newColor(0.85, 0.85, 0.85, alpha)
  c.strokeColor = newColor(0.55, 0.55, 0.55, alpha)
  c.strokeWidth = 1
  c.drawRect(toRect)
  c.fillColor = oldFill
  c.strokeColor = oldStroke
  c.strokeWidth = oldWidth

proc drawNinePartImage*(c: GraphicsContext, i: Image, toRect: Rect, ml, mt, mr, mb: Coord, fromRect: Rect = zeroRect, alpha: ColorComponent = 1.0) =
  c.drawImage(i, toRect, fromRect, alpha)

const lineComposition = newComposition """
fn drawLineSdf(p1: vec2f, p2: vec2f) -> f32 {
  let A = uni.A.xy;
  let B = uni.B.xy;
  let va = B - A;
  let vb = vPos - A;
  let vc = vPos - B;
  let tri = vec3f(distance(A, B), distance(vPos, A), distance(vPos, B));
  let p = (tri.x + tri.y + tri.z) / 2.0;
  let h = 2.0 * sqrt(p * (p - tri.x) * (p - tri.y) * (p - tri.z)) / tri.x;
  let angles = acos(vec2f(dot(normalize(-va), normalize(vc)), dot(normalize(va), normalize(vb))));
  let anglem = vec2f(1.0) - step(vec2f(PI / 2.0), angles);
  let pixelValue = 1.0 - smoothstep(0.0, uni.uStrokeWidth.x, h);
  return anglem.x * anglem.y * pixelValue;
}

fn compose() {
  outColor = vec4f(uni.uStrokeColor.xyz, uni.uStrokeColor.a * drawLineSdf(uni.A.xy, uni.B.xy));
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

proc bezierPoint(p0, p1, p2, p3: Point, t: Coord): Point =
  let it = 1 - t
  result.x = it * it * it * p0.x + 3 * it * it * t * p1.x + 3 * it * t * t * p2.x + t * t * t * p3.x
  result.y = it * it * it * p0.y + 3 * it * it * t * p1.y + 3 * it * t * t * p2.y + t * t * t * p3.y

proc drawBezier*(c: GraphicsContext, p0, p1, p2, p3: Point) =
  var prev = p0
  for i in 1 .. 64:
    let p = bezierPoint(p0, p1, p2, p3, i.Coord / 64)
    c.drawLine(prev, p)
    prev = p

const arcComposition = newComposition """
fn compose() {
  let center = uni.bounds.xy + uni.bounds.zw / vec2f(2.0);
  let radius = min(uni.bounds.z, uni.bounds.w) / 2.0 - 1.0;
  let centerDist = distance(vPos, center);
  let delta = vPos - center;
  var angle = atan2(delta.y, delta.x);
  angle += step(angle, 0.0) * PI * 2.0;
  let angleDist1 = step(step(angle, uni.uStartAngle.x) + step(uni.uEndAngle.x, angle), 0.0);
  angle += PI * 2.0;
  let angleDist2 = step(step(angle, uni.uStartAngle.x) + step(uni.uEndAngle.x, angle), 0.0);
  drawInitialShape((centerDist - radius) / radius, uni.uStrokeColor);
  drawShape((centerDist - radius + uni.uStrokeWidth.x) / radius, uni.uFillColor);
  outColor.a *= max(angleDist1, angleDist2);
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
fn compose() {
  let center = vec2f(uni.bounds.x + uni.bounds.z / 2.0, uni.bounds.y + uni.bounds.w / 2.0 - 1.0);
  let triangle = sdRegularPolygonAt(center, 4.0, 3, uni.uAngle.x);
  drawShape(triangle, uni.uColor);
}
"""

proc drawTriangle*(c: GraphicsContext, rect: Rect, angleRad: Coord) =
  var color = c.fillColor
  color.a *= c.alpha
  triangleComposition.draw rect:
    setUniform("uAngle", angleRad)
    setUniform("uColor", color)

proc applyClippingRect*(c: GraphicsContext, r: Rect, on: bool) = discard

template withClippingRect*(c: GraphicsContext, r: Rect, body: typed) =
  body

import private/text_drawing
export text_drawing
