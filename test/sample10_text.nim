import strutils

import sample_registry

import nimx.view
import nimx.font
import nimx.context
import nimx.button
import nimx.text_field
import nimx.slider
import nimx.popup_button
import nimx.formatted_text
import nimx.segmented_control

type TextView = ref object of View
    text: FormattedText

type TextSampleView = ref object of View

const textSample = """Nim is statically typed, with a simple syntax. It supports compile-time metaprogramming features such as syntactic macros and term rewriting macros. Term rewriting macros enable library implementations of common data structures such as bignums and matrixes to be implemented with an efficiency as if they would have been builtin language facilities. Iterators are supported and can be used as first class entities in the language as can functions, these features allow for functional programming to be used. Object-oriented programming is supported by inheritance and multiple dispatch. Functions can be generic and can also be overloaded, generics are further enhanced by the support for type classes. Operator overloading is also supported. Nim includes automatic garbage collection based on deferred reference counting with cycle detection. Andrew Binstock (editor-in-chief of Dr. Dobb's) says Nim (formerly known as Nimrod) "presents a most original design that straddles Pascal and Python and compiles to C code or JavaScript." """

#const textSample = """Hello"""

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

method init(v: TextSampleView, r: Rect) =
    procCall v.View.init(r)

    let tv = TextField.new(v.bounds.inset(50, 50))
    tv.resizingMask = "wh"
    tv.text = textSample
    tv.backgroundColor = newColor(0.5, 0, 0, 0.5)

    for a, b in tv.text.rangesOfSubstring("Nim"):
        tv.formattedText.setFontInRange(a, b, systemFontOfSize(40))
        tv.formattedText.setStrokeInRange(a, b, newColor(1, 0, 0), 5)

    for a, b in tv.text.rangesOfSubstring("programming"):
        tv.formattedText.setTextColorInRange(a, b, newColor(1, 0, 0))
        tv.formattedText.setShadowInRange(a, b, newGrayColor(0.5, 0.5), newSize(2, 3))

    for a, b in tv.text.rangesOfSubstring("supported"):
        tv.formattedText.setTextColorInRange(a, b, newColor(0, 0.6, 0))

    v.addSubview(tv)

    let hAlignChooser = SegmentedControl.new(newRect(5, 5, 200, 25))
    hAlignChooser.segments = @[$haLeft, $haCenter, $haRight]
    v.addSubview(hAlignChooser)
    hAlignChooser.onAction do():
        tv.formattedText.horizontalAlignment = parseEnum[HorizontalTextAlignment](hAlignChooser.segments[hAlignChooser.selectedSegment])

    let vAlignChooser = SegmentedControl.new(newRect(hAlignChooser.frame.maxX + 5, 5, 200, 25))
    vAlignChooser.segments = @[$vaTop, $vaCenter, $vaBottom]
    vAlignChooser.selectedSegment = 1
    v.addSubview(vAlignChooser)
    vAlignChooser.onAction do():
        tv.formattedText.verticalAlignment = parseEnum[VerticalAlignment](vAlignChooser.segments[vAlignChooser.selectedSegment])

method draw(v: TextView, r: Rect) =
    procCall v.View.draw(r)
    let c = currentContext()
    v.text.boundingSize = v.bounds.size
    c.drawText(newPoint(0, 0), v.text)

registerSample(TextSampleView, "Text")
