import strutils, logging

when defined(js):
    when defined(runAutoTests):
        proc native_log(a: cstring) =
            {.emit: """
            if ('dump' in window)
                window['dump'](`a` + '\n');
            else
                console.log(`a`);
            """.}
    else:
        proc native_log(a: cstring) {.importc: "console.log".}
elif defined(emscripten):
    when defined(runAutoTests):
        import jsbind.emscripten
        proc native_log(a: cstring) =
            discard EM_ASM_INT("""
            var s = Pointer_stringify($0);
            if ('dump' in window)
                window['dump'](s + '\n');
            else
                console.log(s);
            return 0;
            """, a)
    else:
        proc emscripten_log(flags: cint) {.importc, varargs.}
        template native_log(a: cstring) =
            emscripten_log(0, cstring("%s"), cstring(a))
elif defined(macosx) or defined(ios):
    {.passL:"-framework Foundation".}
    {.emit: """

    #include <CoreFoundation/CoreFoundation.h>
    extern void NSLog(CFStringRef format, ...);

    """.}

    proc native_log(a: cstring) =
        {.emit: "NSLog(CFSTR(\"%s\"), `a`);".}
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

var currentOffset {.threadvar.}: string

proc logi*(a: varargs[string, nimxPrivateStringify]) {.gcsafe.} =
    if currentOffset.isNil: currentOffset = ""
    native_log(currentOffset & a.join())

proc increaseOffset() =
    if currentOffset.isNil: currentOffset = "  "
    else: currentOffset &= "  "

template decreaseOffset() =
    currentOffset.setLen(currentOffset.len - 2)

template enterLog*() =
    increaseOffset()
    defer: decreaseOffset()

type SystemLogger = ref object of Logger

method log*(logger: SystemLogger, level: Level, args: varargs[string, `$`]) =
    if currentOffset.isNil: currentOffset = ""
    native_log(currentOffset & args.join())

proc registerLogger() =
    var lg: SystemLogger
    lg.new()
    addHandler(lg)

registerLogger()
