import dom

import nimx/private/font/font_data
import rect_packer

type JsGlyphProvider* = ref object
    face: string
    size: float32
    glyphMargin*: int32

proc setFace*(p: JsGlyphProvider, face: string) =
    p.face = face

template setSize*(p: JsGlyphProvider, sz: float32) =
    p.size = sz

proc cssFontName(p: JsGlyphProvider): cstring =
    let fSize = p.size
    let fName : cstring = p.face
    {.emit: """`result` = "" + (`fSize`|0) + "px " + `fName`;""".}

proc auxCanvasForFont(p: JsGlyphProvider): Element =
    let fName = p.cssFontName
    result = document.createElement("canvas")
    {.emit: """
    var ctx = `result`.getContext('2d');
    `result`.style.font = `fName`;
    ctx.font = `fName`;
    `result`.__nimx_ctx = ctx;
    """.}

template clearCache*(p: JsGlyphProvider) = discard

proc calculateFontMetricsInCanvas(fontName: cstring, fontSize: int): ref RootObj =
    # Idea borrowed from from https://github.com/Pomax/fontmetrics.js
    {.emit: """
    var textstring = "Hl@¿Éq¶";
    var canvas = document.createElement("canvas");
    var ctx = canvas.getContext("2d");
    ctx.font = `fontName`;
    `result` = ctx.measureText(textstring);

    var padding = 100;
    canvas.width = `result`.width + padding;
    canvas.height = 3*`fontSize`;
    canvas.style.opacity = 1;
    ctx.font = `fontName`;
    var w = canvas.width,
        h = canvas.height,
        baseline = h/2;

    // Set all canvas pixeldata values to 255, with all the content
    // data being 0. This lets us scan for data[i] != 255.
    ctx.fillStyle = "white";
    ctx.fillRect(-1, -1, w+2, h+2);
    ctx.fillStyle = "black";
    ctx.fillText(textstring, padding/2, baseline);
    var pixelData = ctx.getImageData(0, 0, w, h).data;

    // canvas pixel data is w*4 by h*4, because R, G, B and A are separate,
    // consecutive values in the array, rather than stored as 32 bit ints.
    var i = 0,
        w4 = w * 4,
        len = pixelData.length;

    // Finding the ascent uses a normal, forward scanline
    while (++i < len && pixelData[i] === 255) {}
    var ascent = (i/w4)|0;

    // Finding the descent uses a reverse scanline
    i = len - 1;
    while (--i > 0 && pixelData[i] === 255) {}
    var descent = (i/w4)|0;

    `result`.ascent = (baseline - ascent);
    `result`.descent = (descent - baseline);
    `result`.height = 1+(descent - ascent);
    """.}

proc getFontMetrics*(p: JsGlyphProvider, oAscent, oDescent: var float32) =
    var ascent, descent: float32
    let metrics = calculateFontMetricsInCanvas(p.cssFontName, int(p.size))
    {.emit: """
    `ascent` = `metrics`.ascent;
    `descent` = -`metrics`.descent;
    """.}
    oAscent = ascent
    oDescent = descent

proc bakeChars*(p: JsGlyphProvider, start: int32, data: var GlyphData) =
    let startChar = start * charChunkLength
    let endChar = startChar + charChunkLength

    var rectPacker = newPacker(32, 32)

    var ascent, descent: float32
    p.getFontMetrics(ascent, descent)

    let h = int32(ascent - descent)
    let canvas = p.auxCanvasForFont()
    let fName = p.cssFontName

    {.emit: """
    var ctx = `canvas`.__nimx_ctx;
    """.}

    for i in startChar ..< endChar:
        if isPrintableCodePoint(i):
            var w: int32
            {.emit: """
            `w` = ctx.measureText(String.fromCharCode(`i`)).width;
            """.}

            if w > 0:
                let (x, y) = rectPacker.packAndGrow(w + p.glyphMargin * 2, h + p.glyphMargin * 2)

                let c = charOff(i - startChar)
                #data.glyphMetrics.charOffComp(c, compX) = 0
                #data.glyphMetrics.charOffComp(c, compY) = 0
                data.glyphMetrics.charOffComp(c, compAdvance) = w.int16
                data.glyphMetrics.charOffComp(c, compTexX) = (x + p.glyphMargin).int16
                data.glyphMetrics.charOffComp(c, compTexY) = (y + p.glyphMargin).int16
                data.glyphMetrics.charOffComp(c, compWidth) = w.int16
                data.glyphMetrics.charOffComp(c, compHeight) = h.int16

    let texWidth = rectPacker.width
    let texHeight = rectPacker.height
    data.bitmapWidth = texWidth.uint16
    data.bitmapHeight = texHeight.uint16

    asm """
    `canvas`.width = `texWidth`;
    `canvas`.height = `texHeight`;
    ctx.textBaseline = "top";
    ctx.font = `fName`;
    """

    for i in startChar ..< endChar:
        let indexOfGlyphInRange = i - startChar
        data.dfDoneForGlyph[indexOfGlyphInRange] = true
        if isPrintableCodePoint(i) and i != ord(' '):
            let c = charOff(indexOfGlyphInRange)
            let w = data.glyphMetrics.charOffComp(c, compAdvance)
            if w > 0:
                let x = data.glyphMetrics.charOffComp(c, compTexX)
                let y = data.glyphMetrics.charOffComp(c, compTexY)
                {.emit: "ctx.fillText(String.fromCharCode(`i`), `x`, `y`);".}
                data.dfDoneForGlyph[indexOfGlyphInRange] = false

    var byteData : seq[byte]
    {.emit: """
    var sz = `texWidth` * `texHeight`;
    var imgData = ctx.getImageData(0, 0, `texWidth`, `texHeight`).data;
    `byteData` = new Uint8Array(sz);
    for (var i = 3, j = 0; j < sz; i += 4, ++j) `byteData`[j] = imgData[i];
    """.}

    shallowCopy(data.bitmap, byteData)
