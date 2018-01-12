when not defined(android):
    {.error: "This module is available only for Android target".}

{.deprecated.} # Use android.app.activity module instead

import android.app.activity

proc mainActivity*(): Activity {.deprecated.} =
    # Use android.app.activity.currentActivity()
    currentActivity()
