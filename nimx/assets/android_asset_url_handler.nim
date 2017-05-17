import url_stream
import android.ndk.aasset_manager

import sdl2
import jnim

jclassDef android.content.res.AssetManager of JVMObject

jclass android.app.Application of JVMObject:
    proc getAssets: AssetManager

jclass android.app.Activity of JVMObject:
    proc getApplication: Application

proc getAssetManager(): AAssetManager =
    let act = Activity.fromJObject(cast[jobject](androidGetActivity()))
    let am = act.getApplication().getAssets().get()
    result = AAssetManager_fromJava(am)

let gAssetManager = getAssetManager()

registerUrlHandler("android_asset") do(url: string, handler: Handler) {.gcsafe.}:
    const prefixLen = "android_asset://".len
    let p = url.substr(prefixLen)
    let s = gAssetManager.streamForReading(p)
    var err: string
    if s.isNil:
        err = "Could not load android asset: " & url
    handler(s, err)
