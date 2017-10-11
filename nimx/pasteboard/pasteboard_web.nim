import abstract_pasteboard
export abstract_pasteboard
import pasteboard_item

import strutils
import jsbind

type WebPasteboard = ref object of Pasteboard

const webCode = """
var textArea = document.createElement("textarea");
textArea.style.position = 'absolute';
textArea.style.top = "-200px";
textArea.style.left = "-200px";
textArea.style.width = '2px';
textArea.style.height = '2px';
textArea.value = $1;
document.body.appendChild(textArea);
textArea.select();
try {
    var successful = document.execCommand('copy');
} catch (err) {
}
document.body.removeChild(textArea);
"""

when defined(js):
    const jsCode = webCode.format("`cdata`")
else:
    import jsbind.emscripten
    const emCode = webCode.format("UTF8ToString($0)")

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem]) =
    let item = pi_ar[0]
    if item.kind == PboardKindString:
        when defined(js):
            let cdata: cstring = item.data
            {.emit: jsCode.}
        else:
            discard EM_ASM_INT(emCode, cstring(item.data))

proc pbRead(p: Pasteboard, kind: string): PasteboardItem = discard

proc pasteboardWithName*(name: string): Pasteboard =
    var res: WebPasteboard
    res.new()
    res.writeImpl = pbWrite
    res.readImpl = pbRead
    result = res
