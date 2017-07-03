import url_stream
import jnim
import android.ndk.aasset_manager
import android.app.activity
import android.content.res.asset_manager
import android.content.context
import sdl2

proc getAssetManager(): AAssetManager =
    let act = Activity.fromJObject(cast[jobject](androidGetActivity()))
    result = act.getApplication().getAssets().getNative()

let gAssetManager = getAssetManager()

registerUrlHandler("android_asset") do(url: string, handler: Handler) {.gcsafe.}:
    const prefixLen = "android_asset://".len
    let p = url.substr(prefixLen)
    let s = gAssetManager.streamForReading(p)
    var err: string
    if s.isNil:
        err = "Could not load android asset: " & url
    handler(s, err)
