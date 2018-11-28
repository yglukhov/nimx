const appKit = defined(macosx) and not defined(ios)

when defined(js) or defined(emscripten):
    import jsbind
    when defined(emscripten):
        import jsbind/emscripten
elif appKit:
    import darwin/app_kit as apkt
else:
    import sdl2

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
        when defined(js) or defined(emscripten):
            c: jsstring
        elif appKit:
            c: pointer
        else:
            c: CursorPtr

when defined(js) or defined(emscripten):
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

    proc finalizeCursor(c: Cursor) = discard
        # if c.isNil: return
        # cast[NSCursor](c.c).release()
else:
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

proc newCursor*(k: CursorKind): Cursor =
    when defined(js) or defined(emscripten):
        result.new()
        result.c = cursorKindToCSSName(k)
    else:
        result.new(finalizeCursor)
        when appKit:
            result.c = NSCursorOfKind(k)#.retain()
        else:
            result.c = createSystemCursor(cursorKindToSdl(k))

var gCursor: Cursor
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
    elif defined(emscripten):
        discard EM_ASM_INT("""
        document.body.style.cursor = Pointer_stringify($0);
        """, cstring(c.c))
    elif appKit:
        cast[NSCursor](c.c).setCurrent()
    else:
        setCursor(c.c)
