import unicode, algorithm
import nimx.font, nimx.types, nimx.context


type
    FormattedText* = ref object
        text*: string
        mAttributes: seq[Attributes]
        lines: seq[LineInfo]
        mTotalHeight: float32
        horizontalAlignment*: HorizontalTextAlignment
        verticalAlignment*: VerticalAlignment
        mBoundingSize: Size
        cacheValid: bool
        canBreakOnAnyChar: bool

    LineInfo* = object
        breakPos: int
        width: float32
        height: float32
        baseline: float32 # distance from top of the line to baseline

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

proc newFormattedText*(s: string = ""): FormattedText =
    result.new()
    result.text = s
    result.mAttributes = @[defaultAttributes()]
    result.lines = @[]

proc updateCache(t: FormattedText) =
    t.cacheValid = true
    t.lines.setLen(0)
    t.mTotalHeight = 0

    var curLineWidth = 0'f32
    var curLineHeight = 0'f32
    var curLineBaseline = 0'f32

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
    let textLen = t.text.len

    while i < textLen:
        let font = t.mAttributes[curAttrIndex].font

        # Switch to next attribute if its time
        if i + 1 == nextAttrStartIndex:
            inc curAttrIndex
            if t.mAttributes.high > curAttrIndex:
                nextAttrStartIndex = t.mAttributes[curAttrIndex + 1].start

        fastRuneAt(t.text, i, c, true)

        let runeWidth = font.getAdvanceForRune(c)

        template canBreakLine(): bool =
            t.canBreakOnAnyChar or c == Rune(' ') or c == Rune('-') or i == textLen - 1

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
                t.lines.add(li)
                t.mTotalHeight += curLineHeight + lineSpacing
                curLineWidth = curWordWidth
                curLineHeight = curWordHeight
                curLineBaseline = curWordBaseline

            curWordWidth = 0
            curWordHeight = 0
            curWordBaseline = 0
            curWordStart = i

    if curLineWidth > 0:
        var li: LineInfo
        li.breakPos = curWordStart
        li.height = curLineHeight
        li.width = curLineWidth
        li.baseline = curLineBaseline
        t.lines.add(li)
        t.mTotalHeight += curLineHeight + lineSpacing


    # echo "Cache updated. Bounds: ", boundingWidth
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
        fastRuneAt(t.text, iChar, r, true)
        inc iRune
    t.mAttributes.insert(attr, result)
    t.mAttributes[result] = t.mAttributes[result - 1]
    t.mAttributes[result].runeStart = a
    t.mAttributes[result].start = iChar

iterator attrsInRange(t: FormattedText, a, b: int): int =
    let aa = t.prepareAttributes(a)
    let ab = t.prepareAttributes(b)
    for i in aa ..< ab: yield i
    t.cacheValid = false

proc setFontInRange*(t: FormattedText, a, b: int, f: Font) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].font = f

proc setTextColorInRange*(t: FormattedText, a, b: int, c: Color) =
    for i in t.attrsInRange(a, b):
        t.mAttributes[i].textColor = c

proc drawText*(c: GraphicsContext, origP: Point, t: FormattedText) =
    if not t.cacheValid:
        t.updateCache()

    var p = origP
    var curAttrIndex = 0
    let numLines = t.lines.len
    var curLine = 0

    while curLine < numLines:
        p.x = origP.x
        if t.horizontalAlignment == haRight:
            p.x = p.x + t.mBoundingSize.width - t.lines[curLine].width
        elif t.horizontalAlignment == haCenter:
                p.x = p.x + (t.mBoundingSize.width - t.lines[curLine].width) / 2

        let lineY = p.y
        let firstAttrInLine = curAttrIndex
        while curAttrIndex < t.mAttributes.len and t.mAttributes[curAttrIndex].start < t.lines[curLine].breakPos:
            p.y = lineY + t.lines[curLine].baseline

            var attrStartIndex = t.mAttributes[curAttrIndex].start
            if curLine > 0 and curAttrIndex == firstAttrInLine:
                attrStartIndex = t.lines[curLine - 1].breakPos

            let endOfLine = t.lines[curLine].breakPos
            var attrEndIndex = endOfLine
            var attributeBreaks = true
            if t.mAttributes.high > curAttrIndex:
                let nextAttrStart = t.mAttributes[curAttrIndex + 1].start
                if nextAttrStart < attrEndIndex:
                    attrEndIndex = nextAttrStart
                    attributeBreaks = true

            c.fillColor = t.mAttributes[curAttrIndex].textColor

            let font = t.mAttributes[curAttrIndex].font
            let oldBaseline = font.baseline
            font.baseline = bAlphabetic
            c.drawText(t.mAttributes[curAttrIndex].font, p, t.text.substr(attrStartIndex, attrEndIndex - 1))
            font.baseline = oldBaseline

            if attrEndIndex == endOfLine:
                break

            if attributeBreaks:
                inc curAttrIndex

        p.y = lineY + t.lines[curLine].height
        inc curLine
