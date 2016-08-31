import unicode, algorithm, strutils, sequtils
import nimx.font, nimx.types, nimx.context, nimx.unistring, nimx.utils.lower_bound


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
        backgroundColor: Color

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
    t.mText = s
    t.cacheValid = false

template text*(t: FormattedText): string = t.mText

proc newFormattedText*(s: string = ""): FormattedText =
    result.new()
    result.mText = s
    result.mAttributes = @[defaultAttributes()]
    result.lines = @[]

proc updateCache(t: FormattedText) =
    t.cacheValid = true
    t.lines.setLen(0)
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

    const lineSpacing = 2'f32

    var c: Rune
    let textLen = t.mText.len
    var curRune = 0

    while i < textLen:
        let font = t.mAttributes[curAttrIndex].font
        let charStart = i

        fastRuneAt(t.mText, i, c, true)

        let runeWidth = font.getAdvanceForRune(c)

        template canBreakLine(): bool =
            t.canBreakOnAnyChar or c == Rune(' ') or c == Rune('-') or charStart == textLen - 1

        curWordWidth += runeWidth
        curWordHeight = max(curWordHeight, font.height)
        curWordBaseline = max(curWordBaseline, font.ascent)

        if canBreakLine():
            # commit current word

            if curLineInfo.width + curWordWidth < boundingWidth:
                # Word fits in the line
                curLineInfo.width += curWordWidth
                curLineInfo.height = max(curLineInfo.height, curWordHeight)
                curLineInfo.baseline = max(curLineInfo.baseline, curWordBaseline)
            else:
                # Complete current line
                let tmp = curLineInfo # JS bug workaround. Copy to temp object.
                t.lines.add(tmp)
                t.mTotalHeight += curLineInfo.height + lineSpacing
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
            if t.mAttributes.high > curAttrIndex:
                nextAttrStartIndex = t.mAttributes[curAttrIndex + 1].startByte

        inc curRune

    if curLineInfo.width > 0 or t.lines.len == 0:
        let tmp = curLineInfo # JS bug workaround. Copy to temp object.
        t.lines.add(tmp)
        t.mTotalHeight += curLineInfo.height + lineSpacing

    # echo "Cache updated for ", t.mText
    # echo "Attributes: ", t.mAttributes
    # echo "lines: ", t.lines

template updateCacheIfNeeded(t: FormattedText) =
    if not t.cacheValid: t.updateCache()

proc `boundingSize=`*(t: FormattedText, s: Size) =
    if s != t.mBoundingSize:
        t.mBoundingSize = s
        t.cacheValid = false

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
    let ab = t.prepareAttributes(b)
    for i in aa ..< ab: yield i

proc setFontInRange*(t: FormattedText, a, b: int, f: Font) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].font = f
    t.cacheValid = false

proc setTextColorInRange*(t: FormattedText, a, b: int, c: Color) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].textColor = c

proc attrIndexForRuneAtPos(t: FormattedText, pos: int): int =
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
            position = pos
            offset = totalWidth
            return
        totalWidth += width
        inc pos

    position = pos
    offset = totalWidth

proc lineAtHeight*(t: FormattedText, height: Coord): int =
    t.updateCacheIfNeeded()
    result = lowerBoundIt(t.lines, t.lines.low, t.lines.high, cmp(it.top, height) <= 0) - 1

proc topOffset*(t: FormattedText): float32 =
    t.updateCacheIfNeeded()
    case t.verticalAlignment
    of vaBottom: t.mBoundingSize.height - t.mTotalHeight
    of vaCenter: (t.mBoundingSize.height - t.mTotalHeight) / 2
    else: 0

proc getClosestCursorPositionToPoint*(t: FormattedText, p: Point, position: var int, offset: var Coord) =
    let ln = t.lineAtHeight(p.y - t.topOffset)
    t.getClosestCursorPositionToPointInLine(ln, p, position, offset)
    position += t.lines[ln].startRune

proc runeLen*(t: FormattedText): int =
    # TODO: Optimize
    result = t.mText.runeLen

template len*(t: FormattedText): int = t.mText.len

proc drawText*(c: GraphicsContext, origP: Point, t: FormattedText) =
    t.updateCacheIfNeeded()

    var p = origP
    let numLines = t.lines.len
    var curLine = 0
    let top = t.topOffset()

    while curLine < numLines:
        p.x = origP.x
        if t.horizontalAlignment == haRight:
            p.x = p.x + t.mBoundingSize.width - t.lines[curLine].width
        elif t.horizontalAlignment == haCenter:
                p.x = p.x + (t.mBoundingSize.width - t.lines[curLine].width) / 2

        p.y = t.lines[curLine].top + t.lines[curLine].baseline + top
        for curAttrIndex, attrStartIndex, attrEndIndex in t.attrsInLine(curLine):
            if t.overrideColor.a != 0:
                c.fillColor = t.overrideColor
            else:
                c.fillColor = t.mAttributes[curAttrIndex].textColor

            let font = t.mAttributes[curAttrIndex].font
            let oldBaseline = font.baseline
            font.baseline = bAlphabetic
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
