import abstract_pasteboard
export abstract_pasteboard
import winlean
import tables
import os
{.pragma: winApi, stdcall, nodecl.}

type
    LPVOID = pointer
    UINT = cuint
    # HANDLE = pointer

const
    CF_UNICODETEXT: UINT = 13
    GMEM_MOVEABLE: UINT = 0x0002
    MAX_FORMAT_NAME_LEN = 512'i32

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
proc globalAlloc(uFlags: UINT, dwBytes: csize): Handle {.winApi, importc: "GlobalAlloc".}

# HGLOBAL WINAPI GlobalFree(
#   _In_ HGLOBAL hMem
# );
proc globalFree(hMem: Handle): Handle {.winApi, importc: "GlobalFree".}

# SIZE_T WINAPI GlobalSize(
#   _In_ HGLOBAL hMem
# );
proc globalSize(hMem: Handle): csize {.winApi, importc: "GlobalSize".}

# UINT WINAPI GlobalFlags(
#   _In_ HGLOBAL hMem
# );
proc globalFlags(hMem: Handle): UINT {.winApi, importc: "GlobalFlags".}

# UINT WINAPI RegisterClipboardFormat(
#   _In_ LPCTSTR lpszFormat
# );
proc registerClipboardFormat(lpszFormat: WideCString): UINT {.winApi, importc: "RegisterClipboardFormat".}

# int WINAPI GetClipboardFormatName(
#   _In_  UINT   format,
#   _Out_ LPTSTR lpszFormatName,
#   _In_  int    cchMaxCount
# );
proc getClipboardFormatName(uFormat: UINT, lpszFormatName: WideCString, cchMaxCount: int32): int32 {.winApi, importc: "GetClipboardFormatName".}

proc `*`(b: SomeOrdinal): bool = result = b != 0

proc getClipboardFormatByString(str: string): UINT =
    case str
    of PboardKindString: result = CF_UNICODETEXT
    else:
        var uFormat = registerClipboardFormat(newWideCString (str))
        if not *uFormat:
            raiseOSError($getLastError())
        result = uFormat

type WindowsPasteboard = ref object of Pasteboard

proc getPasteboardItem(k: UINT, lpstr: LPVOID, lpdat: Handle): PasteboardItem =
    var lpdatLen = globalSize(lpdat)
    if not *lpdatLen: raiseOSError($getLastError())
    var str = newWideCString("",lpdatLen)
    copyMem(addr(str[0]), lpstr, csize(lpdatLen) )

    var data = str$lpdatLen.int32
    case k
    of CF_UNICODETEXT:
        result = newPasteboardItem(PboardKindString, data)
    else:
        let maxLen = MAX_FORMAT_NAME_LEN
        var fName = newWideCString("", maxLen)
        var L = getClipboardFormatName(k, fName, maxLen)
        if L == 0'i32: raiseOSError($getLastError())
        result = newPasteboardItem(fName$L, data)

proc pbWrite(p: Pasteboard, pi_ar: varargs[PasteboardItem])=
    if *openClipboard() and *emptyClipboard():

        for pi in pi_ar:
            let win_kind = getClipboardFormatByString(pi.kind)
            let cwstr = newWideCString(pi.data)
            let size = csize(cwstr.len + 1) * sizeof(Utf16Char)
            var allmem = globalAlloc(GMEM_MOVEABLE, size)
            let pBuf = globalLock(allmem)
            if not pBuf.isNil:
                copyMem(pBuf, addr(cwstr[0]), size)
                discard globalUnlock(allmem)
                discard setClipboardData(win_kind, allmem)
                discard globalFree(allmem)

        discard closeClipboard()

    else:
        raiseOSError($getLastError())

proc pbRead(p: Pasteboard, kind: string): PasteboardItem =

    let win_kind = getClipboardFormatByString(kind)
    if *openClipboard():
        if not *isClipboardFormatAvailable(win_kind): return nil

        var hglb = getClipboardData(win_kind)
        var lpstr = globalLock(hglb)

        if not lpstr.isNil:
            result = getPasteboardItem(win_kind, lpstr, hglb)
        else:
            result = nil

        discard globalUnlock(hglb)
        discard closeClipboard()

    else:
        raiseOSError($getLastError())

proc pasteboardWithName*(name: string): Pasteboard=
    var res = new(WindowsPasteboard)
    res.writeImpl = pbWrite
    res.readImpl = pbRead

    result = res
