import strutils
import sample_registry
import nimx / [ view, font, context, button, text_field, slider, popup_button,
                formatted_text, segmented_control, scroll_view ]

type TextView = ref object of View
    text: FormattedText

type TextSampleView = ref object of View

const textSample = """Nim is statically typed, with a simple syntax. It supports compile-time metaprogramming features such as syntactic macros and term rewriting macros.
    Term rewriting macros enable library implementations of common data structures such as bignums and matrixes to be implemented with an efficiency as if they would have been builtin language facilities.
    Iterators are supported and can be used as first class entities in the language as can functions, these features allow for functional programming to be used.
    Object-oriented programming is supported by inheritance and multiple dispatch. Functions can be generic and can also be overloaded, generics are further enhanced by the support for type classes.
    Operator overloading is also supported. Nim includes automatic garbage collection based on deferred reference counting with cycle detection.
    Andrew Binstock (editor-in-chief of Dr. Dobb's) says Nim (formerly known as Nimrod) "presents a most original design that straddles Pascal and Python and compiles to C code or JavaScript.
    And realistic Soft Shadow :)"""

iterator rangesOfSubstring(haystack, needle: string): (int, int) =
    var start = 0
    while true:
        let index = haystack.find(needle, start)
        if index == -1:
            break
        else:
            let b = index + needle.len
            yield (index, b)
            start = b

method init(v: TextSampleView, gfx: GraphicsContext, r: Rect) =
    template fontCtx: untyped = gfx.fontCtx
    template gl: untyped = gfx.gl
    procCall v.View.init(gfx, r)

    let tv = TextField.new(gfx, v.bounds.inset(50, 50))
    tv.resizingMask = "wh"
    tv.text = textSample
    tv.backgroundColor = newColor(0.5, 0, 0, 0.5)
    tv.multiline = true

    for a, b in tv.text.rangesOfSubstring("Nim"):
        setFontInRange(fontCtx, gl, tv.formattedText, a, b, systemFontOfSize(fontCtx, 40))
        setStrokeInRange(fontCtx, gl, tv.formattedText, a, b, newColor(1, 0, 0), 5)

    for a, b in tv.text.rangesOfSubstring("programming"):
        setTextColorInRange(fontCtx, gl, tv.formattedText, a, b, newColor(1, 0, 0))
        setShadowInRange(fontCtx, gl, tv.formattedText, a, b, newGrayColor(0.5, 0.5), newSize(2, 3), 0.0, 0.0)

    for a, b in tv.text.rangesOfSubstring("supported"):
        setTextColorInRange(fontCtx, gl, tv.formattedText, a, b, newColor(0, 0.6, 0))

    for a, b in tv.text.rangesOfSubstring("Soft Shadow"):
        setFontInRange(fontCtx, gl, tv.formattedText, a, b, systemFontOfSize(fontCtx, 40))
        setShadowInRange(fontCtx, gl, tv.formattedText, a, b, newColor(0.0, 0.0, 1.0, 1.0), newSize(2, 3), 5.0, 0.8)

    let sv = newScrollView(gfx, tv)
    v.addSubview(sv)

    let hAlignChooser = SegmentedControl.new(gfx, newRect(5, 5, 200, 25))
    hAlignChooser.segments = @[$haLeft, $haCenter, $haRight]
    v.addSubview(hAlignChooser)
    hAlignChooser.onAction do():
        tv.formattedText.horizontalAlignment = parseEnum[HorizontalTextAlignment](hAlignChooser.segments[hAlignChooser.selectedSegment])

    let vAlignChooser = SegmentedControl.new(gfx, newRect(hAlignChooser.frame.maxX + 5, 5, 200, 25))
    vAlignChooser.segments = @[$vaTop, $vaCenter, $vaBottom]
    vAlignChooser.selectedSegment = 0
    v.addSubview(vAlignChooser)
    vAlignChooser.onAction do():
        tv.formattedText.verticalAlignment = parseEnum[VerticalAlignment](vAlignChooser.segments[vAlignChooser.selectedSegment])
    tv.formattedText.verticalAlignment = vaTop

method draw(v: TextView, r: Rect) =
    template gfx: untyped = v.gfx
    procCall v.View.draw(r)
    v.text.boundingSize = v.bounds.size
    gfx.drawText(newPoint(0, 0), v.text)

registerSample(TextSampleView, "Text")
