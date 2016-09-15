import unicode, algorithm, strutils, sequtils
import nimx.font, nimx.types, nimx.unistring, nimx.utils.lower_bound


type
    FormattedText* = ref object
        mText: string
        mAttributes: seq[Attributes]
        lines: seq[LineInfo]
        mTotalHeight: float32
        horizontalAlignment*: HorizontalTextAlignment
        verticalAlignment*: VerticalAlignment
        mBoundingSize: Size
        cacheValid: bool
        canBreakOnAnyChar: bool
        overrideColor*: Color
        shadowAttrs: seq[int]
        strokeAttrs: seq[int]
        shadowMultiplier*: Size
        mLineSpacing: float32

    LineInfo* = object
        startByte: int
        startRune: int
        width: float32
        height: float32
        top: float32
        baseline: float32 # distance from top of the line to baseline
        firstAttr: int

    Attributes = object
        startByte: int # Index of char where attributes start.
        startRune: int # Index of rune where attributes start.
        font: Font
        textColor: Color

        # Richer attributes. TODO: Move to separate ref object
        shadowColor: Color
        strokeColor1: Color
        strokeColor2: Color
        textColor2: Color
        backgroundColor: Color
        shadowOffset: Size
        shadowRadius: float32
        strokeSize: float32
        tracking: float32
        isTextGradient: bool
        isStrokeGradient: bool

    VerticalAlignment* = enum
        vaTop
        vaCenter
        vaBottom

    HorizontalTextAlignment* = enum
        haLeft
        haRight
        haCenter
        haJustify

proc defaultAttributes(): Attributes =
    result.font = systemFont()
    result.textColor = blackColor()

proc `text=`*(t: FormattedText, s: string) =
    if s.isNil:
        t.mText = ""
    else:
        t.mText = s
    t.cacheValid = false

template text*(t: FormattedText): string = t.mText

proc `lineSpacing=`*(t: FormattedText, s: float32) =
    t.mLineSpacing = s
    t.cacheValid = false

template lineSpacing*(t: FormattedText): float32 = t.mLineSpacing

proc newFormattedText*(s: string = ""): FormattedText =
    result.new()
    result.mText = s
    result.mAttributes = @[defaultAttributes()]
    result.lines = @[]
    result.shadowAttrs = @[]
    result.strokeAttrs = @[]
    result.shadowMultiplier = newSize(1, 1)
    result.mLineSpacing = 2

proc updateCache(t: FormattedText) =
    t.cacheValid = true
    t.lines.setLen(0)
    t.shadowAttrs.setLen(0)
    t.strokeAttrs.setLen(0)
    t.mTotalHeight = 0

    var curLineInfo: LineInfo
    curLineInfo.height = t.mAttributes[0].font.height

    # In this context "word" means minimal sequence of runes that can not have
    # line break
    var curWordWidth = 0'f32
    var curWordHeight = 0'f32
    var curWordBaseline = 0'f32

    var curWordStartByte = 0
    var curWordStartRune = 0
    var curWordFirstAttr = 0

    var i = 0
    var curAttrIndex = 0
    var nextAttrStartIndex = -1
    if t.mAttributes.len > 1:
        nextAttrStartIndex = t.mAttributes[1].startByte

    var boundingWidth = t.mBoundingSize.width
    if boundingWidth == 0: boundingWidth = Inf

    var c: Rune
    let textLen = t.mText.len
    var curRune = 0

    if t.mAttributes[0].strokeSize > 0: t.strokeAttrs.add(0)
    if t.mAttributes[0].shadowColor.a != 0: t.shadowAttrs.add(0)

    template mustBreakLine(): bool =
        c == Rune('\l')

    template canBreakLine(): bool =
        t.canBreakOnAnyChar or c == Rune(' ') or c == Rune('-') or i == textLen or mustBreakLine()

    while i < textLen:
        let font = t.mAttributes[curAttrIndex].font
        let charStart = i

        fastRuneAt(t.mText, i, c, true)

        let runeWidth = font.getAdvanceForRune(c)

        curWordWidth += runeWidth
        curWordHeight = max(curWordHeight, font.height)
        curWordBaseline = max(curWordBaseline, font.ascent)

        if canBreakLine():
            # commit current word
            if (curLineInfo.width + curWordWidth < boundingWidth or curLineInfo.width == 0):
                # Word fits in the line
                curLineInfo.width += curWordWidth
                curLineInfo.height = max(curLineInfo.height, curWordHeight)
                curLineInfo.baseline = max(curLineInfo.baseline, curWordBaseline)
                if mustBreakLine():
                    let tmp = curLineInfo # JS bug workaround. Copy to temp object.
                    t.lines.add(tmp)
                    t.mTotalHeight += curLineInfo.height + t.mLineSpacing
                    curLineInfo.top = t.mTotalHeight
                    curLineInfo.startByte = i
                    curLineInfo.startRune = curRune + 1
                    curLineInfo.width = 0
                    curLineInfo.height = 0
                    curLineInfo.baseline = 0
                    curLineInfo.firstAttr = curAttrIndex
            else:
                # Complete current line
                let tmp = curLineInfo # JS bug workaround. Copy to temp object.
                t.lines.add(tmp)
                t.mTotalHeight += curLineInfo.height + t.mLineSpacing
                curLineInfo.top = t.mTotalHeight
                curLineInfo.startByte = curWordStartByte
                curLineInfo.startRune = curWordStartRune
                curLineInfo.width = curWordWidth
                curLineInfo.height = curWordHeight
                curLineInfo.baseline = curWordBaseline
                curLineInfo.firstAttr = curWordFirstAttr

            curWordWidth = 0
            curWordHeight = 0
            curWordBaseline = 0
            curWordStartByte = i
            curWordStartRune = curRune + 1
            curWordFirstAttr = curAttrIndex

        # Switch to next attribute if its time
        if charStart + 1 == nextAttrStartIndex:
            inc curAttrIndex
            if t.mAttributes[curAttrIndex].strokeSize > 0: t.strokeAttrs.add(curAttrIndex)
            if t.mAttributes[curAttrIndex].shadowColor.a != 0: t.shadowAttrs.add(curAttrIndex)
            if t.mAttributes.high > curAttrIndex:
                nextAttrStartIndex = t.mAttributes[curAttrIndex + 1].startByte

        inc curRune

    if curLineInfo.width > 0 or t.lines.len == 0 or mustBreakLine():
        if curLineInfo.height == 0:
            curLineInfo.height = t.mAttributes[curAttrIndex].font.height
        let tmp = curLineInfo # JS bug workaround. Copy to temp object.
        t.lines.add(tmp)
        t.mTotalHeight += curLineInfo.height + t.mLineSpacing

    # echo "Cache updated for ", t.mText
    # echo "Attributes: ", t.mAttributes
    # echo "lines: ", t.lines
    # echo "shadow attrs: ", t.shadowAttrs

template updateCacheIfNeeded(t: FormattedText) =
    if not t.cacheValid: t.updateCache()

proc `boundingSize=`*(t: FormattedText, s: Size) =
    if s != t.mBoundingSize:
        t.mBoundingSize = s
        t.cacheValid = false

template boundingSize*(t: FormattedText): Size = t.mBoundingSize

proc lineOfRuneAtPos*(t: FormattedText, pos: int): int =
    t.updateCacheIfNeeded()
    result = lowerBoundIt(t.lines, t.lines.low, t.lines.high, cmp(it.startRune, pos) <= 0) - 1

proc lineTop*(t: FormattedText, ln: int): float32 =
    t.updateCacheIfNeeded()
    t.lines[ln].top

proc lineHeight*(t: FormattedText, ln: int): float32 =
    t.updateCacheIfNeeded()
    t.lines[ln].height

proc lineWidth*(t: FormattedText, ln: int): float32 =
    t.updateCacheIfNeeded()
    t.lines[ln].width

proc lineLeft*(t: FormattedText, ln: int): float32 =
    t.updateCacheIfNeeded()
    case t.horizontalAlignment
    of haCenter: (t.mBoundingSize.width - t.lines[ln].width) / 2
    of haRight: t.mBoundingSize.width - t.lines[ln].width
    else: 0

proc lineBaseline*(t: FormattedText, ln: int): float32 =
    # Do not use this!
    t.updateCacheIfNeeded()
    result = t.lines[ln].baseline

proc hasShadow*(t: FormattedText): bool =
    t.updateCacheIfNeeded()
    t.shadowAttrs.len > 0

proc totalHeight*(t: FormattedText): float32 =
    t.updateCacheIfNeeded()
    t.mTotalHeight

proc prepareAttributes(t: FormattedText, a: int): int =
    result = lowerBoundIt(t.mAttributes, 0, t.mAttributes.high, cmp(it.startRune, a) < 0)
    if result < t.mAttributes.len and t.mAttributes[result].startRune == a:
        return

    var iRune = t.mAttributes[result - 1].startRune
    var iChar = t.mAttributes[result - 1].startByte
    var r: Rune
    while iRune < a:
        fastRuneAt(t.mText, iChar, r, true)
        inc iRune
    var attr: Attributes
    t.mAttributes.insert(attr, result)
    t.mAttributes[result] = t.mAttributes[result - 1]
    t.mAttributes[result].startRune = a
    t.mAttributes[result].startByte = iChar

iterator attrsInRange(t: FormattedText, a, b: int): int =
    let aa = t.prepareAttributes(a)
    let ab = if b == -1:
            t.mAttributes.len
        else:
            t.prepareAttributes(b)
    for i in aa ..< ab: yield i

proc setFontInRange*(t: FormattedText, a, b: int, f: Font) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].font = f
    t.cacheValid = false

proc setTrackingInRange*(t: FormattedText, a, b: int, v: float32) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].tracking = v
    t.cacheValid = false

proc setTextColorInRange*(t: FormattedText, a, b: int, c: Color) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].textColor = c
        t.mAttributes[i].isTextGradient = false

proc setTextColorInRange*(t: FormattedText, a, b: int, color1, color2: Color) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].textColor = color1
        t.mAttributes[i].textColor2 = color2
        t.mAttributes[i].isTextGradient = true

proc setShadowInRange*(t: FormattedText, a, b: int, color: Color, offset: Size) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].shadowColor = color
        t.mAttributes[i].shadowOffset = offset
    t.cacheValid = false

proc setStrokeInRange*(t: FormattedText, a, b: int, color: Color, size: float32) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].strokeColor1 = color
        t.mAttributes[i].strokeSize = size
        t.mAttributes[i].isStrokeGradient = false
    t.cacheValid = false

proc setStrokeInRange*(t: FormattedText, a, b: int, color1, color2: Color, size: float32) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].strokeColor1 = color1
        t.mAttributes[i].strokeColor2 = color2
        t.mAttributes[i].strokeSize = size
        t.mAttributes[i].isStrokeGradient = true
    t.cacheValid = false

proc attrIndexForRuneAtPos(t: FormattedText, pos: int): int =
    if pos == 0: return 0 # Shortcut
    result = t.mAttributes.lowerBoundIt(0, t.mAttributes.high, cmp(it.startRune, pos) <= 0) - 1

proc uniInsert*(t: FormattedText, atIndex: int, s: string) =
    t.cacheValid = false
    t.mText.uniInsert(s, atIndex)
    var ai = t.attrIndexForRuneAtPos(atIndex)
    inc ai
    let rl = s.runeLen
    for i in ai .. t.mAttributes.high:
        t.mAttributes[i].startRune += rl
        t.mAttributes[i].startByte += s.len

proc getByteOffsetsForRunePositions(t: FormattedText, positions: openarray[int], res: var openarray[int]) =
    let a = t.attrIndexForRuneAtPos(positions[0])
    var p = t.mAttributes[a].startByte
    var r = t.mAttributes[a].startRune
    for i in 0 .. positions.high:
        p = t.mText.runeOffset(positions[i] - r, p)
        res[i] = p
        r = positions[i]

proc uniDelete*(t: FormattedText, start, stop: int) =
    t.cacheValid = false

    var sa = t.attrIndexForRuneAtPos(start)
    var ea = t.attrIndexForRuneAtPos(stop)

    var byteOffsets: array[2, int]
    t.getByteOffsetsForRunePositions([start, stop], byteOffsets)

    let startByte = byteOffsets[0]
    let stopByte = byteOffsets[1]

    let bl = stopByte - startByte + 1
    let rl = stop - start + 1

    t.mText.uniDelete(start, stop) # TODO: Call non-unicode delete here

    if sa == ea:
        for i in ea + 1 .. t.mAttributes.high:
            t.mAttributes[i].startRune -= rl
            t.mAttributes[i].startByte -= bl
    else:
        t.mAttributes[ea].startByte = startByte
        t.mAttributes[ea].startRune = start
        for i in ea + 1 .. t.mAttributes.high:
            t.mAttributes[i].startRune -= rl
            t.mAttributes[i].startByte -= bl
        if ea - sa > 1:
            t.mAttributes.delete(sa + 1, ea - 1)

    if sa < t.mAttributes.high and t.mAttributes[sa].startRune == t.mAttributes[sa + 1].startRune:
        t.mAttributes.delete(sa)

iterator attrsInLine(t: FormattedText, line: int): tuple[attrIndex, a, b: int] =
    let firstAttrInLine = t.lines[line].firstAttr
    var curAttrIndex = firstAttrInLine
    var breakPos = t.mText.len
    if line < t.lines.high: breakPos = t.lines[line + 1].startByte
    while curAttrIndex < t.mAttributes.len and t.mAttributes[curAttrIndex].startByte < breakPos:
        var attrStartIndex = t.mAttributes[curAttrIndex].startByte
        if curAttrIndex == firstAttrInLine:
            attrStartIndex = t.lines[line].startByte

        var attrEndIndex = breakPos
        var attributeBreaks = true
        if t.mAttributes.high > curAttrIndex:
            let nextAttrStart = t.mAttributes[curAttrIndex + 1].startByte
            if nextAttrStart < attrEndIndex:
                attrEndIndex = nextAttrStart
                attributeBreaks = true

        yield (curAttrIndex, attrStartIndex, attrEndIndex - 1)

        if attrEndIndex == breakPos:
            break

        if attributeBreaks:
            inc curAttrIndex

iterator runeWidthsInLine*(t: FormattedText, line: int): float32 =
    var first = true
    var charOff = 0
    var r: Rune
    var p = 0
    for curAttrIndex, attrStartIndex, attrEndIndex in t.attrsInLine(line):
        if first:
            charOff = t.mAttributes[curAttrIndex].startByte
            while charOff < attrStartIndex:
                inc charOff, runeLenAt(t.mText, charOff)
            first = false
        while charOff <= attrEndIndex:
            fastRuneAt(t.mText, charOff, r, true)
            let w = t.mAttributes[curAttrIndex].font.getAdvanceForRune(r)
            yield w
            inc p

proc cursorOffsetForPositionInLine*(t: FormattedText, line, position: int): Coord =
    t.updateCacheIfNeeded()
    if t.lines.len == 0: return

    var p = 0
    for width in t.runeWidthsInLine(line):
        if p == position: break
        result += width
        inc p

proc xOfRuneAtPos*(t: FormattedText, position: int): Coord =
    t.updateCacheIfNeeded()
    let ln = min(t.lineOfRuneAtPos(position), t.lines.high)
    result = t.cursorOffsetForPositionInLine(ln, position - t.lines[ln].startRune)

proc getClosestCursorPositionToPointInLine*(t: FormattedText, line: int, p: Point, position: var int, offset: var Coord) =
    t.updateCacheIfNeeded()
    if line > t.lines.high: return

    var totalWidth = 0'f32
    var pos = 0
    for width in t.runeWidthsInLine(line):
        if p.x < totalWidth + width:
            if (totalWidth + width - p.x) > (p.x - totalWidth):
                position = pos + t.lines[line].startRune
                offset = totalWidth
            else:
                position = pos + t.lines[line].startRune + 1
                offset = totalWidth + width
            return
        totalWidth += width
        inc pos

    position = pos + t.lines[line].startRune
    if line < t.lines.high and position > 0: dec position
    offset = totalWidth

proc lineAtHeight*(t: FormattedText, height: Coord): int =
    t.updateCacheIfNeeded()
    result = lowerBoundIt(t.lines, t.lines.low, t.lines.high, cmp(it.top, height) <= 0)
    if result > 0: dec result

proc topOffset*(t: FormattedText): float32 =
    t.updateCacheIfNeeded()
    case t.verticalAlignment
    of vaBottom: t.mBoundingSize.height - t.mTotalHeight
    of vaCenter: (t.mBoundingSize.height - t.mTotalHeight) / 2
    else: 0

proc getClosestCursorPositionToPoint*(t: FormattedText, p: Point, position: var int, offset: var Coord) =
    let ln = t.lineAtHeight(p.y - t.topOffset)
    t.getClosestCursorPositionToPointInLine(ln, p, position, offset)

proc runeLen*(t: FormattedText): int =
    # TODO: Optimize
    result = t.mText.runeLen

template len*(t: FormattedText): int = t.mText.len

################################################################################
# Some ugly api. Not recommended for use. May soon be removed.
################################################################################
template attrOfRuneAtPos(t: FormattedText, pos: int): Attributes =
    t.mAttributes[t.attrIndexForRuneAtPos(pos)]

proc colorOfRuneAtPos*(t: FormattedText, pos: int): tuple[color1, color2: Color, isGradient: bool] =
    let i = t.attrIndexForRuneAtPos(pos)
    result.color1 = t.mAttributes[i].textColor
    result.color2 = t.mAttributes[i].textColor2
    result.isGradient = t.mAttributes[i].isTextGradient

proc shadowOfRuneAtPos*(t: FormattedText, pos: int): tuple[color: Color, offset: Size, radius: float32] =
    let i = t.attrIndexForRuneAtPos(pos)
    result.color = t.mAttributes[i].shadowColor
    result.offset = t.mAttributes[i].shadowOffset
    result.radius = t.mAttributes[i].shadowRadius

proc strokeOfRuneAtPos*(t: FormattedText, pos: int): tuple[color1, color2: Color, size: float32, isGradient: bool] =
    let i = t.attrIndexForRuneAtPos(pos)
    result.color1 = t.mAttributes[i].strokeColor1
    result.color2 = t.mAttributes[i].strokeColor2
    result.size = t.mAttributes[i].strokeSize
    result.isGradient = t.mAttributes[i].isStrokeGradient

proc fontOfRuneAtPos*(t: FormattedText, pos: int): Font =
    t.attrOfRuneAtPos(pos).font

proc trackingOfRuneAtPos*(t: FormattedText, pos: int): float32 =
    t.attrOfRuneAtPos(pos).tracking

################################################################################
# Drawing
################################################################################
import nimx.context, nimx.composition


const GRADIENT_ENABLED = 1 # OPTION_1
const STROKE_ENABLED = 2 # OPTION_2

var gradientAndStrokeComposition = newComposition("""
attribute vec4 aPosition;

#ifdef OPTION_1
    uniform float point_y;
    uniform float size_y;
    varying float vGradient;
#endif

uniform mat4 uModelViewProjectionMatrix;
varying vec2 vTexCoord;

void main() {
    vTexCoord = aPosition.zw;
    gl_Position = uModelViewProjectionMatrix * vec4(aPosition.xy, 0, 1);

#ifdef OPTION_1
    vGradient = abs(aPosition.y - point_y) / size_y;
#endif
}
""",

"""
uniform sampler2D texUnit;
uniform vec4 fillColor;

#ifdef OPTION_2
    uniform float strokeSize;
#endif

#ifdef OPTION_1
    uniform vec4 colorFrom;
    uniform vec4 colorTo;
    varying float vGradient;
#endif

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
    return 0.06 / glyphScale;
}

void compose()
{
    float scale = (1.0 / 320.0) / fwidth(vTexCoord.x);
    scale = abs(scale);
#ifdef OPTION_2
    float aBase = thresholdFunc(scale) - strokeSize;
#else
    float aBase = thresholdFunc(scale);
#endif
    float aRange = spreadFunc(scale);
    float aMin = max(0.0, aBase - aRange);
    float aMax = min(aBase + aRange, 1.0);

    float dist = texture2D(texUnit, vTexCoord).a;
    float alpha = smoothstep(aMin, aMax, dist);

#ifdef OPTION_1
    vec4 color = mix(colorFrom, colorTo, vGradient);
    gl_FragColor = vec4(color.rgb, alpha * color.a);
#else
    gl_FragColor = vec4(fillColor.rgb, alpha * fillColor.a);
#endif
}
""", false, "mediump")

proc drawShadow(c: GraphicsContext, origP: Point, t: FormattedText) =
    # TODO: Optimize heavily
    var p = origP
    let numLines = t.lines.len
    var curLine = 0
    let top = t.topOffset() + origP.y

    while curLine < numLines:
        p.x = origP.x + t.lineLeft(curLine)
        p.y = t.lines[curLine].top + t.lines[curLine].baseline + top
        for curAttrIndex, attrStartIndex, attrEndIndex in t.attrsInLine(curLine):
            c.fillColor = t.mAttributes[curAttrIndex].shadowColor

            let font = t.mAttributes[curAttrIndex].font
            let oldBaseline = font.baseline
            font.baseline = bAlphabetic

            var pp = p
            let ppp = pp
            pp.x += t.mAttributes[curAttrIndex].shadowOffset.width * t.shadowMultiplier.width
            pp.y += t.mAttributes[curAttrIndex].shadowOffset.height * t.shadowMultiplier.height
            c.drawText(t.mAttributes[curAttrIndex].font, pp, t.mText.substr(attrStartIndex, attrEndIndex))
            font.baseline = oldBaseline
            p.x += pp.x - ppp.x
        inc curLine

proc drawStroke(c: GraphicsContext, origP: Point, t: FormattedText) =
    # TODO: Optimize heavily
    var p = origP
    let numLines = t.lines.len
    var curLine = 0
    let top = t.topOffset() + origP.y

    while curLine < numLines:
        p.x = origP.x + t.lineLeft(curLine)
        p.y = t.lines[curLine].top + t.lines[curLine].baseline + top
        for curAttrIndex, attrStartIndex, attrEndIndex in t.attrsInLine(curLine):
            let font = t.mAttributes[curAttrIndex].font
            if t.mAttributes[curAttrIndex].strokeSize > 0:
                var options = STROKE_ENABLED
                if t.mAttributes[curAttrIndex].isStrokeGradient:
                    options = options or GRADIENT_ENABLED

                gradientAndStrokeComposition.options = options
                let gl = c.gl
                var cc = gl.getCompiledComposition(gradientAndStrokeComposition)

                gl.useProgram(cc.program)

                compositionDrawingDefinitions(cc, c, gl)

                setUniform("strokeSize", t.mAttributes[curAttrIndex].strokeSize / 15)

                if t.mAttributes[curAttrIndex].isStrokeGradient:
                    setUniform("point_y", p.y)
                    setUniform("size_y", t.lines[curLine].height)
                    setUniform("colorFrom", t.mAttributes[curAttrIndex].strokeColor1)
                    setUniform("colorTo", t.mAttributes[curAttrIndex].strokeColor2)
                else:
                    setUniform("fillColor", t.mAttributes[curAttrIndex].strokeColor1)

                gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
                setupPosteffectUniforms(cc)

                gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
                gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)

                let oldBaseline = font.baseline
                font.baseline = bAlphabetic
                c.drawTextBase(font, p, t.mText.substr(attrStartIndex, attrEndIndex))
                font.baseline = oldBaseline
            else:
                c.fillColor = newColor(0, 0, 0, 0)
                # Dirty hack to advance x position. Should be optimized, of course.
                c.drawText(font, p, t.mText.substr(attrStartIndex, attrEndIndex))

        inc curLine

proc drawText*(c: GraphicsContext, origP: Point, t: FormattedText) =
    t.updateCacheIfNeeded()

    if t.overrideColor.a == 0:
        if t.shadowAttrs.len > 0: c.drawShadow(origP, t)
        if t.strokeAttrs.len > 0: c.drawStroke(origP, t)

    var p = origP
    let numLines = t.lines.len
    var curLine = 0
    let top = t.topOffset() + origP.y

    while curLine < numLines:
        p.x = origP.x + t.lineLeft(curLine)
        p.y = t.lines[curLine].top + t.lines[curLine].baseline + top
        for curAttrIndex, attrStartIndex, attrEndIndex in t.attrsInLine(curLine):
            let font = t.mAttributes[curAttrIndex].font
            let oldBaseline = font.baseline
            font.baseline = bAlphabetic
            if t.mAttributes[curAttrIndex].isTextGradient:
                gradientAndStrokeComposition.options = GRADIENT_ENABLED
                let gl = c.gl
                var cc = gl.getCompiledComposition(gradientAndStrokeComposition)

                gl.useProgram(cc.program)

                compositionDrawingDefinitions(cc, c, gl)

                setUniform("point_y", p.y)
                setUniform("size_y", t.lines[curLine].height)
                setUniform("colorFrom", t.mAttributes[curAttrIndex].textColor)
                setUniform("colorTo", t.mAttributes[curAttrIndex].textColor2)

                gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
                setupPosteffectUniforms(cc)

                gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
                gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)

                c.drawTextBase(font, p, t.mText.substr(attrStartIndex, attrEndIndex))
            else:
                if t.overrideColor.a != 0:
                    c.fillColor = t.overrideColor
                else:
                    c.fillColor = t.mAttributes[curAttrIndex].textColor
                c.drawText(t.mAttributes[curAttrIndex].font, p, t.mText.substr(attrStartIndex, attrEndIndex))
            font.baseline = oldBaseline

        inc curLine

when isMainModule:
    let arial16 = newFontWithFace("Arial", 16)
    let arial40 = newFontWithFace("Arial", 16)
    if arial16.isNil:
        echo "Could not load font Arial. Skipping test."
    else:
        let t = newFormattedText("Hello world!")
        let h = t.lineHeight(0)
