when defined(js) or defined(emscripten):
    import jsbind
    when defined(emscripten):
        import emscripten
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
    else:
        setCursor(c.c)
