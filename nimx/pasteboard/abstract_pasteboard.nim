## Pasteboards
## Writing a string to pasteboard
## let p = pasteboardWithName(PboardGeneral)
## p.write(newPasteboardItem("Hello, world!"))
##
## Reading a string
## let myString = p.read().data

type
    Pasteboard* = ref object {.inheritable.}
        writeImpl*: proc(pb: Pasteboard, pi: varargs[PasteboardItem] ) {.nimcall.}
        readImpl*: proc(pb: Pasteboard, kind: string): PasteboardItem {.nimcall.}

    PasteboardItem* = ref object
        kind*: string
        data*: string

const PboardGeneral* = "__nimx.PboardGeneral"
const PboardFont* = "__nimx.PboardFont"
const PboardRuler* = "__nimx.PboardRuler"
const PboardFind* = "__nimx.PboardFind"
const PboardDrag* = "__nimx.PboardDrag"

const PboardKindString* = "string"

proc newPasteboardItem*(kind, data: string): PasteboardItem =
    result.new()
    result.kind = kind
    result.data = data

proc newPasteboardItem*(s: string): PasteboardItem = newPasteboardItem(PboardKindString, s)

proc write*(pb: Pasteboard, pi: varargs[PasteboardItem]) {.inline.} =
    if not pb.writeImpl.isNil: pb.writeImpl(pb, pi)
proc read*(pb: Pasteboard, kind: string): PasteboardItem {.inline.} =
    if not pb.readImpl.isNil: result = pb.readImpl(pb, kind)

proc writeString*(pb: Pasteboard, s: string) = pb.write(newPasteboardItem(s))
proc readString*(pb: Pasteboard): string =
    let pi = pb.read(PboardKindString)
    if not pi.isNil and pi.kind == PboardKindString:
        result = pi.data
