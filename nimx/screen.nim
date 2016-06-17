when defined(ios):
    {.emit: "#import <UIKit/UIKit.h>".}
    type UIScreen {.importc, header: "<UIKit/UIKit.h>", final.} = distinct int
    proc mainScreen: UIScreen {.importobjc: "UIScreen mainScreen", nodecl.}
    proc scaleFactor(s: UIScreen): float32 =
        {.emit: """
        `result` = [`s` respondsToSelector: @selector(scale)] ? [`s` scale] : 1.0f;
        """.}
elif defined(macosx):
    {.emit: "#import <AppKit/AppKit.h>".}
    type NSScreen {.importc, header: "<AppKit/AppKit.h>", final.} = distinct int
    proc mainScreen: NSScreen {.importobjc: "NSScreen mainScreen", nodecl.}
    proc scaleFactor(s: NSScreen): float32 =
        {.emit: """
        `result` = [`s` respondsToSelector: @selector(backingScaleFactor)] ? [`s` backingScaleFactor] : 1.0f;
        """.}
elif defined(android):
    import jnim, sdl2
    jnimport:
        import android.util.DisplayMetrics
        import android.app.Activity
        import android.view.WindowManager
        import android.view.Display

        proc new(t: typedesc[DisplayMetrics])
        proc getWindowManager(a: Activity): WindowManager
        proc getDefaultDisplay(w: WindowManager): Display
        proc getMetrics(d: Display, outMetrics: DisplayMetrics)

        proc density(d: DisplayMetrics): jfloat {.property.}
        proc densityDpi(d: DisplayMetrics): jint {.property.}

proc screenScaleFactor*(): float =
    when defined(macosx) or defined(ios):
        result = mainScreen().scaleFactor()
    elif defined(js):
        asm "`result` = window.devicePixelRatio;"
    elif defined(android):
        let act = Activity(sdl2.androidGetActivity())
        let dm = DisplayMetrics.new()
        act.getWindowManager().getDefaultDisplay().getMetrics(dm)
        result = dm.density
        result = 1.0 #called in sdl_window for viewportSize
    else:
        result = 1.0

var dpi = 0

proc getDPI*(): int =
    var screenScale = screenScaleFactor()
    when defined(android):
        if dpi == 0:
            let act = Activity(sdl2.androidGetActivity())
            let dm = DisplayMetrics.new()
            act.getWindowManager().getDefaultDisplay().getMetrics(dm)
            dpi = dm.densityDpi

    elif defined(ios) or defined(macosx):
        if dpi == 0:
            {.emit: """
                if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                    `dpi` = 132 * `screenScale`;
                } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                    `dpi` = 163 * `screenScale`;
                } else {
                    `dpi` = 160 * `screenScale`;
                }
            """.}

    else:
        dpi = 96

    result = dpi
