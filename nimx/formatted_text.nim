import unicode, algorithm, strutils, sequtils
import nimx/font, nimx/types, nimx/unistring, nimx/utils/lower_bound


type
    FormattedText* = ref object
        mText: string
        mAttributes: seq[Attributes]
        lines: seq[LineInfo]
        mTotalHeight: float32
        mTotalWidth: float32
        horizontalAlignment*: HorizontalTextAlignment
        verticalAlignment*: VerticalAlignment
        mBoundingSize: Size
        mTruncationBehavior: TruncationBehavior
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
        hidden: bool

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
        shadowSpread: float32
        strokeSize: float32
        tracking: float32
        isTextGradient: bool
        isStrokeGradient: bool

    VerticalAlignment* = enum
        vaTop
        vaCenter
        vaBottom

    TruncationBehavior* = enum
        tbNone
        tbCut
        tbEllipsis

    HorizontalTextAlignment* = enum
        haLeft
        haRight
        haCenter
        haJustify

proc defaultAttributes(): Attributes =
    result.font = systemFont()
    result.textColor = blackColor()

proc `text=`*(t: FormattedText, s: string) =
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
    result.mTruncationBehavior = tbNone

proc updateCache(t: FormattedText) =
    t.cacheValid = true
    t.lines.setLen(0)
    t.shadowAttrs.setLen(0)
    t.strokeAttrs.setLen(0)
    t.mTotalHeight = 0
    t.mTotalWidth = 0

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
    var boundingHeight = t.mBoundingSize.height
    if boundingHeight == 0 or t.mTruncationBehavior == tbNone: boundingHeight = Inf

    var c: Rune
    let textLen = t.mText.len
    var curRune = 0

    if t.mAttributes[0].strokeSize > 0: t.strokeAttrs.add(0)
    if t.mAttributes[0].shadowColor.a != 0: t.shadowAttrs.add(0)

    template mustBreakLine(): bool =
        c == Rune('\l')

    template canBreakLine(): bool =
        t.canBreakOnAnyChar or c == Rune(' ') or c == Rune('-') or i == textLen or mustBreakLine()

    template canAddWordWithHeight(): bool =
        let curHeight = max(curLineInfo.height, curWordHeight)
        t.mTotalHeight + curHeight <= boundingHeight

    while i < textLen:
        let font = t.mAttributes[curAttrIndex].font

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
                    t.mTotalWidth = max(t.mTotalWidth, curLineInfo.width)
                    curLineInfo.top = t.mTotalHeight
                    curLineInfo.startByte = i
                    curLineInfo.startRune = curRune + 1
                    curLineInfo.width = 0
                    curLineInfo.height = 0
                    curLineInfo.baseline = 0
                    curLineInfo.firstAttr = curAttrIndex
                    curLineInfo.hidden = not canAddWordWithHeight()
            else:
                # Complete current line
                let tmp = curLineInfo # JS bug workaround. Copy to temp object.
                t.lines.add(tmp)
                t.mTotalHeight += curLineInfo.height + t.mLineSpacing
                t.mTotalWidth = max(t.mTotalWidth, curLineInfo.width)
                curLineInfo.top = t.mTotalHeight
                curLineInfo.startByte = curWordStartByte
                curLineInfo.startRune = curWordStartRune
                curLineInfo.width = curWordWidth
                curLineInfo.height = curWordHeight
                curLineInfo.baseline = curWordBaseline
                curLineInfo.firstAttr = curWordFirstAttr
                curLineInfo.hidden = not canAddWordWithHeight()

            curWordWidth = 0
            curWordHeight = 0
            curWordBaseline = 0
            curWordStartByte = i
            curWordStartRune = curRune + 1
            curWordFirstAttr = curAttrIndex

        # Switch to next attribute if its time
        if i == nextAttrStartIndex:
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
        t.mTotalWidth = max(t.mTotalWidth, curLineInfo.width)
        curLineInfo.hidden = not canAddWordWithHeight()

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

proc `truncationBehavior=`*(t: FormattedText, b: TruncationBehavior) =
    if b != t.mTruncationBehavior:
        t.mTruncationBehavior = b
        t.cacheValid = false

template truncationBehavior*(t: FormattedText): TruncationBehavior = t.mTruncationBehavior

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

proc totalWidth*(t: FormattedText): float32 =
    t.updateCacheIfNeeded()
    t.mTotalWidth

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

proc setTextAlphaInRange*(t: FormattedText, a, b: int, alpha: float32) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].textColor.a = alpha
        t.mAttributes[i].textColor2.a = alpha

proc setShadowInRange*(t: FormattedText, a, b: int, color: Color, offset: Size, radius, spread: float32) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].shadowColor = color
        t.mAttributes[i].shadowOffset = offset
        t.mAttributes[i].shadowRadius = radius
        t.mAttributes[i].shadowSpread = spread
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
    let stopRuneByte = byteOffsets[1]
    let stopByte = stopRuneByte + t.mText.runeLenAt(stopRuneByte) - 1

    let bl = stopByte - startByte + 1
    let rl = stop - start + 1

    t.mText.delete(startByte, stopByte)

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

proc shadowOfRuneAtPos*(t: FormattedText, pos: int): tuple[color: Color, offset: Size, radius, spread: float32] =
    let i = t.attrIndexForRuneAtPos(pos)
    result.color = t.mAttributes[i].shadowColor
    result.offset = t.mAttributes[i].shadowOffset
    result.radius = t.mAttributes[i].shadowRadius
    result.spread = t.mAttributes[i].shadowSpread

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
import nimx/context, nimx/composition


const GRADIENT_ENABLED = (1 shl 0) # OPTION_1
const STROKE_ENABLED = (1 shl 1) # OPTION_2
const SOFT_SHADOW_ENABLED = (1 shl 2) # OPTION_3

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

#ifdef OPTION_1
    uniform vec4 colorFrom;
    uniform vec4 colorTo;
    varying float vGradient;
#endif

#ifdef OPTION_2
    uniform float strokeSize;
#endif

#ifdef OPTION_3
    uniform float shadowRadius;
    uniform float shadowSpread;
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
#ifdef OPTION_3
    float aBase = thresholdFunc(scale) - shadowRadius;
#elif defined(OPTION_2)
    float aBase = thresholdFunc(scale) - strokeSize;
#else
    float aBase = thresholdFunc(scale);
#endif
    float aRange = spreadFunc(scale);
    float aMin = max(0.0, aBase - aRange);
    float aMax = min(aBase + aRange, 1.0);

    float dist = texture2D(texUnit, vTexCoord).a;
#ifdef OPTION_3
    float alpha = smoothstep(aMin, aMin + shadowSpread, dist)  / (aMin + shadowSpread);
    alpha = min(alpha, 1.0);
#else
    float alpha = smoothstep(aMin, aMax, dist);
#endif

#ifdef OPTION_1
    vec4 color = mix(colorFrom, colorTo, vGradient);
    gl_FragColor = vec4(color.rgb, alpha * color.a);
#else
    gl_FragColor = vec4(fillColor.rgb, alpha * fillColor.a);
#endif
}
""", false, "mediump")

type ForEachLineAttributeCallback = proc(c: GraphicsContext, t: FormattedText, p: var Point, curLine, endIndex: int, str: string) {.nimcall.}
proc forEachLineAttribute(c: GraphicsContext, inRect: Rect, origP: Point, t: FormattedText, cb: ForEachLineAttributeCallback) =
    var p = origP
    let numLines = t.lines.len
    var curLine = 0
    let top = t.topOffset() + origP.y

    while curLine < numLines:
        p.x = origP.x + t.lineLeft(curLine)
        p.y = t.lines[curLine].top + t.lines[curLine].baseline + top
        if not inRect.contains(p):
            curLine.inc
            continue

        var lastCurAttrIndex: int
        var lastAttrStartIndex: int
        var lastAttrEndIndex: int
        var lastAttrFont: Font

        for curAttrIndex, attrStartIndex, attrEndIndex in t.attrsInLine(curLine):
            if not lastAttrFont.isNil:
                cb(c, t, p, curLine, lastCurAttrIndex, t.mText.substr(lastAttrStartIndex, lastAttrEndIndex))

            lastCurAttrIndex = curAttrIndex
            lastAttrStartIndex = attrStartIndex
            lastAttrEndIndex = attrEndIndex
            lastAttrFont = t.mAttributes[curAttrIndex].font

        if not lastAttrFont.isNil:
            let nextLine = curLine + 1
            let isNextLineHidden = nextLine < numLines and t.lines[nextLine].hidden

            if (curLine == numLines - 1 or isNextLineHidden) and t.mTruncationBehavior != tbNone:
                let lastIndex = lastAttrEndIndex
                var symbols = ""
                var runeWidth = 0.0

                if t.mTruncationBehavior == tbEllipsis:
                    symbols = "..."
                    runeWidth = lastAttrFont.getAdvanceForRune(Rune(symbols[0]))

                let ellipsisWidth = runeWidth * symbols.len.float
                var width = ellipsisWidth
                var index = lastAttrStartIndex
                var isCut = false
                while index <= lastIndex:
                    var r: Rune
                    fastRuneAt(t.mText, index, r, true)
                    var w = lastAttrFont.getAdvanceForRune(r)
                    if w + width < t.mBoundingSize.width:
                        width = width + w
                        lastAttrEndIndex = index - 1
                    else:
                        isCut = true
                        break

                if isNextLineHidden:
                    isCut = true

                if not isCut:
                    width -= ellipsisWidth

                if t.horizontalAlignment == haCenter:
                    p.x = (t.mBoundingSize.width - width) * 0.5
                elif t.horizontalAlignment == haRight:
                    p.x = t.mBoundingSize.width - width

                if not isCut:
                    cb(c, t, p, curLine, lastCurAttrIndex, t.mText.substr(lastAttrStartIndex, lastAttrEndIndex))
                else:
                    cb(c, t, p, curLine, lastCurAttrIndex, t.mText.substr(lastAttrStartIndex, lastAttrEndIndex) & symbols)
                    break
            else:
                cb(c, t, p, curLine, lastCurAttrIndex, t.mText.substr(lastAttrStartIndex, lastAttrEndIndex))

        curLine.inc


proc drawShadow(c: GraphicsContext, inRect: Rect, origP: Point, t: FormattedText) =
    # TODO: Optimize heavily
    forEachLineAttribute(c, inRect, origP, t) do(c: GraphicsContext, t: FormattedText, p: var Point, curLine, curAttrIndex: int, str: string):
        c.fillColor = t.mAttributes[curAttrIndex].shadowColor
        let font = t.mAttributes[curAttrIndex].font
        let oldBaseline = font.baseline
        font.baseline = bAlphabetic

        var pp = p
        let ppp = pp
        pp.x += t.mAttributes[curAttrIndex].shadowOffset.width * t.shadowMultiplier.width
        pp.y += t.mAttributes[curAttrIndex].shadowOffset.height * t.shadowMultiplier.height


        if t.mAttributes[curAttrIndex].shadowRadius > 0.0 or t.mAttributes[curAttrIndex].shadowSpread > 0.0:
            var options = SOFT_SHADOW_ENABLED
            gradientAndStrokeComposition.options = options
            let gl = c.gl
            var cc = gl.getCompiledComposition(gradientAndStrokeComposition)

            gl.useProgram(cc.program)

            compositionDrawingDefinitions(cc, c, gl)

            const minShadowSpread = 0.17 # make shadow border smooth and great again

            setUniform("shadowRadius", t.mAttributes[curAttrIndex].shadowRadius / 8.0)
            setUniform("shadowSpread", t.mAttributes[curAttrIndex].shadowSpread + minShadowSpread)
            setUniform("fillColor", c.fillColor)

            gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
            setupPosteffectUniforms(cc)

            gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
            gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)

            c.drawTextBase(font, pp, str)
        else:
            c.drawText(font, pp, str)

        font.baseline = oldBaseline
        p.x += pp.x - ppp.x

proc drawStroke(c: GraphicsContext, inRect: Rect, origP: Point, t: FormattedText) =
    # TODO: Optimize heavily
    forEachLineAttribute(c, inRect, origP, t) do(c: GraphicsContext, t: FormattedText, p: var Point, curLine, curAttrIndex: int, str: string):
        const magicStrokeMaxSizeCoof = 0.46
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

            setUniform("strokeSize", min(t.mAttributes[curAttrIndex].strokeSize / 15, magicStrokeMaxSizeCoof))

            if t.mAttributes[curAttrIndex].isStrokeGradient:
                setUniform("point_y", p.y - t.lines[curLine].baseline)
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
            c.drawTextBase(font, p, str)
            font.baseline = oldBaseline
        else:
            c.fillColor = newColor(0, 0, 0, 0)
            # Dirty hack to advance x position. Should be optimized, of course.
            c.drawText(font, p, str)

proc drawText*(c: GraphicsContext, inRect: Rect, origP: Point, t: FormattedText) =
    t.updateCacheIfNeeded()

    if t.overrideColor.a == 0:
        if t.shadowAttrs.len > 0: c.drawShadow(inRect, origP, t)
        if t.strokeAttrs.len > 0: c.drawStroke(inRect, origP, t)

    forEachLineAttribute(c, inRect, origP, t) do(c: GraphicsContext, t: FormattedText, p: var Point, curLine, curAttrIndex: int, str: string):
        let font = t.mAttributes[curAttrIndex].font
        let oldBaseline = font.baseline
        font.baseline = bAlphabetic
        if t.mAttributes[curAttrIndex].isTextGradient:
            gradientAndStrokeComposition.options = GRADIENT_ENABLED
            let gl = c.gl
            var cc = gl.getCompiledComposition(gradientAndStrokeComposition)

            gl.useProgram(cc.program)

            compositionDrawingDefinitions(cc, c, gl)

            setUniform("point_y", p.y - t.lines[curLine].baseline)
            setUniform("size_y", t.lines[curLine].height)
            setUniform("colorFrom", t.mAttributes[curAttrIndex].textColor)
            setUniform("colorTo", t.mAttributes[curAttrIndex].textColor2)

            gl.uniformMatrix4fv(uniformLocation("uModelViewProjectionMatrix"), false, c.transform)
            setupPosteffectUniforms(cc)

            gl.activeTexture(GLenum(int(gl.TEXTURE0) + cc.iTexIndex))
            gl.uniform1i(uniformLocation("texUnit"), cc.iTexIndex)

            c.drawTextBase(font, p, str)
        else:
            if t.overrideColor.a != 0:
                c.fillColor = t.overrideColor
            else:
                c.fillColor = t.mAttributes[curAttrIndex].textColor
            c.drawText(font, p, str)

        font.baseline = oldBaseline

when isMainModule:
    let arial16 = newFontWithFace("Arial", 16)
    let arial40 = newFontWithFace("Arial", 16)
    if arial16.isNil:
        echo "Could not load font Arial. Skipping test."
    else:
        let t = newFormattedText("Hello world!")
        let h = t.lineHeight(0)
