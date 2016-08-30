import unicode, algorithm, strutils
import nimx.font, nimx.types, nimx.context, nimx.unistring


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
        breakPos: int
        width: float32
        height: float32
        baseline: float32 # distance from top of the line to baseline
        firstAttr: int

    Attributes = object
        start: int # Index of char where attributes start.
        runeStart: int # Index of rune where attributes start.
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

    var curLineWidth = 0'f32
    var curLineHeight = 0'f32
    var curLineBaseline = 0'f32

    var firstAttrInLine = 0

    # In this context "word" means minimal sequence of runes that can not have
    # line break
    var curWordWidth = 0'f32
    var curWordHeight = 0'f32
    var curWordBaseline = 0'f32

    var curWordStart = 0

    var i = 0
    var curAttrIndex = 0
    var nextAttrStartIndex = -1
    if t.mAttributes.len > 1:
        nextAttrStartIndex = t.mAttributes[1].start

    var boundingWidth = t.mBoundingSize.width
    if boundingWidth == 0: boundingWidth = Inf

    const lineSpacing = 2'f32

    var c: Rune
    let textLen = t.mText.len

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

            if curLineWidth + curWordWidth < boundingWidth:
                # Word fits in the line
                curLineWidth += curWordWidth
                curLineHeight = max(curLineHeight, curWordHeight)
                curLineBaseline = max(curLineBaseline, curWordBaseline)
            else:
                # Complete current line
                var li: LineInfo
                li.breakPos = curWordStart
                li.height = curLineHeight
                li.width = curLineWidth
                li.baseline = curLineBaseline
                li.firstAttr = firstAttrInLine
                t.lines.add(li)
                t.mTotalHeight += curLineHeight + lineSpacing
                curLineWidth = curWordWidth
                curLineHeight = curWordHeight
                curLineBaseline = curWordBaseline
                firstAttrInLine = curAttrIndex

            curWordWidth = 0
            curWordHeight = 0
            curWordBaseline = 0
            curWordStart = i

        # Switch to next attribute if its time
        if charStart + 1 == nextAttrStartIndex:
            inc curAttrIndex
            if t.mAttributes.high > curAttrIndex:
                nextAttrStartIndex = t.mAttributes[curAttrIndex + 1].start

    if curLineWidth > 0:
        var li: LineInfo
        li.breakPos = curWordStart
        li.height = curLineHeight
        li.width = curLineWidth
        li.baseline = curLineBaseline
        li.firstAttr = firstAttrInLine
        t.lines.add(li)
        t.mTotalHeight += curLineHeight + lineSpacing


    # echo "Cache updated for ", t.mText
    # echo "Attributes: ", t.mAttributes
    # echo "lines: ", t.lines

proc `boundingSize=`*(t: FormattedText, s: Size) =
    if s != t.mBoundingSize:
        t.mBoundingSize = s
        t.cacheValid = false

proc prepareAttributes(t: FormattedText, a: int): int =
    proc cmpByRuneStart(a, b: Attributes): int = cmp(a.runeStart, b.runeStart)

    var attr: Attributes
    attr.runeStart = a

    result = lowerBound(t.mAttributes, attr, cmpByRuneStart)
    if result < t.mAttributes.len and t.mAttributes[result].runeStart == a:
        return

    var iRune = t.mAttributes[result - 1].runeStart
    var iChar = t.mAttributes[result - 1].start
    var r: Rune
    while iRune < a:
        fastRuneAt(t.mText, iChar, r, true)
        inc iRune
    t.mAttributes.insert(attr, result)
    t.mAttributes[result] = t.mAttributes[result - 1]
    t.mAttributes[result].runeStart = a
    t.mAttributes[result].start = iChar

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

proc uniInsert*(t: FormattedText, atIndex: int, s: string) =
    t.cacheValid = false
    t.mText.uniInsert(s, atIndex)
    # TODO: Move attributes

proc uniDelete*(t: FormattedText, start, stop: int) =
    t.cacheValid = false
    t.mText.uniDelete(start, stop)
    # TODO: Move attributes

iterator attrsInLine(t: FormattedText, line: int): tuple[attrIndex, a, b: int] =
    let firstAttrInLine = t.lines[line].firstAttr
    var curAttrIndex = firstAttrInLine
    let breakPos = t.lines[line].breakPos
    while curAttrIndex < t.mAttributes.len and t.mAttributes[curAttrIndex].start < breakPos:
        var attrStartIndex = t.mAttributes[curAttrIndex].start
        if line > 0 and curAttrIndex == firstAttrInLine:
            attrStartIndex = t.lines[line - 1].breakPos

        var attrEndIndex = breakPos
        var attributeBreaks = true
        if t.mAttributes.high > curAttrIndex:
            let nextAttrStart = t.mAttributes[curAttrIndex + 1].start
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
            charOff = t.mAttributes[curAttrIndex].start
            while charOff < attrStartIndex:
                inc charOff, runeLenAt(t.mText, charOff)
            first = false
        while charOff <= attrEndIndex:
            fastRuneAt(t.mText, charOff, r, true)
            let w = t.mAttributes[curAttrIndex].font.getAdvanceForRune(r)
            yield w
            inc p

template updateCacheIfNeeded(t: FormattedText) =
    if not t.cacheValid: t.updateCache()

proc cursorOffsetForPositionInLine*(t: FormattedText, line, position: int): Coord =
    t.updateCacheIfNeeded()

    if t.lines.len == 0: return

    var p = 0
    for width in t.runeWidthsInLine(line):
        if p == position: break
        result += width
        inc p

proc getClosestCursorPositionToPointInLine*(t: FormattedText, line: int, p: Point, position: var int, offset: var Coord) =
    t.updateCacheIfNeeded()

    if t.lines.len == 0: return

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

proc getLinesAtHeights*(t: FormattedText, heights: openarray[Coord], lines: var openarray[int]) =
    assert(heights.len == lines.len)
    var line = 0
    var iHeight = 0
    var height = 0'f32
    while line < t.lines.len:
        height += t.lines[line].height
        while iHeight < heights.len and heights[iHeight] < height:
            lines[iHeight] = line
            inc iHeight
        if iHeight == heights.len: break
        inc line

proc lineAtHeight*(t: FormattedText, height: Coord): int =
    var res: array[1, int]
    t.getLinesAtHeights([height], res)
    result = res[0]

proc runeLen*(t: FormattedText): int =
    # TODO: Optimize
    result = t.mText.runeLen

template len*(t: FormattedText): int = t.mText.len

proc drawText*(c: GraphicsContext, origP: Point, t: FormattedText) =
    t.updateCacheIfNeeded()

    var p = origP
    let numLines = t.lines.len
    var curLine = 0

    while curLine < numLines:
        p.x = origP.x
        if t.horizontalAlignment == haRight:
            p.x = p.x + t.mBoundingSize.width - t.lines[curLine].width
        elif t.horizontalAlignment == haCenter:
                p.x = p.x + (t.mBoundingSize.width - t.lines[curLine].width) / 2

        let lineY = p.y
        p.y = lineY + t.lines[curLine].baseline
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

        p.y = lineY + t.lines[curLine].height
        inc curLine
