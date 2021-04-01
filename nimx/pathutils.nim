import strutils, os, parseutils

proc urlParentDir*(url: string): string =
    let schemeEnd = url.find(':')
    if schemeEnd == -1 or url.len <= schemeEnd + 3 or url[schemeEnd + 1] != '/' or url[schemeEnd + 2] != '/':
        raise newException(ValueError, "Invalid url: " & url)

    let i = url.rfind({'/', '\\'})
    if i <= schemeEnd + 3:
        raise newException(ValueError, "Cannot get parent dir in url: " & url)

    url[0 ..< i]

proc parentDirEx*(pathOrUrl: string): string =
    let i = pathOrUrl.rfind({'/', '\\'})
    if i == -1: return ""
    pathOrUrl[0 ..< i]

proc relativePathToPath*(path, toPath: string): string =
    # Returns a relative path to `toPath` which is equivalent of absolute `path`
    # E.g. given `path` = "/a/b/c/d/e" and `toPath` = "/a/b/c/f/g"
    # result = "../../f/g"

    let pc = path.split({'/', '\\'})
    let tpc = toPath.split({'/', '\\'})

    let ln = min(pc.len, tpc.len)
    var cp = 0
    while cp < ln:
        if pc[cp] != tpc[cp]: break
        inc cp

    var ccp = pc.len - cp
    result = ""
    while ccp > 0:
        result &= "../"
        dec ccp
    while cp < tpc.len:
        result &= tpc[cp]
        if cp != tpc.len - 1:
            result &= "/"
        inc cp

proc normalizePath*(path: var string, usePlatformSeparator: bool = true) =
    let ln = path.len
    var j = 0
    var i = 0

    let targetSeparator = if usePlatformSeparator:(when defined(windows):'\\'else:'/')else:'/'
    let replaceSeparator = if usePlatformSeparator:(when defined(windows):'/'else:'\\')else:'\\'

    template isSep(c: char): bool = c == '/' or c == '\\'
    template rollback() =
        dec j
        if j < 0:
            raise newException(Exception, "Path is too relative: " & path)
        while j > 0:
            if path[j].isSep: break
            dec j

    while i < ln:
        var copyChar = true
        if path[i].isSep:
            if ln > i + 1:
                if path[i + 1] == '.':
                    if ln > i + 2:
                        if path[i + 2] == '.':
                            rollback()
                            copyChar = false
                            i += 3
                            if j == 0: inc i
                        elif path[i + 2].isSep:
                            copyChar = false
                            i += 2
        if copyChar:
            path[j] = path[i]
            if path[j] == replaceSeparator: path[j] = targetSeparator

            inc j
            inc i
    path.setLen(j)

proc isSubpathOf*(child, parent: string): bool =
    if child.len < parent.len: return false
    let ln = parent.len
    var i = 0
    while i < ln:
        if parent[i] != child[i]: return false
        inc i
    return i == child.len or child[i] == '/' or parent[i - 1] == '/'

proc toAbsolutePath*(relativeOrAbsolutePath, basePath: string): string =
    if isAbsolute(relativeOrAbsolutePath): return relativeOrAbsolutePath
    result = basePath & '/' & relativeOrAbsolutePath
    normalizePath(result)

when defined(js):
    proc getCurrentHref*(): string =
        var s: cstring
        {.emit: """
        `s` = window.location.href;
        """.}
        result = $s
elif defined(emscripten):
    import jsbind/emscripten

    proc getCurrentHref*(): string =
        let r = EM_ASM_INT """
        return _nimem_s(window.location.href);
        """
        result = cast[string](r)

iterator uriParamsPairs*(s: string): (string, string) =
    var i = s.skipUntil('?') + 1
    while i < s.len:
        var k, v: string
        i += s.parseUntil(k, '=', i) + 1
        i += s.parseUntil(v, '&', i) + 1
        yield (k, v)

proc uriParam*(url, key: string, default: string = ""): string =
    for k, v in url.uriParamsPairs:
        if k == key: return v
    return default

when isMainModule:
    doAssert(relativePathToPath("/a/b/c/d/e", "/a/b/c/f/g") == "../../f/g")
    doAssert("a/b/c".isSubpathOf("a/b"))
    doAssert(not "a/b/ca".isSubpathOf("a/b/c"))
    doAssert("a/b/c/a".isSubpathOf("a/b/c/"))
    doAssert(urlParentDir("file://a/b") == "file://a")
