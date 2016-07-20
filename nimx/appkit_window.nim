import abstract_window
import system_logger
import view
import opengl
import context
import event
import unicode, times
import app
import linkage_details
import portable_gl
import screen
import nimx.private.objc_appkit

enableObjC()

{.emit: """
#include <AppKit/AppKit.h>

@interface __NimxView__ : NSOpenGLView {
    @public
    void* w;
}
@end

@interface __NimxAppDelegate__ : NSObject {
    @public
    void* d;
}
@end

@interface __NimxWindow__ : NSWindow {
    @public
    void* w;
}
@end

""".}

type AppkitWindow* = ref object of Window
    nativeWindow: pointer # __NimxWindow__
    mNativeView: pointer # __NimxView__
    renderingContext: GraphicsContext
    inLiveResize: bool

type AppDelegate = ref object
    init: proc()

var animationEnabled = 0

method enableAnimation*(w: AppkitWindow, flag: bool) =
    discard

proc initCommon(w: AppkitWindow, r: view.Rect) =
    procCall init(w.Window, r)

    var nativeWnd, nativeView: pointer
    let x = r.x
    let y = r.y
    let width = r.width
    let height = r.height

    {.emit: """
    NSRect frame = NSMakeRect(`x`, `y`, `width`, `height`);
    NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
    __NimxWindow__* win = [[__NimxWindow__ alloc] initWithContentRect: frame
					styleMask: styleMask
					backing: NSBackingStoreBuffered
					defer: YES];
    win->w = `w`;
    __NimxView__* glView = [[__NimxView__ alloc] initWithFrame: [win frame]
                colorBits:16 depthBits:16 fullscreen: FALSE];
    if (glView)
    {
        glView->w = `w`;
        [glView setWantsBestResolutionOpenGLSurface:YES];
        [win setContentView:glView];
        [win makeKeyAndOrderFront:nil];
        [glView release];
    }
    `nativeWnd` = win;
    `nativeView` = glView;
    """.}
    w.nativeWindow = nativeWnd
    w.mNativeView = nativeView

    w.renderingContext = newGraphicsContext()
    mainApplication().addWindow(w)
    w.onResize(r.size)

template nativeView(w: AppkitWindow): NSView = cast[NSView](w.mNativeView)

proc initFullscreen*(w: AppkitWindow) =
    w.initCommon(newRect(0, 0, 800, 600))

method init*(w: AppkitWindow, r: view.Rect) =
    w.initCommon(r)

proc newFullscreenAppkitWindow(): AppkitWindow =
    result.new()
    result.initFullscreen()

proc newAppkitWindow(r: view.Rect): AppkitWindow =
    result.new()
    result.init(r)

newWindow = proc(r: view.Rect): Window =
    result = newAppkitWindow(r)

newFullscreenWindow = proc(): Window =
    result = newFullscreenAppkitWindow()

method drawWindow(w: AppkitWindow) =
    if w.inLiveResize:
        let s = w.nativeView.bounds.size
        w.onResize(newSize(s.width, s.height))

    let c = w.renderingContext
    c.gl.clear(c.gl.COLOR_BUFFER_BIT or c.gl.STENCIL_BUFFER_BIT or c.gl.DEPTH_BUFFER_BIT)
    let oldContext = setCurrentContext(c)

    c.withTransform ortho(0, w.frame.width, w.frame.height, 0, -1, 1):
        procCall w.Window.drawWindow()
    let nv = w.nativeView
    {.emit: "[[`nv` openGLContext] flushBuffer];".}

proc markNeedsDisplayAux(w: AppkitWindow) =
    let nv = w.nativeView
    {.emit: "[`nv` setNeedsDisplay: YES];".}

method markNeedsDisplay*(w: AppkitWindow) = w.markNeedsDisplayAux()

#[
proc windowFromSDLEvent[T](event: T): EmscriptenWindow =
    let sdlWndId = event.windowID
    let sdlWin = getWindowFromID(sdlWndId)
    if sdlWin != nil:
        result = cast[EmscriptenWindow](sdlWin.getData("__nimx_wnd"))

proc positionFromSDLEvent[T](event: T): auto =
    newPoint(event.x.Coord, event.y.Coord)

template buttonStateFromSDLState(s: KeyState): ButtonState =
    if s == KeyPressed:
        bsDown
    else:
        bsUp

var activeTouches = 0

proc eventWithSDLEvent(event: ptr sdl2.Event): Event =
    case event.kind:
        of FingerMotion, FingerDown, FingerUp:
            let bs = case event.kind
                of FingerDown: bsDown
                of FingerUp: bsUp
                else: bsUnknown
            let touchEv = cast[TouchFingerEventPtr](event)
            result = newTouchEvent(
                                   newPoint(touchEv.x * defaultWindow.frame.width, touchEv.y * defaultWindow.frame.height),
                                   bs, int(touchEv.fingerID), touchEv.timestamp
                                   )
            if bs == bsDown:
                inc activeTouches
                if activeTouches == 1:
                    result.pointerId = 0
            elif bs == bsUp:
                dec activeTouches
            #logi "EVENT: ", result.position, " ", result.buttonState
            result.window = defaultWindow
            result.kind = etUnknown # TODO: Fix apple trackpad problem

        of WindowEvent:
            let wndEv = cast[WindowEventPtr](event)
            let wnd = windowFromSDLEvent(wndEv)
            case wndEv.event:
                of WindowEvent_Resized:
                    result = newEvent(etWindowResized)
                    result.window = wnd
                    result.position.x = wndEv.data1.Coord
                    result.position.y = wndEv.data2.Coord
                else:
                    discard

        of MouseButtonDown, MouseButtonUp:
            when not defined(ios) and not defined(android):
                if event.kind == MouseButtonDown:
                    discard sdl2.captureMouse(True32)
                else:
                    discard sdl2.captureMouse(False32)

            let mouseEv = cast[MouseButtonEventPtr](event)
            if mouseEv.which != SDL_TOUCH_MOUSEID:
                let wnd = windowFromSDLEvent(mouseEv)
                let state = buttonStateFromSDLState(mouseEv.state.KeyState)
                let button = case mouseEv.button:
                    of sdl2.BUTTON_LEFT: VirtualKey.MouseButtonPrimary
                    of sdl2.BUTTON_MIDDLE: VirtualKey.MouseButtonMiddle
                    of sdl2.BUTTON_RIGHT: VirtualKey.MouseButtonSecondary
                    else: VirtualKey.Unknown
                let pos = positionFromSDLEvent(mouseEv)
                result = newMouseButtonEvent(pos, button, state, mouseEv.timestamp)
                result.window = wnd

        of MouseMotion:
            let mouseEv = cast[MouseMotionEventPtr](event)
            if mouseEv.which != SDL_TOUCH_MOUSEID:
                #logi("which: " & $mouseEv.which)
                let wnd = windowFromSDLEvent(mouseEv)
                if wnd != nil:
                    let pos = positionFromSDLEvent(mouseEv)
                    result = newMouseMoveEvent(pos, mouseEv.timestamp)
                    result.window = wnd

        of MouseWheel:
            let mouseEv = cast[MouseWheelEventPtr](event)
            let wnd = windowFromSDLEvent(mouseEv)
            if wnd != nil:
                var x, y: cint
                getMouseState(x, y)
                let pos = newPoint(x.Coord, y.Coord)
                result = newEvent(etScroll, pos)
                result.window = wnd
                result.offset.x = mouseEv.x.Coord
                result.offset.y = mouseEv.y.Coord

        of KeyDown, KeyUp:
            let keyEv = cast[KeyboardEventPtr](event)
            let wnd = windowFromSDLEvent(keyEv)
            result = newKeyboardEvent(virtualKeyFromNative(keyEv.keysym.sym), buttonStateFromSDLState(keyEv.state.KeyState), keyEv.repeat)
            result.rune = keyEv.keysym.unicode.Rune
            result.window = wnd

        of TextInput:
            let textEv = cast[TextInputEventPtr](event)
            result = newEvent(etTextInput)
            result.window = windowFromSDLEvent(textEv)
            result.text = $cast[cstring](addr textEv.text)

        of TextEditing:
            let textEv = cast[TextEditingEventPtr](event)
            result = newEvent(etTextInput)
            result.window = windowFromSDLEvent(textEv)
            result.text = $cast[cstring](addr textEv.text)

        of AppWillEnterBackground:
            result = newEvent(etAppWillEnterBackground)

        of AppWillEnterForeground:
            result = newEvent(etAppWillEnterForeground)

        else:
            #echo "Unknown event: ", event.kind
            discard

proc handleEvent(event: ptr sdl2.Event): Bool32 =
    if event.kind == UserEvent5:
        let evt = cast[UserEventPtr](event)
        let p = cast[proc (data: pointer) {.cdecl.}](evt.data1)
        if p.isNil:
            logi "WARNING: UserEvent5 with nil proc"
        else:
            p(evt.data2)
    else:
        # This branch should never execute on a foreign thread!!!
        var e = eventWithSDLEvent(event)
        if (e.kind != etUnknown):
            discard mainApplication().handleEvent(e)
    result = True32
]#
method onResize*(w: AppkitWindow, newSize: Size) =
    let sf = screenScaleFactor()
    glViewport(0, 0, GLSizei(newSize.width * sf), GLsizei(newSize.height * sf))
    procCall w.Window.onResize(newSize)
#[
# Framerate limiter
let MAXFRAMERATE: uint32 = 20 # milli seconds
var frametime: uint32

proc limitFramerate() =
    var now = getTicks()
    if frametime > now:
        delay(frametime - now)
    frametime = frametime + MAXFRAMERATE

proc animateAndDraw() =
    when not defined ios:
        mainApplication().runAnimations()
        mainApplication().drawWindows()
    else:
        if animationEnabled == 0:
            mainApplication().runAnimations()
            mainApplication().drawWindows()

proc handleCallbackEvent(evt: UserEventPtr) =
    let p = cast[proc (data: pointer) {.cdecl.}](evt.data1)
    if p.isNil:
        logi "WARNING: UserEvent5 with nil proc"
    else:
        p(evt.data2)

proc nextEvent(evt: var sdl2.Event) =
    when defined(ios):
        if waitEvent(evt):
            discard handleEvent(addr evt)
    else:
        var doPoll = false
        if animationEnabled > 0:
            doPoll = true
        elif waitEvent(evt):
            discard handleEvent(addr evt)
            doPoll = evt.kind != QuitEvent
        # TODO: This should be researched more carefully.
        # During animations we need to process more than one event
        if doPoll:
            while pollEvent(evt):
                discard handleEvent(addr evt)
                if evt.kind == QuitEvent:
                    break

    animateAndDraw()

method startTextInput*(w: EmscriptenWindow, r: Rect) =
    startTextInput()

method stopTextInput*(w: EmscriptenWindow) =
    stopTextInput()
]#

proc runUntilQuit(d: AppDelegate) =
    {.emit:"""
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	id app = [NSApplication sharedApplication];
    __NimxAppDelegate__* appDelegate = [[__NimxAppDelegate__ alloc] init];
    appDelegate->d = `d`;
	[app setDelegate: appDelegate];
	[app run];
	[app setDelegate: nil];
	[appDelegate release];
	SInt32 result = 0;
	[pool drain];
    """.}

    # # Initialize fist dummy event. The kind should be any unused kind.
    # var evt = sdl2.Event(kind: UserEvent1)
    # #setEventFilter(eventFilter, nil)
    # animateAndDraw()

    # # Main loop
    # while true:
    #     nextEvent(evt)
    #     if evt.kind == QuitEvent:
    #         break

    # discard quit(evt)

template runApplication*(body: typed): stmt =
    try:
        let appDelegate = AppDelegate.new()
        appDelegate.init = proc() =
            body
        runUntilQuit(appDelegate)
    except:
        logi "Exception caught: ", getCurrentExceptionMsg()
        logi getCurrentException().getStackTrace()
        quit 1


proc appDidFinishLaunching(d: AppDelegate) =
    if not d.init.isNil:
        d.init()
        d.init = nil

proc pointFromNSEvent(w: AppkitWindow, e: NSEvent): Point =
    let v = w.nativeView
    var pt = v.convertPointFromView(e.locationInWindow, nil)
    result.x = pt.x
    result.y = v.frame.size.height - pt.y

proc eventWithNSEvent(w: AppkitWindow, e: NSEvent): Event =
    case e.kind
    of NSLeftMouseDown:
        result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonPrimary, bsDown)
    of NSLeftMouseUp:
        result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonPrimary, bsUp)
    of NSLeftMouseDragged:
        result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonPrimary, bsUnknown)
    of NSRightMouseDown:
        result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonSecondary, bsDown)
    of NSRightMouseUp:
        result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonSecondary, bsUp)
    of NSRightMouseDragged:
        result = newMouseButtonEvent(w.pointFromNSEvent(e), VirtualKey.MouseButtonSecondary, bsUnknown)
    else:
        discard

    result.window = w

proc sendEvent(w: AppkitWindow, e: NSEvent) =
    var evt = w.eventWithNSEvent(e)
    discard mainApplication().handleEvent(evt)

proc viewWillStartLiveResize(w: AppkitWindow) =
    w.inLiveResize = true

proc viewDidEndLiveResize(w: AppkitWindow) =
    w.inLiveResize = false
    let s = w.nativeView.bounds.size
    w.onResize(newSize(s.width, s.height))

{.emit: """
@implementation __NimxView__

/*
 * Create a pixel format and possible switch to full screen mode
 */
NSOpenGLPixelFormat* createPixelFormat(NSRect frame, int colorBits, int depthBits) {
   NSOpenGLPixelFormatAttribute pixelAttribs[ 16 ];
   int pixNum = 0;
   NSDictionary *fullScreenMode;

   pixelAttribs[pixNum++] = NSOpenGLPFADoubleBuffer;
   pixelAttribs[pixNum++] = NSOpenGLPFAAccelerated;
   pixelAttribs[pixNum++] = NSOpenGLPFAColorSize;
   pixelAttribs[pixNum++] = colorBits;
   pixelAttribs[pixNum++] = NSOpenGLPFADepthSize;
   pixelAttribs[pixNum++] = depthBits;
/*
   if( runningFullScreen )  // Do this before getting the pixel format
   {
      pixelAttribs[pixNum++] = NSOpenGLPFAFullScreen;
      fullScreenMode = (NSDictionary *) CGDisplayBestModeForParameters(
                                           kCGDirectMainDisplay,
                                           colorBits, frame.size.width,
                                           frame.size.height, NULL );
      CGDisplayCapture( kCGDirectMainDisplay );
      CGDisplayHideCursor( kCGDirectMainDisplay );
      CGDisplaySwitchToMode( kCGDirectMainDisplay,
                             (CFDictionaryRef) fullScreenMode );
   }*/
   pixelAttribs[pixNum] = 0;
   return [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelAttribs];
}

- (id) initWithFrame:(NSRect)frame colorBits:(int)numColorBits
       depthBits:(int)numDepthBits fullscreen:(BOOL)runFullScreen
{
    NSOpenGLPixelFormat *pixelFormat;

    pixelFormat = createPixelFormat(frame, numColorBits, numDepthBits);
    if( pixelFormat != nil )
    {
        self = [ super initWithFrame:frame pixelFormat:pixelFormat ];
        [ pixelFormat release ];
        if( self )
        {
            [ [ self openGLContext ] makeCurrentContext ];
            [ self reshape ];
        }
    }
    else
        self = nil;

    return self;
}

- (void)drawRect:(NSRect)r { `drawWindow`(w); }

- (void)viewWillStartLiveResize { `viewWillStartLiveResize`(w); }
- (void)viewDidEndLiveResize { `viewDidEndLiveResize`(w); }

@end

@implementation __NimxWindow__
- (BOOL) canBecomeKeyWindow
{
	return YES;
}

- (void) sendEvent:(NSEvent *)theEvent
{
	[super sendEvent: theEvent];
    `sendEvent`(w, theEvent);
}
@end

@implementation __NimxAppDelegate__
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification { `appDidFinishLaunching`(d); }
@end

""".}