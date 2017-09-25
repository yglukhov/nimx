when defined(ios):
    import darwin.ui_kit
elif defined(macosx):
    import darwin.app_kit
elif defined(android):
    import jnim, sdl2
    import android.util.display_metrics
    import android.view.display
    import android.view.window_manager
    import android.app.activity

elif defined(emscripten):
    import jsbind.emscripten

proc screenScaleFactor*(): float =
    when defined(macosx) or defined(ios):
        result = mainScreen().scaleFactor()
    elif defined(js):
        asm "`result` = window.devicePixelRatio;"
    elif defined(android):
        let act = Activity.fromJObject(cast[jobject](sdl2.androidGetActivity()))
        let dm = DisplayMetrics.new()
        act.getWindowManager().getDefaultDisplay().getMetrics(dm)
        result = dm.density
        result = 1.0 # TODO: Take care of this
    elif defined(emscripten):
        result = emscripten_get_device_pixel_ratio()
    else:
        result = 1.0
