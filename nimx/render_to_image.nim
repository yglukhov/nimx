import image, types, context

type
  RTIContext* = tuple
    skipClear: bool

  GpuFrameState* {.deprecated.} = RTIContext

  ImageRenderTarget* = ref ImageRenderTargetObj
  ImageRenderTargetObj = object
    texWidth*, texHeight*: int16
    needsDepthStencil*: bool

proc dispose*(r: ImageRenderTarget) = discard

proc newImageRenderTarget*(needsDepthStencil: bool = true): ImageRenderTarget {.inline.} =
  result.new()
  result.needsDepthStencil = needsDepthStencil

proc setImage*(rt: ImageRenderTarget, i: SelfContainedImage) =
  rt.texWidth = i.texWidth
  rt.texHeight = i.texHeight

proc beginDraw*(t: ImageRenderTarget, state: var RTIContext) = discard
proc beginDrawNoClear*(t: ImageRenderTarget, state: var RTIContext) = state.skipClear = true
proc endDraw*(t: ImageRenderTarget, state: var RTIContext) = discard

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
