import strutils

when defined(js):
    proc native_log(a: cstring) {.importc: "console.log".}
elif defined(emscripten):
    proc emscripten_log(flags: cint) {.importc, varargs.}
    template native_log(a: cstring) =
        emscripten_log(0, cstring("%s"), cstring(a))
elif defined(macosx) or defined(ios):
    {.passL:"-framework Foundation"}
    {.emit: """

    #include <CoreFoundation/CoreFoundation.h>
    extern void NSLog(CFStringRef format, ...);

    """.}

    proc native_log(a: cstring) =
        {.emit: "NSLog(CFSTR(\"%s\"), `a`);" .}
elif defined(android):
    {.emit: """
    #include <android/log.h>
    """.}

    proc native_log(a: cstring) =
        {.emit: """__android_log_write(ANDROID_LOG_INFO, "NIM_APP", `a`);""".}
else:
    template native_log(a: string) = echo a

proc nimxPrivateStringify*[T](v: T): string {.inline.} = $v
proc nimxPrivateStringify*(v: string): string {.inline.} =
    result = v
    if result.isNil: result = "(nil)"

var currentOffset = ""

proc logi*(a: varargs[string, nimxPrivateStringify]) = native_log(currentOffset & a.join())

template enterLog*() =
    currentOffset &= "  "
    defer: currentOffset.setLen(currentOffset.len - 2)
