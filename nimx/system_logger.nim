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
  proc log_write(prio: cint, tag, text: cstring) {.importc: "__android_log_write".}
  template native_log(a: cstring) =
    # ANDROID_LOG_INFO = 4
    log_write(4, "NIM_APP", a)
else:
  template native_log(a: string) = echo a

var currentOffset {.threadvar.}: string

proc logi*(a: varargs[string, `$`]) {.gcsafe.} =
  native_log(currentOffset & a.join())

proc increaseOffset() =
  currentOffset &= "  "

template decreaseOffset() =
  currentOffset.setLen(currentOffset.len - 2)

template enterLog*() =
  increaseOffset()
  defer: decreaseOffset()

type SystemLogger = ref object of Logger

method log*(logger: SystemLogger, level: Level, args: varargs[string, `$`]) =
  native_log(currentOffset & args.join())

proc registerLogger() =
  var lg: SystemLogger
  lg.new()
  addHandler(lg)

registerLogger()
