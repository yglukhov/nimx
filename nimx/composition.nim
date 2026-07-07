import types
import context

type
  Composition* = object
  CompiledComposition* = ref object
    iTexIndex*: int

proc newComposition*(vsDef, fsDef: static[string], requiresPrequel: bool = true, precision: string = "highp"): Composition =
  Composition()

template newComposition*(definition: static[string], requiresPrequel: bool = true): Composition =
  newComposition("", definition, requiresPrequel)

template newCompositionWithNimsl*(mainProc: typed): Composition =
  Composition()

template setUniform*(name: string, value: untyped) = discard

template draw*(comp: Composition, r: Rect, body: untyped) =
  block:
    let ctx = currentContext()
    let oldFill = ctx.fillColor
    let oldStroke = ctx.strokeColor
    let oldWidth = ctx.strokeWidth
    body
    if ctx.strokeWidth == oldWidth and ctx.fillColor == oldFill and ctx.strokeColor == oldStroke:
      ctx.fillColor = newGrayColor(0.78)
      ctx.strokeColor = newGrayColor(0.55)
      ctx.strokeWidth = 1
    ctx.drawRect(r)
    ctx.fillColor = oldFill
    ctx.strokeColor = oldStroke
    ctx.strokeWidth = oldWidth

proc draw*(comp: Composition, r: Rect) =
  let ctx = currentContext()
  let oldFill = ctx.fillColor
  let oldStroke = ctx.strokeColor
  let oldWidth = ctx.strokeWidth
  ctx.fillColor = newGrayColor(0.78)
  ctx.strokeColor = newGrayColor(0.55)
  ctx.strokeWidth = 1
  ctx.drawRect(r)
  ctx.fillColor = oldFill
  ctx.strokeColor = oldStroke
  ctx.strokeWidth = oldWidth

proc GetOverdrawValue*(): int = 0
proc ResetOverdrawValue*() = discard
proc GetDIPValue*(): int = 0
proc ResetDIPValue*() = discard

template hasPostEffect*(): bool = false
proc setupPosteffectUniforms*(cc: CompiledComposition) = discard

template compositionDrawingDefinitions*(cc: CompiledComposition, ctx: untyped, gpu: untyped) =
  template setUniform(name: string, value: untyped) = discard
  template uniformLocation(name: string): int = 0

template getCompiledComposition*(gpu: untyped, comp: Composition, options: int = 0): CompiledComposition =
  CompiledComposition(iTexIndex: 0)
