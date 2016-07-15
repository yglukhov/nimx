import abstract_pasteboard
export abstract_pasteboard
import winlean
{.pragma: winApi, stdcall, nodecl.}

type
    LPVOID = pointer
    UINT = cuint
    # HANDLE = pointer

type ClipboardFormat = enum
    CF_NONE = 0
    CF_TEXT = 1
    CF_UNICODETEXT = 13

type GlobalAllocFlag = enum
    GMEM_MOVEABLE = 0x0002

# BOOL WINAPI OpenClipboard(
#   _In_opt_ HWND hWndNewOwner
# );
proc openClipboard(hwnd: Handle = 0): WINBOOL {.winApi, importc: "OpenClipboard".}

# BOOL WINAPI CloseClipboard(void);
proc closeClipboard(): WINBOOL {.winApi, importc: "CloseClipboard".}

# LPVOID WINAPI GlobalLock(
#   _In_ HGLOBAL hMem
# );
proc globalLock(hMem: Handle): LPVOID {.winApi, importc: "GlobalLock".}

# BOOL WINAPI GlobalUnlock(
#   _In_ HGLOBAL hMem
# );
proc globalUnlock(hMem: Handle): WINBOOL {.winApi, importc: "GlobalUnlock".}

# HANDLE WINAPI GetClipboardData(
#   _In_ UINT uFormat
# );
proc getClipboardData(uFormat: UINT):Handle {.winApi, importc: "GetClipboardData".}

# HANDLE WINAPI SetClipboardData(
#   _In_     UINT   uFormat,
#   _In_opt_ HANDLE hMem
# );
proc setClipboardData(uFormat: UINT, hMem: Handle = 0): Handle {.winApi, importc: "SetClipboardData".}

# BOOL WINAPI EmptyClipboard(void);
proc emptyClipboard(): WINBOOL {.winApi, importc: "EmptyClipboard".}

# BOOL WINAPI IsClipboardFormatAvailable(
#   _In_ UINT format
# );
proc isClipboardFormatAvailable(format: UINT): WINBOOL {.winApi, importc: "IsClipboardFormatAvailable".}


# HGLOBAL WINAPI GlobalAlloc(
#   _In_ UINT   uFlags,
#   _In_ SIZE_T dwBytes
# );
proc globalAlloc(uFlags: UINT, dwBytes: int32): Handle {.winApi, importc: "GlobalAlloc".}

# HGLOBAL WINAPI GlobalFree(
#   _In_ HGLOBAL hMem
# );
proc globalFree(hMem: Handle): Handle {.winApi, importc: "GlobalFree".}

# void * memcpy ( void * destination, const void * source, size_t num );
proc c_memcpy(dest: pointer, sou: pointer, num: int32): pointer {.winApi, importc: "memcpy", header: "<string.h>" .}

proc c_strlen(a: cstring): cint {.
    importc: "strlen", header: "<string.h>", noSideEffect.}

proc `*`(b: SomeOrdinal): bool = result = b != 0

proc getClipboardFormatByString(str: string): ClipboardFormat =
    case str
    of "string": result = CF_TEXT
    of "unicodeString": result = CF_UNICODETEXT
    else: result = CF_NONE

type WindowsPasteboard = ref object of Pasteboard

proc getPasteboardItem(k: ClipboardFormat, lpstr: LPVOID): PasteboardItem =
    case k
    of CF_NONE: result = nil
    of CF_TEXT:
        var cstr = cast[cstring](lpstr)
        var str = $cstr
        result = newPasteboardItem("string", str)

    of CF_UNICODETEXT:
        var str = cast[WideCString](lpstr)
        result = newPasteboardItem("unicodeString", $str)

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem] )=
    if *openClipboard() and *emptyClipboard():

        for pi in pi_ar:
            let win_kind = getClipboardFormatByString(pi.kind)
            let cstr = pi.data.cstring
            let size = cstr.len.int32 + 1
            var allmem = globalAlloc(GMEM_MOVEABLE.UINT, size)
            discard c_memcpy(globalLock(allmem), cstr, size)
            discard globalUnlock(allmem)

            discard setClipboardData(win_kind.UINT, allmem)
            discard closeClipboard()

            discard globalFree(allmem)

    else:
        var error = getLastError()

proc pbRead(p: Pasteboard, kind: string): PasteboardItem =

    let win_kind = getClipboardFormatByString(kind)
    if *openClipboard() and *isClipboardFormatAvailable(win_kind.UINT):

        var hglb = getClipboardData(win_kind.UINT)
        var lpstr = globalLock(hglb)

        if not lpstr.isNil:
            result = getPasteboardItem(win_kind, lpstr)
        else:
            result = nil

        discard globalUnlock(hglb)
        discard closeClipboard()

    else:
        var error = getLastError()

proc pasteboardWithName*(name: string): Pasteboard=
    var res = new(WindowsPasteboard)
    res.writeImpl = pbWrite
    res.readImpl = pbRead

    result = res
