
import types

type ColorStop* = tuple[color: Color, location: float32]

type Gradient* = object
    startColor*: Color
    endColor*: Color
    colorStops*: seq[ColorStop]

proc newGradient*(startColor, endColor: Color): Gradient =
    result.startColor = startColor
    result.endColor = endColor

proc addColorStop*(gradient: var Gradient, color: Color, location: float32) =
    if gradient.colorStops.isNil:
        gradient.colorStops = newSeq[ColorStop]()
    gradient.colorStops.add((color, location))

# This is a workaround for Nim can't convert float literal to float32 implicitly
#template addColorStop*(gradient: var Gradient, color: Color, location: float):stmt =
#    gradient.addColorStop(color, location.float)

iterator colors*(gradient: Gradient): ColorStop =
    yield (gradient.startColor, float32(0.0))
    for cs in gradient.colorStops.items:
        yield cs
    yield (gradient.endColor, float32(1.0))
