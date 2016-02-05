import oswalkdir, ospaths

proc targetIsJs(t: string): bool =
    t == "js" or t == "nodejs"

proc commonBuild*(mainFile: string) =
    var target = "current"
    var doRun = true

    for i in 0 .. paramCount():
        let p = paramStr(i)
        if p == "-d:android":
            target = "android"
        elif p == "-d:ios":
            target = "ios"
        elif p == "-d:iosSim":
            target = "iosSim"
        elif p == "-d:js":
            target = "js"
        elif p == "-d:nodejs":
            target = "nodejs"
        elif p == "-d:norun":
            doRun = false

    if doRun and target != "js":
        --run

    if target.targetIsJs():
        setCommand("js", mainFile)
        if doRun and target == "js":
            discard # Start browser here
    else:
        --threads:on
        when not defined(windows):
            --noMain

        setCommand("c", mainFile)

proc cpDir*(src, dst: string) =
    for t, f in walkDir(src, true):
        if t == pcDir:
            mkDir(dst / f)
            cpDir(src / f, dst / f)
        else:
            cpFile(src / f, dst / f)
