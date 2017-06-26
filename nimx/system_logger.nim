import strutils, logging

when defined(js):
    proc native_log(a: cstring) {.importc: "console.log".}
elif defined(emscripten):
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

proc join*(a: openArray[string], sep: string = "", nilSubstitute: string = nil): string {.
  noSideEffect.} =
  ## Concatenates all strings in `a` separating them with `sep`.
  if len(a) > 0:
    var L = sep.len * (a.len-1)
    for i in 0..high(a): inc(L, if a[i].isNil: nilSubstitute.len else: a[i].len)
    result = newStringOfCap(L)
    add(result, a[0])
    for i in 1..high(a):
      add(result, sep)
      add(result, if a[i].isNil: nilSubstitute else: a[i])
  else:
    result = ""

proc logi*(a: varargs[string, nimxPrivateStringify]) {.gcsafe.} =
    if currentOffset.isNil: currentOffset = ""
    native_log(currentOffset & a.join(nilSubstitute = "(nil)"))

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
    native_log(currentOffset & args.join(nilSubstitute = "(nil)"))

proc registerLogger() =
    var lg: SystemLogger
    lg.new()
    addHandler(lg)

registerLogger()
