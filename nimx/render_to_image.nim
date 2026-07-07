import image, types, context, gpu_types
import wgpu except Color

type
  RTIContext* = tuple
    skipClear: bool

  GpuFrameState* {.deprecated.} = RTIContext

  ImageRenderTarget* = ref ImageRenderTargetObj
  ImageRenderTargetObj = object
    texWidth*, texHeight*: int16
    needsDepthStencil*: bool
    image: SelfContainedImage
    savedRenderPass: RenderPassEncoder
    savedFrameActive: bool
    offscreenEncoder: CommandEncoder
    offscreenPass: RenderPassEncoder

proc dispose*(r: ImageRenderTarget) =
  r.image = nil
  r.offscreenPass = RenderPassEncoder()
  r.offscreenEncoder = CommandEncoder()
  r.savedRenderPass = RenderPassEncoder()

proc newImageRenderTarget*(needsDepthStencil: bool = true): ImageRenderTarget {.inline.} =
  result.new()
  result.needsDepthStencil = needsDepthStencil

proc ensureRenderTargetTexture(i: SelfContainedImage) =
  # Create a WebGPU texture that can be both rendered into and sampled from.
  if not i.texture.isNil: return
  let c = currentContext()
  if c.isNil or c.device.isNil: return
  let w = max(1, i.texWidth.int)
  let h = max(1, i.texHeight.int)
  var desc: TextureDescriptor
  desc.usage = {tuRenderAttachment, tuTextureBinding, tuCopySrc}
  desc.dimension = td2D
  desc.size = Extent3D(width: w.uint32, height: h.uint32, depthOrArrayLayers: 1)
  desc.format = c.surfaceFormat
  desc.mipLevelCount = 1
  desc.sampleCount = 1
  i.texture = c.device.createTexture(desc)

proc setImage*(rt: ImageRenderTarget, i: SelfContainedImage) =
  assert(i.texWidth != 0 and i.texHeight != 0)
  rt.image = i
  rt.texWidth = i.texWidth
  rt.texHeight = i.texHeight
  i.ensureRenderTargetTexture()

proc beginDraw*(t: ImageRenderTarget, state: var RTIContext) =
  let c = currentContext()
  if c.isNil or c.device.isNil or t.image.isNil or t.image.texture.isNil:
    return
  t.savedRenderPass = c.renderPass
  t.savedFrameActive = c.frameActive

  let view = t.image.texture.createView()
  t.offscreenEncoder = c.device.createCommandEncoder()

  var attachment: RenderPassColorAttachment
  attachment.view = view
  attachment.depthSlice = DEPTH_SLICE_UNDEFINED
  attachment.loadOp = loClear
  attachment.storeOp = soStore
  attachment.clearValue = wgpu.Color(r: 0.0, g: 0.0, b: 0.0, a: 0.0)

  var passDesc: RenderPassDescriptor
  passDesc.colorAttachmentCount = 1
  passDesc.colorAttachments = cast[ptr UncheckedArray[RenderPassColorAttachment]](addr attachment)
  t.offscreenPass = t.offscreenEncoder.beginRenderPass(passDesc)

  c.renderPass = t.offscreenPass
  c.frameActive = true

proc beginDrawNoClear*(t: ImageRenderTarget, state: var RTIContext) =
  state.skipClear = true
  t.beginDraw(state)

proc endDraw*(t: ImageRenderTarget, state: var RTIContext) =
  let c = currentContext()
  if c.isNil or t.offscreenPass.isNil:
    return
  t.offscreenPass.finish()
  c.device.getQueue().submit(t.offscreenEncoder.finish())
  t.offscreenPass = RenderPassEncoder()
  t.offscreenEncoder = CommandEncoder()
  # Restore the main frame's render pass so subsequent draws go to the window.
  c.renderPass = t.savedRenderPass
  c.frameActive = t.savedFrameActive

template draw*(rt: ImageRenderTarget, sci: SelfContainedImage, drawBody: untyped) =
  var gfs: RTIContext
  rt.setImage(sci)
  rt.beginDraw(gfs)
  currentContext().withTransform ortho(0, sci.size.width, sci.size.height, 0, -1, 1):
    drawBody
  rt.endDraw(gfs)

template draw*(sci: SelfContainedImage, drawBody: untyped) =
  let rt = newImageRenderTarget()
  rt.draw(sci):
    drawBody