when defined(ios):
  import darwin/ui_kit
elif defined(macosx):
  import darwin/app_kit
elif defined(android):
  import android/util/display_metrics
  import android/app/activity
  import android/content/context_wrapper
  import android/content/res/resources

elif defined(emscripten):
  import jsbind/emscripten

proc screenScaleFactor*(): float =
  when defined(macosx) or defined(ios):
    result = mainScreen().scaleFactor()
  elif defined(js):
    asm "`result` = window.devicePixelRatio;"
  elif defined(android):
    let sm = currentActivity().getResources().getDisplayMetrics()
    result = sm.scaledDensity
  elif defined(emscripten):
    result = emscripten_get_device_pixel_ratio()
  else:
    result = 1.0
