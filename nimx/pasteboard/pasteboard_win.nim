import abstract_pasteboard
export abstract_pasteboard
import winlean
import os

{.pragma: user32, stdcall, dynlib: "user32" .}
{.pragma: kernel32, stdcall, dynlib: "kernel32" .}

const UniSuffix = when useWinUnicode: "W" else: "A"

type
    LPVOID = pointer
    UINT = cuint

const
    CF_UNICODETEXT: UINT = 13
    GMEM_MOVEABLE: UINT = 0x0002
    MAX_FORMAT_NAME_LEN = 512'i32

# BOOL WINAPI OpenClipboard(
#   _In_opt_ HWND hWndNewOwner
# );
proc openClipboard(hwnd: Handle = 0): WINBOOL {.user32, importc: "OpenClipboard".}

# BOOL WINAPI CloseClipboard(void);
proc closeClipboard(): WINBOOL {.user32, importc: "CloseClipboard".}

# HANDLE WINAPI GetClipboardData(
#   _In_ UINT uFormat
# );
proc getClipboardData(uFormat: UINT):Handle {.user32, importc: "GetClipboardData".}

# HANDLE WINAPI SetClipboardData(
#   _In_     UINT   uFormat,
#   _In_opt_ HANDLE hMem
# );
proc setClipboardData(uFormat: UINT, hMem: Handle = 0): Handle {.user32, importc: "SetClipboardData".}

# BOOL WINAPI EmptyClipboard(void);
proc emptyClipboard(): WINBOOL {.user32, importc: "EmptyClipboard".}

# BOOL WINAPI IsClipboardFormatAvailable(
#   _In_ UINT format
# );
proc isClipboardFormatAvailable(format: UINT): WINBOOL {.user32, importc: "IsClipboardFormatAvailable".}

# UINT WINAPI RegisterClipboardFormat(
#   _In_ LPCTSTR lpszFormat
# );
proc registerClipboardFormat(lpszFormat: pointer): UINT {.user32, importc: "RegisterClipboardFormat" & UniSuffix.}

# int WINAPI GetClipboardFormatName(
#   _In_  UINT   format,
#   _Out_ LPTSTR lpszFormatName,
#   _In_  int    cchMaxCount
# );
proc getClipboardFormatName(uFormat: UINT, lpszFormatName: pointer, cchMaxCount: int32): int32 {.user32, importc: "GetClipboardFormatName" & UniSuffix.}

# HGLOBAL WINAPI GlobalAlloc(
#   _In_ UINT   uFlags,
#   _In_ SIZE_T dwBytes
# );
proc globalAlloc(uFlags: UINT, dwBytes: csize): Handle {.kernel32, importc: "GlobalAlloc".}

# HGLOBAL WINAPI GlobalFree(
#   _In_ HGLOBAL hMem
# );
proc globalFree(hMem: Handle): Handle {.kernel32, importc: "GlobalFree".}

# SIZE_T WINAPI GlobalSize(
#   _In_ HGLOBAL hMem
# );
proc globalSize(hMem: Handle): csize {.kernel32, importc: "GlobalSize".}

# LPVOID WINAPI GlobalLock(
#   _In_ HGLOBAL hMem
# );
proc globalLock(hMem: Handle): LPVOID {.kernel32, importc: "GlobalLock".}

# BOOL WINAPI GlobalUnlock(
#   _In_ HGLOBAL hMem
# );
proc globalUnlock(hMem: Handle): WINBOOL {.kernel32, importc: "GlobalUnlock".}

proc `*`(b: SomeOrdinal): bool = result = b != 0

proc error()=
    raiseOSError(getLastError().OSErrorCode)

proc getClipboardFormatByString(str: string): UINT =
    case str
    of PboardKindString: result = CF_UNICODETEXT
    else:
        var uFormat = registerClipboardFormat(str.cstring)
        if not *uFormat: error()
        result = uFormat

type WindowsPasteboard = ref object of Pasteboard

proc getPasteboardItem(k: UINT, lpstr: LPVOID, lpdat: Handle): PasteboardItem =
    var lpdatLen = globalSize(lpdat)
    if not *lpdatLen: error()
    var str = newWideCString("",lpdatLen)
    copyMem(addr(str[0]), lpstr, csize(lpdatLen) )

    var data = str$lpdatLen.int32
    case k
    of CF_UNICODETEXT:
        result = newPasteboardItem(PboardKindString, data)
    else:
        let maxLen = MAX_FORMAT_NAME_LEN
        var fName = newString(maxLen)
        var L = getClipboardFormatName(k, addr(fName[0]), maxLen)
        if L == 0'i32: error()
        result = newPasteboardItem(fName, data)

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem])=
    if *openClipboard() and *emptyClipboard():

        for pi in pi_ar:
            let fKind = getClipboardFormatByString(pi.kind)
            let cwstr = newWideCString(pi.data)
            let size = csize(cwstr.len + 1) * sizeof(Utf16Char)
            var allmem = globalAlloc(GMEM_MOVEABLE, size)
            let pBuf = globalLock(allmem)
            if not pBuf.isNil:
                copyMem(pBuf, addr(cwstr[0]), size)
                discard globalUnlock(allmem)
                discard setClipboardData(fKind, allmem)
                discard globalFree(allmem)

        discard closeClipboard()

    else:
        error()

proc pbRead(p: Pasteboard, kind: string): PasteboardItem =

    let fKind = getClipboardFormatByString(kind)
    if *openClipboard():
        if not *isClipboardFormatAvailable(fKind): return nil

        var hglb = getClipboardData(fKind)
        var lpstr = globalLock(hglb)

        if not lpstr.isNil:
            result = getPasteboardItem(fKind, lpstr, hglb)
        else:
            result = nil

        discard globalUnlock(hglb)
        discard closeClipboard()

    else:
        error()

proc pasteboardWithName*(name: string): Pasteboard=
    var res = new(WindowsPasteboard)
    res.writeImpl = pbWrite
    res.readImpl = pbRead

    result = res
