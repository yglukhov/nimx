import abstract_pasteboard
export abstract_pasteboard

import darwin.app_kit

type MacPasteboard = ref object of Pasteboard
    p: NSPasteboard

proc finalizePboard(p: MacPasteboard) = p.p.release()

proc nativePboardName(n: string): NSString =
    case n
    of PboardGeneral: result = NSGeneralPboard
    of PboardFont: result = NSFontPboard
    of PboardRuler: result = NSRulerPboard
    of PboardFind: result = NSFindPboard
    of PboardDrag: result = NSDragPboard
    else: result = n

proc kindToNative(k: string): NSString =
    case k
    of PboardKindString: result = NSPasteboardTypeString
    else: result = k

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem]) =
    let pb = MacPasteboard(p)
    pb.p.clearContents()
    let items = newMutableArray[NSPasteboardItem]()
    for pi in pi_ar:
        let npi = NSPasteboardItem.alloc().init()
        let data = dataWithBytes(addr pi.data[0], pi.data.len)
        discard npi.setDataForType(data, kindToNative(pi.kind))
        items.add(npi)
        npi.release()
    pb.p.writeObjects(items)
    items.release()

proc pbRead(p: Pasteboard, kind: string): PasteboardItem =
    let pb = MacPasteboard(p)
    let typ = kindToNative(kind)
    let d = pb.p.dataForType(typ)
    if not d.isNil:
        result.new()
        result.kind = kind
        let ln = d.length
        result.data = newString(ln)
        d.getBytes(addr result.data[0], ln)

proc pasteboardWithName*(name: string): Pasteboard =
    var res: MacPasteboard
    res.new(finalizePboard)
    res.p = NSPasteboard.withName(nativePboardName(name)).retain()
    res.writeImpl = pbWrite
    res.readImpl = pbRead
    result = res
