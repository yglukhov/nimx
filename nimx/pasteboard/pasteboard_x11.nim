import abstract_pasteboard
export abstract_pasteboard
import os, times
import xlib, x, xatom, xutil
import nimx.app, nimx.private.windows.sdl_window
import sdl2

type X11Pasteboard = ref object of Pasteboard
const XINT_MAX = 32767

type WMinfoX11 = object 
    version*: SDL_Version
    subsystem*: SysWMType
    display*: pointer
    window*: culong

proc getTextFormat(d: PDisplay): TAtom =
    when defined(X_HAVE_UTF8_STRING):
        result = XInternAtom(d, "UTF8_STRING", 0)
    else:
        result = XA_STRING

const x11ClipboardSelection = "CLIPBOARD"

proc nimxCutBuffer(display: PDisplay): TAtom = 
    result = XInternAtom(display, "SDL_CUTBUFFER", 0)

template displayConnection(body: untyped)=
    var keyWnd = mainApplication().keyWindow()
    if keyWnd.isNil: return

    var winInfo: WMinfoX11
    getVersion(winInfo.version)
    
    if keyWnd.SdlWindow.getSDLWindow().getWMInfo(cast[ptr WMInfo](addr winInfo)[]) == False32 and winInfo.display.isNil:
        raise newException(Exception, "Can't retreive SDLWindow info")

    var display{.inject, used.} = cast[PDisplay](winInfo.display)
    var window{.inject, used.} = cast[TWindow](winInfo.window)
    
    assert(not display.isNil)
    var rootWindow{.inject, used.} = DefaultRootWindow(display)

    body

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem])=
    displayConnection:
        var format = getTextFormat(display)
        let clipboard = XInternAtom(display, x11ClipboardSelection, 0)
        let cutBuffer = nimxCutBuffer(display)
        for pi in pi_ar:
            discard XChangeProperty(display, rootWindow, cutBuffer, format, 8.cint, PropModeReplace, pi.data.Pcuchar, pi.data.len.cint)
            if clipboard != None and XGetSelectionOwner(display, clipboard) != window:
                discard XSetSelectionOwner(display, clipboard, window, CurrentTime)
            if XGetSelectionOwner(display, XA_PRIMARY) != window:
                discard XSetSelectionOwner(display, XA_PRIMARY, window, CurrentTime)

proc pbRead(p: Pasteboard, kind: string): PasteboardItem =
    displayConnection:
        var format = getTextFormat(display)
        let clipboard = XInternAtom(display, x11ClipboardSelection, 0)
        let cutBuffer = nimxCutBuffer(display)
        var selection: TAtom
        var owner = XGetSelectionOwner(display, clipboard)

        if owner == None:
            owner = rootWindow
            selection = XA_CUT_BUFFER0
            format = XA_STRING

        elif owner == window:
            owner = rootWindow
            selection = cutBuffer
        else:
            owner = window
            selection = XInternAtom(display, "SDL_SELECTION", 0)
            discard XConvertSelection(display, clipboard, format, selection, owner, CurrentTime)
            
        var selType: TAtom
        var selFormat: cint
        var bytes: culong = 0
        var overflow: culong = 0
        var src : cstring

        if XGetWindowProperty(display, owner, selection, 0.clong, (XINT_MAX div 4).clong, 0.TBool, format, (addr selType).PAtom,
            (addr selFormat).PCint, (addr bytes).Pculong, (addr overflow).Pculong, cast[PPcuchar](addr src)) == Success:
            if selType == format:
                var data = $src
                result = newPasteboardItem(PboardKindString, data)
                discard XFree(src)

proc pasteboardWithName*(name: string): Pasteboard=
    var res = new(X11Pasteboard)
    res.writeImpl = pbWrite
    res.readImpl = pbRead

    result = res
