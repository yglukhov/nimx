proc targetIsJs(t: string): bool =
    t == "js" or t == "nodejs"

proc commonBuild*(mainFile: string) =
    --threads:on
    when not defined(windows):
        --noMain

    # parse cmdline

    var target = "current"

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

    if target.targetIsJs():
        setCommand("js", mainFile)
    else:
        setCommand("c", mainFile)
