when defined(ios):
    {.emit: "#import <UIKit/UIKit.h>".}
    type UIScreen {.importc, header: "<UIKit/UIKit.h>", final.} = distinct int
    proc mainScreen: UIScreen {.importobjc: "UIScreen mainScreen", nodecl.}
    proc scaleFactor(s: UIScreen): float32 =
        {.emit: """
        `result` = [`s` respondsToSelector: @selector(nativeScale)] ? [`s` nativeScale] : 1.0f;
        """.}
        # result = 1.0 # TODO: Fix this
elif defined(macosx):
    {.emit: "#import <AppKit/AppKit.h>".}
    type NSScreen {.importc, header: "<AppKit/AppKit.h>", final.} = distinct int
    proc mainScreen: NSScreen {.importobjc: "NSScreen mainScreen", nodecl.}
    proc scaleFactor(s: NSScreen): float32 =
        {.emit: """
        `result` = [`s` respondsToSelector: @selector(backingScaleFactor)] ? [`s` backingScaleFactor] : 1.0f;
        """.}
elif defined(android):
    import jnim
    jclass android.util.DisplayMetrics of JVMObject:
        proc new
        proc density: jfloat {.prop.}

    jclass android.view.Display of JVMObject:
        proc getMetrics(outMetrics: DisplayMetrics)
        proc getRealMetrics(outMetrics: DisplayMetrics)

    jclass android.view.WindowManager of JVMObject:
        proc getDefaultDisplay: Display

    jclass android.app.Activity of JVMObject:
        proc getWindowManager: WindowManager

elif defined(emscripten):
    import jsbind.emscripten

proc screenScaleFactor*(): float =
    when defined(macosx) or defined(ios):
        result = mainScreen().scaleFactor()
    elif defined(js):
        asm "`result` = window.devicePixelRatio;"
    elif defined(android):
        proc nimx_getAndroidActivity(): jobject {.importc.}
        let act = Activity.fromJObject(nimx_getAndroidActivity())
        let dm = DisplayMetrics.new()
        let disp = act.getWindowManager().getDefaultDisplay()
        try:
            disp.getRealMetrics(dm)
        except:
            disp.getMetrics(dm)
        result = dm.density
        result = 1.0
    elif defined(emscripten):
        result = emscripten_get_device_pixel_ratio()
    else:
        result = 1.0
