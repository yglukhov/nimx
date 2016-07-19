import typetraits

{.pragma: appkit, header: "<AppKit/AppKit.h>", nodecl.}
{.pragma: appkitType, importc, appkit, final.}

{.passL: "-framework AppKit".}

template enableObjC*() =
    ## Should be called in global scope of a nim file to ensure it will be
    ## translated to Objective-C
    proc dummyWithNoParticularMeaning() {.importobjc: "NSObject description".}

type NSObject* {.appkitType.} = ptr object {.inheritable.}
type NSString* {.appkitType.} = ptr object of NSObject
type NSPasteboard* {.appkitType.} = ptr object of NSObject
type NSPasteboardItem* {.appkitType.} = ptr object of NSObject
type NSData* {.appkitType.} = ptr object of NSObject
type NSArrayAbstract {.appkit, importc: "NSArray", final.} = ptr object of NSObject
type NSMutableArrayAbstract {.appkit, importc: "NSMutableArray", final.} = ptr object of NSArrayAbstract
type NSArray*[T] = ptr object of NSArrayAbstract
type NSMutableArray*[T] = ptr object of NSArray[T]

{.push stackTrace: off.}
proc alloc*(t: typedesc): t {.noInit.} =
    const typeName = typetraits.name(t)
    {.emit:"`result` = [" & typeName & " alloc];".}
{.pop.}

proc description*(o: NSObject): NSString {.importobjc, nodecl.}

proc arrayWithObjectsAndCount*(objs: pointer, count: int): NSArrayAbstract {.importobjc: "NSArray arrayWithObjects", nodecl.}
proc newMutableArrayAbstract*(): NSMutableArrayAbstract {.importobjc: "NSMutableArray new", nodecl.}
proc addObject*(a: NSMutableArrayAbstract, o: NSObject) {.importobjc, nodecl.}
template newMutableArray*[T](): NSMutableArray[T] = cast[NSMutableArray[T]](newMutableArrayAbstract())

template add*[T](a: NSMutableArray[T], v: T) = cast[NSMutableArrayAbstract](a).addObject(v)

proc count*(a: NSArrayAbstract): int {.importobjc, nodecl.}
proc objectAtIndex*(a: NSArrayAbstract, i: int): NSObject {.importobjc, nodecl.}

template len*(a: NSArray): int = NSArrayAbstract(a).count
template `[]`*[T](a: NSArray[T], i: int): T = cast[T](NSArrayAbstract(a).objectAtIndex(i))

iterator items*[T](a: NSArray[T]): T =
    let ln = a.len
    for i in 0 ..< ln: yield a[i]

proc clearContents*(p: NSPasteboard) {.importobjc, nodecl.}
proc writeObjects*(p: NSPasteboard, o: NSArray[NSPasteboardItem]) {.importobjc, nodecl.}
proc pasteboardItems*(p: NSPasteboard): NSArray[NSPasteboardItem] {.importobjc, nodecl.}
proc dataForType*(pi: NSPasteboard, t: NSString): NSData {.importobjc: "dataForType", nodecl.}

proc length*(p: NSData): int {.importobjc, nodecl.}
proc getBytes*(self: NSData, buffer: pointer, length: int) {.importobjc, nodecl.}

proc arrayWithObjects*[T](objs: varargs[T]): NSArray[T] {.inline.} = cast[NSArray[T]](arrayWithObjectsAndCount(unsafeAddr objs[0], objs.len))

proc types*(pi: NSPasteboardItem): NSArray[NSString] {.importobjc: "types", nodecl.}
proc dataForType*(pi: NSPasteboardItem, t: NSString): NSData {.importobjc: "dataForType", nodecl.}

proc dataWithBytes*(bytes: cstring, length: int): NSData {.importobjc: "NSData dataWithBytes", nodecl.}

proc setDataForType*(self: NSPasteboardItem, data: NSData, forType: NSString): bool {.importobjc: "setData", nodecl.}

proc appkit_native_init*(o: NSObject): NSObject {.importobjc: "init", nodecl, discardable.}
proc appkit_native_retain*(o: NSObject): NSObject {.importobjc: "retain", nodecl, discardable.}
proc release*(o: NSObject) {.importobjc, nodecl.}

template init*[T](v: T): T = cast[T](v.appkit_native_init())
template retain*[T](v: T): T = cast[T](v.appkit_native_retain())

proc UTF8String*(s: NSString): cstring {.importobjc, nodecl.}

proc isEqualToString*(s1, s2: NSString): bool {.importobjc, nodecl.}

template `==`*(s1, s2: NSString): bool = s1.isEqualToString(s2)

proc macPasteboardWithName*(n: NSString): NSPasteboard {.importobjc: "NSPasteboard pasteboardWithName", nodecl.}
proc NSStringWithstring*(n: cstring): NSString {.importobjc: "NSString stringWithUTF8String", nodecl.}
proc stringWithNSString*(n: NSString): string = $n.UTF8String

proc `$`*(o: NSObject): string = stringWithNSString(o.description)

converter toNSString*(s: string): NSString = NSStringWithstring(s)
converter nsstringtostring*(s: NSString): string = stringWithNSString(s)

var NSGeneralPboard* {.importc, appkit.} : NSString
var NSFontPboard* {.importc, appkit.} : NSString
var NSRulerPboard* {.importc, appkit.} : NSString
var NSFindPboard* {.importc, appkit.} : NSString
var NSDragPboard* {.importc, appkit.} : NSString

var NSPasteboardTypeString* {.importc, appkit.} : NSString
var NSPasteboardTypePDF* {.importc, appkit.} : NSString
var NSPasteboardTypeTIFF* {.importc, appkit.} : NSString
var NSPasteboardTypePNG* {.importc, appkit.} : NSString
var NSPasteboardTypeRTF* {.importc, appkit.} : NSString
var NSPasteboardTypeRTFD* {.importc, appkit.} : NSString
var NSPasteboardTypeHTML* {.importc, appkit.} : NSString
var NSPasteboardTypeTabularText* {.importc, appkit.} : NSString
var NSPasteboardTypeFont* {.importc, appkit.} : NSString
var NSPasteboardTypeRuler* {.importc, appkit.} : NSString
var NSPasteboardTypeColor* {.importc, appkit.} : NSString
var NSPasteboardTypeSound* {.importc, appkit.} : NSString
var NSPasteboardTypeMultipleTextSelection* {.importc, appkit.} : NSString
var NSPasteboardTypeFindPanelSearchOptions* {.importc, appkit.} : NSString
