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

type TextView = ref object of View
    text: FormattedText

type TextSampleView = ref object of View

const textSample = """
Nim is statically typed, with a simple syntax. It supports compile-time metaprogramming features such as syntactic macros and term rewriting macros. Term rewriting macros enable library implementations of common data structures such as bignums and matrixes to be implemented with an efficiency as if they would have been builtin language facilities. Iterators are supported and can be used as first class entities in the language as can functions, these features allow for functional programming to be used. Object-oriented programming is supported by inheritance and multiple dispatch. Functions can be generic and can also be overloaded, generics are further enhanced by the support for type classes. Operator overloading is also supported. Nim includes automatic garbage collection based on deferred reference counting with cycle detection. Andrew Binstock (editor-in-chief of Dr. Dobb's) says Nim (formerly known as Nimrod) "presents a most original design that straddles Pascal and Python and compiles to C code or JavaScript." """

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

    let tv = TextView.new(v.bounds.inset(100, 100))
    tv.resizingMask = "wh"
    tv.text = newFormattedText(textSample)
    tv.backgroundColor = newColor(0.5, 0, 0, 0.5)

    for a, b in tv.text.text.rangesOfSubstring("Nim"):
        tv.text.setFontInRange(a, b, systemFontOfSize(40))

    for a, b in tv.text.text.rangesOfSubstring("programming"):
        tv.text.setTextColorInRange(a, b, newColor(1, 0, 0))

    for a, b in tv.text.text.rangesOfSubstring("supported"):
        tv.text.setTextColorInRange(a, b, newColor(1, 1, 0))

    v.addSubview(tv)

method draw(v: TextView, r: Rect) =
    procCall v.View.draw(r)
    let c = currentContext()
    v.text.boundingSize = v.bounds.size
    c.drawText(newPoint(0, 0), v.text)

registerSample(TextSampleView, "Text")
