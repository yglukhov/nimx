import strutils

# Support logging on iOS and android
when defined(js):
    proc js_console_log(a: cstring) {.importc: "console.log".}

    proc logi*(a: varargs[string, `$`]) =
        js_console_log(a.join())
elif defined(emscripten):
    proc emscripten_log(flags: cint) {.importc, varargs.}
    proc logi*(a: varargs[string, `$`]) =
        emscripten_log(0, cstring("%s"), cstring(a.join()))
elif defined(macosx) or defined(ios):
    {.passL:"-framework Foundation"}
    {.emit: """

    #include <CoreFoundation/CoreFoundation.h>
    extern void NSLog(CFStringRef format, ...);

    """.}

    proc NSLog_imported(a: cstring) =
        {.emit: "NSLog(CFSTR(\"%s\"), a);" .}

    proc logi*(a: varargs[string, `$`]) = NSLog_imported(a.join())
elif defined(android):
    {.emit: """
    #include <android/log.h>
    """.}

    proc droid_log_imported(a: cstring) =
        {.emit: """__android_log_write(ANDROID_LOG_INFO, "NIM_APP", a);""".}
    proc logi*(a: varargs[string, `$`]) = droid_log_imported(a.join())
else:
    proc logi*(a: varargs[string, `$`]) = echo a.join()
