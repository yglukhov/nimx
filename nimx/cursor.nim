const appKit = defined(macosx) and not defined(ios)

when defined(js) or defined(emscripten) or defined(wasm):
    import jsbind
    when defined(emscripten) or defined(wasm):
        import jsbind/emscripten
elif appKit:
    import darwin/app_kit as apkt
elif not defined(nimxAvoidSDL):
    import sdl2
elif defined(linux):
    import x11/[xlib, cursorfont]
    import ./private/windows/x11_window
else:
    {.error.}


type
    CursorKind* = enum
        ckArrow
        ckText
        ckWait
        ckCrosshair
        ckWaitArrow
        ckSizeTRBL # Diagonal size top-right - bottom-left
        ckSizeTLBR # Diagonal size top-left - bottom-right
        ckSizeHorizontal
        ckSizeVertical
        ckSizeAll
        ckNotAllowed
        ckHand

    Cursor* = ref object
        when defined(js) or defined(emscripten) or defined(wasm):
            c: jsstring
        elif appKit:
            c: pointer
        elif not defined(nimxAvoidSdl):
            c: CursorPtr
        else:
            c: cuint

when defined(js) or defined(emscripten) or defined(wasm):
    proc cursorKindToCSSName(c: CursorKind): jsstring =
        case c
        of ckArrow: "auto"
        of ckText: "text"
        of ckWait: "wait"
        of ckCrosshair: "crosshair"
        of ckWaitArrow: "progress"
        of ckSizeTRBL: "nwse-resize"
        of ckSizeTLBR: "nesw-resize"
        of ckSizeHorizontal: "col-resize"
        of ckSizeVertical: "row-resize"
        of ckSizeAll: "all-scroll"
        of ckNotAllowed: "not-allowed"
        of ckHand: "pointer"
elif appKit:
    proc NSCursorOfKind(c: CursorKind): NSCursor =
        case c
        of ckArrow: arrowCursor()
        of ckText: IBeamCursor()
        of ckWait: arrowCursor()
        of ckCrosshair: crosshairCursor()
        of ckWaitArrow: arrowCursor()
        of ckSizeTRBL: arrowCursor()
        of ckSizeTLBR: arrowCursor()
        of ckSizeHorizontal: resizeLeftRightCursor()
        of ckSizeVertical: resizeUpDownCursor()
        of ckSizeAll: arrowCursor()
        of ckNotAllowed: operationNotAllowedCursor()
        of ckHand: pointingHandCursor()

    proc finalizeCursor(c: Cursor) =
        cast[NSCursor](c.c).release()
elif not defined(nimxAvoidSdl):
    proc cursorKindToSdl(c: CursorKind): SystemCursor =
        case c
        of ckArrow: SDL_SYSTEM_CURSOR_ARROW
        of ckText: SDL_SYSTEM_CURSOR_IBEAM
        of ckWait: SDL_SYSTEM_CURSOR_WAIT
        of ckCrosshair: SDL_SYSTEM_CURSOR_CROSSHAIR
        of ckWaitArrow: SDL_SYSTEM_CURSOR_WAITARROW
        of ckSizeTRBL: SDL_SYSTEM_CURSOR_SIZENWSE
        of ckSizeTLBR: SDL_SYSTEM_CURSOR_SIZENESW
        of ckSizeHorizontal: SDL_SYSTEM_CURSOR_SIZEWE
        of ckSizeVertical: SDL_SYSTEM_CURSOR_SIZENS
        of ckSizeAll: SDL_SYSTEM_CURSOR_SIZEALL
        of ckNotAllowed: SDL_SYSTEM_CURSOR_NO
        of ckHand: SDL_SYSTEM_CURSOR_HAND

    proc finalizeCursor(c: Cursor) =
        freeCursor(c.c)
elif defined(linux):
    proc cursorKindToX(c: CursorKind): cuint =
        case c
        of ckArrow: XC_arrow
        of ckText: XC_xterm
        of ckWait: XC_watch
        of ckCrosshair: XC_crosshair
        of ckWaitArrow: XC_arrow # ???
        of ckSizeTRBL: XC_arrow # ???
        of ckSizeTLBR: XC_arrow # ???
        of ckSizeHorizontal: XC_sb_h_double_arrow
        of ckSizeVertical: XC_sb_v_double_arrow
        of ckSizeAll: XC_sizing
        of ckNotAllowed: XC_cross_reverse
        of ckHand: XC_hand1

    proc finalizeCursor(c: Cursor) =
        discard

proc newCursor*(k: CursorKind): Cursor =
    when defined(js) or defined(emscripten) or defined(wasm):
        result.new()
        result.c = cursorKindToCSSName(k)
    else:
        result.new(finalizeCursor)
        when appKit:
            result.c = NSCursorOfKind(k).retain()
        elif not defined(nimxAvoidSdl):
            result.c = createSystemCursor(cursorKindToSdl(k))
        elif defined(linux):
            result.c = cursorKindToX(k)

var gCursor {.threadvar.}: Cursor
proc currentCursor*(): Cursor =
    if gCursor.isNil:
        gCursor = newCursor(ckArrow)
    result = gCursor

proc setCurrent*(c: Cursor) =
    gCursor = c
    when defined(js):
        let cs = c.c
        {.emit: """
        document.body.style.cursor = `cs`;
        """.}
    elif defined(emscripten) or defined(wasm):
        discard EM_ASM_INT("""
        document.body.style.cursor = UTF8ToString($0);
        """, cstring(c.c))
    elif appKit:
        cast[NSCursor](c.c).setCurrent()
    elif not defined(nimxAvoidSdl):
        setCursor(c.c)
    elif defined(linux):
        if allWindows.len > 0:
            let w = allWindows[0]
            let d = w.xdisplay
            let xw = w.xwindow

            let cur = XCreateFontCursor(d, c.c)
            discard XDefineCursor(d, xw, cur)
            discard XFreeCursor(d, cur)
