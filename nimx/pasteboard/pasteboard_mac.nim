import abstract_pasteboard
export abstract_pasteboard

{.pragma: appkit, header: "<AppKit/AppKit.h>", nodecl.}
{.pragma: appkitType, importc, appkit, final.}

{.passL: "-framework AppKit".}

{.hint[XDeclaredButNotUsed]: off.}

type NSObject {.appkitType.} = ptr object {.inheritable.}
type NSString {.appkitType.} = ptr object of NSObject
type NSPasteboard {.appkitType.} = ptr object of NSObject
type NSPasteboardItem {.appkitType.} = ptr object of NSObject
type NSData {.appkitType.} = ptr object of NSObject
type NSArrayAbstract {.appkit, importc: "NSArray", final.} = ptr object of NSObject
type NSMutableArrayAbstract {.appkit, importc: "NSMutableArray", final.} = ptr object of NSArrayAbstract
type NSArray[T] = ptr object of NSArrayAbstract
type NSMutableArray[T] = ptr object of NSArray[T]

proc description(o: NSObject): NSString {.importobjc, nodecl.}

proc arrayWithObjectsAndCount(objs: pointer, count: int): NSArrayAbstract {.importobjc: "NSArray arrayWithObjects", nodecl.}
proc newMutableArrayAbstract(): NSMutableArrayAbstract {.importobjc: "NSMutableArray new", nodecl.}
proc addObject(a: NSMutableArrayAbstract, o: NSObject) {.importobjc, nodecl.}
template newMutableArray[T](): NSMutableArray[T] = cast[NSMutableArray[T]](newMutableArrayAbstract())

template add[T](a: NSMutableArray[T], v: T) = cast[NSMutableArrayAbstract](a).addObject(v)

proc count(a: NSArrayAbstract): int {.importobjc, nodecl.}
proc objectAtIndex(a: NSArrayAbstract, i: int): NSObject {.importobjc, nodecl.}

template len(a: NSArray): int = NSArrayAbstract(a).count
template `[]`[T](a: NSArray[T], i: int): T = cast[T](NSArrayAbstract(a).objectAtIndex(i))

iterator items[T](a: NSArray[T]): T =
    let ln = a.len
    for i in 0 ..< ln: yield a[i]

proc clearContents(p: NSPasteboard) {.importobjc, nodecl.}
proc writeObjects(p: NSPasteboard, o: NSArray[NSPasteboardItem]) {.importobjc, nodecl.}
proc pasteboardItems(p: NSPasteboard): NSArray[NSPasteboardItem] {.importobjc, nodecl.}

proc length(p: NSData): int {.importobjc, nodecl.}
proc getBytes(self: NSData, buffer: pointer, length: int) {.importobjc, nodecl.}

proc arrayWithObjects[T](objs: varargs[T]): NSArray[T] {.inline.} = cast[NSArray[T]](arrayWithObjectsAndCount(unsafeAddr objs[0], objs.len))

proc types(pi: NSPasteboardItem): NSArray[NSString] {.importobjc: "types", nodecl.}
proc dataForType(pi: NSPasteboardItem, t: NSString): NSData {.importobjc: "dataForType", nodecl.}

proc dataWithBytes(bytes: cstring, length: int): NSData {.importobjc: "NSData dataWithBytes", nodecl.}

proc allocPasteboardItem(): NSPasteboardItem {.importobjc: "NSPasteboardItem alloc", nodecl.}

proc setDataForType(self: NSPasteboardItem, data: NSData, forType: NSString): bool {.importobjc: "setData", nodecl.}

proc native_init(o: NSObject): NSObject {.importobjc: "init", nodecl, discardable.}
proc native_retain(o: NSObject): NSObject {.importobjc: "retain", nodecl, discardable.}
proc release(o: NSObject) {.importobjc, nodecl.}

template init[T](v: T): T = cast[T](v.native_init())
template retain[T](v: T): T = cast[T](v.native_retain())

proc UTF8String(s: NSString): cstring {.importobjc, nodecl.}

proc isEqualToString(s1, s2: NSString): bool {.importobjc, nodecl.}

template `==`(s1, s2: NSString): bool = s1.isEqualToString(s2)

proc macPasteboardWithName(n: NSString): NSPasteboard {.importobjc: "NSPasteboard pasteboardWithName", nodecl.}
proc NSStringWithstring(n: cstring): NSString {.importobjc: "NSString stringWithUTF8String", nodecl.}
proc stringWithNSString(n: NSString): string = $n.UTF8String

#proc `$`(o: NSObject): string = stringWithNSString(o.description)

converter toNSString(s: string): NSString = NSStringWithstring(s)
converter nsstringtostring(s: NSString): string = stringWithNSString(s)

type MacPasteboard = ref object of Pasteboard
    p: NSPasteboard

proc finalizePboard(p: MacPasteboard) = p.p.release()

var NSGeneralPboard {.importc, appkit.} : NSString
var NSFontPboard {.importc, appkit.} : NSString
var NSRulerPboard {.importc, appkit.} : NSString
var NSFindPboard {.importc, appkit.} : NSString
var NSDragPboard {.importc, appkit.} : NSString

var NSPasteboardTypeString {.importc, appkit.} : NSString
var NSPasteboardTypePDF {.importc, appkit.} : NSString
var NSPasteboardTypeTIFF {.importc, appkit.} : NSString
var NSPasteboardTypePNG {.importc, appkit.} : NSString
var NSPasteboardTypeRTF {.importc, appkit.} : NSString
var NSPasteboardTypeRTFD {.importc, appkit.} : NSString
var NSPasteboardTypeHTML {.importc, appkit.} : NSString
var NSPasteboardTypeTabularText {.importc, appkit.} : NSString
var NSPasteboardTypeFont {.importc, appkit.} : NSString
var NSPasteboardTypeRuler {.importc, appkit.} : NSString
var NSPasteboardTypeColor {.importc, appkit.} : NSString
var NSPasteboardTypeSound {.importc, appkit.} : NSString
var NSPasteboardTypeMultipleTextSelection {.importc, appkit.} : NSString
var NSPasteboardTypeFindPanelSearchOptions {.importc, appkit.} : NSString

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

proc kindFromNative(k: NSString): string =
    if k == NSPasteboardTypeString: result = PboardKindString
    else: result = k

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem]) =
    let pb = MacPasteboard(p)
    pb.p.clearContents()
    let items = newMutableArray[NSPasteboardItem]()
    for pi in pi_ar:
        let npi = allocPasteboardItem().init()
        let data = dataWithBytes(addr pi.data[0], pi.data.len)
        discard npi.setDataForType(data, kindToNative(pi.kind))
        items.add(npi)
        npi.release()
    pb.p.writeObjects(items)
    items.release()

proc pbRead(p: Pasteboard, kind: string): PasteboardItem =
    let pb = MacPasteboard(p)
    let npi = pb.p.pasteboardItems[0]
    let typ = kindToNative(kind)
    result.new()
    result.kind = kindFromNative(typ)
    let d = npi.dataForType(typ)
    let ln = d.length
    result.data = newString(ln)
    d.getBytes(addr result.data[0], ln)

proc pasteboardWithName*(name: string): Pasteboard =
    var res: MacPasteboard
    res.new(finalizePboard)
    res.p = macPasteboardWithName(nativePboardName(name)).retain()
    res.writeImpl = pbWrite
    res.readImpl = pbRead
    result = res
