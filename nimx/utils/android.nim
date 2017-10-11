when not defined(android):
    {.error: "This module is available only for Android target".}

import jnim
import android.app.activity

when not defined(nimxAvoidSDL):
    import sdl2

proc mainActivity*(): Activity =
    when defined(nimxAvoidSDL):
        {.error: "Not implemented yet".}
    else:
        Activity.fromJObject(cast[jobject](sdl2.androidGetActivity()))
