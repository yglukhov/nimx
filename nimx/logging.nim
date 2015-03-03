import strutils

# Support logging on iOS and android
when defined(JS):
    proc js_log_imported(a: cstring) =
        asm """
        console.log(`a`);
        """

    proc log*(a: varargs[string, `$`]) =
        js_log_imported(a.join())
elif defined(macosx) or defined(ios):
    {.emit: """

    #include <CoreFoundation/CoreFoundation.h>
    extern void NSLog(CFStringRef format, ...);

    """.}

    proc NSLog_imported(a: cstring) =
        {.emit: "NSLog(CFSTR(\"%s\"), a);" .}

    proc log*(a: varargs[string, `$`]) = NSLog_imported(a.join())
elif defined(android):
    {.emit: """
    #include <android/log.h>
    """.}

    proc droid_log_imported(a: cstring) =
        {.emit: """__android_log_print(ANDROID_LOG_INFO, "NIM_APP", a);""".}
    proc log*(a: varargs[string, `$`]) = droid_log_imported(a.join())
else:
    proc log*(a: varargs[string, `$`]) = echo a.join()

