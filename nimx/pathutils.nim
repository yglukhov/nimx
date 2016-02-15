import strutils

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

proc normalizePath*(path: var string) =
    let ln = path.len
    var j = 0
    var i = 0

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
            when defined(windows):
                if path[j] == '/': path[j] = '\\'
            else:
                if path[j] == '\\': path[j] = '/'

            inc j
            inc i
    path.setLen(j)

when isMainModule:
    doAssert(relativePathToPath("/a/b/c/d/e", "/a/b/c/f/g") == "../../f/g")
