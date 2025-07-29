import url_stream
import jnim
import sdl2
import android/ndk/aasset_manager
import android/app/activity
import android/content/res/asset_manager
import android/content/context

# set jnim jniEnv from sdl
theEnv = cast[JNIEnvPtr](androidGetJNIEnv())

proc getAssetManager(): AAssetManager =
  result = currentActivity().getApplication().getAssets().getNative()

let gAssetManager = getAssetManager()

registerUrlHandler("android_asset") do(url: string, handler: Handler) {.gcsafe.}:
  const prefixLen = "android_asset://".len
  let p = url.substr(prefixLen)
  let s = gAssetManager.streamForReading(p)
  var err: string
  if s.isNil:
    err = "Could not load android asset: " & url
  handler(s, err)
