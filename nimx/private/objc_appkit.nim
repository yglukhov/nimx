import typetraits

{.pragma: appkit, header: "<AppKit/AppKit.h>", nodecl.}
{.pragma: appkitType, importc, appkit, final.}

{.passL: "-framework AppKit".}

template enableObjC*() =
    ## Should be called in global scope of a nim file to ensure it will be
    ## translated to Objective-C
    block:
        {.hint[XDeclaredButNotUsed]: off.}
        proc dummyWithNoParticularMeaning() {.importobjc.}

type NSPoint* {.importc: "CGPoint", header: "<CoreGraphics/CoreGraphics.h>".} = object
    x*, y*: float32

type NSSize* {.importc: "CGSize", header: "<CoreGraphics/CoreGraphics.h>".} = object
    width*, height*: float32

type NSRect* {.importc: "CGRect", header: "<CoreGraphics/CoreGraphics.h>".} = object
    origin*: NSPoint
    size*: NSSize

type NSObject* {.appkitType.} = ptr object {.inheritable.}
type NSString* {.appkitType.} = ptr object of NSObject
type NSPasteboard* {.appkitType.} = ptr object of NSObject
type NSPasteboardItem* {.appkitType.} = ptr object of NSObject
type NSData* {.appkitType.} = ptr object of NSObject
type NSArrayAbstract {.appkit, importc: "NSArray", final.} = ptr object of NSObject
type NSMutableArrayAbstract {.appkit, importc: "NSMutableArray", final.} = ptr object of NSArrayAbstract
type NSArray*[T] = ptr object of NSArrayAbstract
type NSMutableArray*[T] = ptr object of NSArray[T]

type NSEvent* {.appkitType.} = ptr object of NSObject
type NSView* {.appkitType.} = ptr object of NSObject

type NSEventKind* = enum
    NSLeftMouseDown      = 1,
    NSLeftMouseUp        = 2,
    NSRightMouseDown     = 3,
    NSRightMouseUp       = 4,
    NSMouseMoved         = 5,
    NSLeftMouseDragged   = 6,
    NSRightMouseDragged  = 7,
    NSMouseEntered       = 8,
    NSMouseExited        = 9,
    NSKeyDown            = 10,
    NSKeyUp              = 11,
    NSFlagsChanged       = 12,
    NSAppKitDefined      = 13,
    NSSystemDefined      = 14,
    NSApplicationDefined = 15,
    NSPeriodic           = 16,
    NSCursorUpdate       = 17,
    NSEventTypeRotate    = 18,
    NSEventTypeBeginGesture = 19,
    NSEventTypeEndGesture   = 20
    NSScrollWheel        = 22,
    NSTabletPoint        = 23,
    NSTabletProximity    = 24,
    NSOtherMouseDown     = 25,
    NSOtherMouseUp       = 26,
    NSOtherMouseDragged  = 27
    NSEventTypeGesture   = 29,
    NSEventTypeMagnify   = 30,
    NSEventTypeSwipe     = 31,
    NSEventTypeSmartMagnify = 32,
    NSEventTypeQuickLook   = 33
    NSEventTypePressure   = 34

proc kind*(e: NSEvent): NSEventKind {.importobjc: "type".}
proc locationInWindow*(e: NSEvent): NSPoint {.importobjc.}

proc convertPointFromView*(v: NSView, point: NSPoint, fromView: NSView): NSPoint {.importobjc: "convertPoint".}
proc convertPointToView*(v: NSView, point: NSPoint, toView: NSView): NSPoint {.importobjc: "convertPoint".}
proc frame*(v: NSView): NSRect {.importobjc.}
proc bounds*(v: NSView): NSRect {.importobjc.}

proc NSLog*(fmt: NSString) {.appkit, varargs.}

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
proc NSStringWithString*(n: cstring): NSString {.importobjc: "NSString stringWithUTF8String", nodecl.}
proc stringWithNSString*(n: NSString): string = $n.UTF8String

proc `$`*(o: NSObject): string = stringWithNSString(o.description)

converter toNSString*(s: string): NSString = NSStringWithString(s)
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


type NSCursor* {.appkitType.} = ptr object of NSObject
proc arrowCursor*(): NSCursor {.importobjc: "NSCursor arrowCursor", nodecl.}
proc IBeamCursor*(): NSCursor {.importobjc: "NSCursor IBeamCursor", nodecl.}
proc crosshairCursor*(): NSCursor {.importobjc: "NSCursor crosshairCursor", nodecl.}
proc closedHandCursor*(): NSCursor {.importobjc: "NSCursor closedHandCursor", nodecl.}
proc pointingHandCursor*(): NSCursor {.importobjc: "NSCursor pointingHandCursor", nodecl.}
proc resizeLeftCursor*(): NSCursor {.importobjc: "NSCursor resizeLeftCursor", nodecl.}
proc resizeRightCursor*(): NSCursor {.importobjc: "NSCursor resizeRightCursor", nodecl.}
proc resizeLeftRightCursor*(): NSCursor {.importobjc: "NSCursor resizeLeftRightCursor", nodecl.}
proc resizeUpCursor*(): NSCursor {.importobjc: "NSCursor resizeUpCursor", nodecl.}
proc resizeDownCursor*(): NSCursor {.importobjc: "NSCursor resizeDownCursor", nodecl.}
proc resizeUpDownCursor*(): NSCursor {.importobjc: "NSCursor resizeUpDownCursor", nodecl.}
proc disappearingItemCursor*(): NSCursor {.importobjc: "NSCursor disappearingItemCursor", nodecl.}
proc IBeamCursorForVerticalLayout*(): NSCursor {.importobjc: "NSCursor IBeamCursorForVerticalLayout", nodecl.}
proc operationNotAllowedCursor*(): NSCursor {.importobjc: "NSCursor operationNotAllowedCursor", nodecl.}
proc dragLinkCursor*(): NSCursor {.importobjc: "NSCursor dragLinkCursor", nodecl.}
proc dragCopyCursor*(): NSCursor {.importobjc: "NSCursor dragCopyCursor", nodecl.}
proc contextualMenuCursor*(): NSCursor {.importobjc: "NSCursor contextualMenuCursor", nodecl.}

proc setCurrent*(c: NSCursor) {.importobjc: "set", nodecl.}
