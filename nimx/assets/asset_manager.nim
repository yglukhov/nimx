import strutils, tables
import variant
import abstract_asset_bundle, asset_cache, url_stream, asset_loading, asset_loader
import nimx.pathutils

type
    AssetManager* = ref object
        mounts: seq[tuple[path: string, ab: AssetBundle, cache: AssetCache]]
        mDefaultAssetBundle: AssetBundle
        defaultCache: AssetCache


template newAssetCache(): AssetCache = newTable[string, Variant]()

proc newAssetManager(): AssetManager =
    result.new()
    result.mounts = @[]
    result.defaultCache = newAssetCache()

var gAssetManager = newAssetManager()

when compileOption("threads"):
    let gAssetManagerPtr = cast[pointer](gAssetManager)

template sharedAssetManager*(): AssetManager =
    when compileOption("threads"):
        cast[AssetManager](gAssetManagerPtr)
    else:
        gAssetManager

proc setDefaultAssetBundle*(am: AssetManager, ab: AssetBundle) =
    assert(am.mDefaultAssetBundle.isNil, "Default asset bundle is already set")
    am.mDefaultAssetBundle = ab

when defined(android):
    import android_asset_bundle
elif defined(js) or defined(emscripten):
    import web_asset_bundle
else:
    import native_asset_bundle

proc createDefaultAssetBundle(): AssetBundle =
    when defined(android):
        newAndroidAssetBundle()
    elif defined(js) or defined(emscripten):
        newWebAssetBundle()
    else:
        newNativeAssetBundle()

proc defaultAssetBundle(am: AssetManager): AssetBundle =
    if am.mDefaultAssetBundle.isNil:
        am.mDefaultAssetBundle = createDefaultAssetBundle()
    result = am.mDefaultAssetBundle

proc mountIndex(am: AssetManager, path: string): int =
    for i, m in am.mounts:
        if path.isSubpathOf(m.path):
            return i
    return -1

proc mountIndex(am: AssetManager, ab: AssetBundle): int =
    for i, m in am.mounts:
        if m.ab == ab:
            return i
    return -1

when defined(windows):
    template normalizeSlashes(s: string): string = s.replace('\\', '/')
else:
    template normalizeSlashes(s: string): string = s

proc mountForPath(am: AssetManager, path: string): tuple[ab: AssetBundle, cache: AssetCache, path: string] =
    let i = am.mountIndex(path)
    if i == -1:
        return (am.defaultAssetBundle, am.defaultCache, path)
    return (am.mounts[i].ab, am.mounts[i].cache, path.substr(am.mounts[i].path.len + 1))

proc mount*(am: AssetManager, path: string, assetBundle: AssetBundle) =
    am.mounts.add((path, assetBundle, newAssetCache()))

proc unmount*(am: AssetManager, path: string) =
    for i in 0 ..< am.mounts.len:
        if am.mounts[i][0] == path:
            am.mounts.del(i)
            break

proc unmount*(am: AssetManager, ab: AssetBundle) =
    for i in 0 ..< am.mounts.len:
        if am.mounts[i][1] == ab:
            am.mounts.del(i)
            break

proc urlForResource*(am: AssetManager, path: string): string =
    var (a, _, p) = am.mountForPath(path.normalizeSlashes)
    result = a.urlForPath(p)

proc resolveUrl*(am: AssetManager, url: string): string =
    const prefix = "res://"
    if url.startsWith(prefix):
        let path = url.substr(prefix.len)
        result = am.urlForResource(path)
    else:
        result = url

proc cachedAssetAux(am: AssetManager, path: string): Variant =
    let (_, c, p) = am.mountForPath(path.normalizeSlashes)
    result = c.getOrDefault(p)

proc cacheAssetAux(am: AssetManager, path: string, v: Variant) =
    let (_, c, p) = am.mountForPath(path.normalizeSlashes)
    c[p] = v

proc cachedAsset*(am: AssetManager, T: typedesc, path: string): T {.inline.} =
    am.cachedAssetAux(path).get(T)

proc cachedAsset*[T](am: AssetManager, path: string, default: T): T =
    let v = am.cachedAssetAux(path)
    if v.ofType(T):
        result = v.get(T)
    else:
        result = default

proc cacheAsset*[T](am: AssetManager, path: string, v: T) {.inline.} =
    am.cacheAssetAux(path, newVariant(v))

proc getAssetAtPathAux(am: AssetManager, path: string, putToCache: bool, handler: proc(res: Variant, err: string)) =
    let v = am.cachedAssetAux(path)
    if v.isEmpty:
        var (a, c, p) = am.mountForPath(path.normalizeSlashes)
        let url = a.urlForPath(p)
        if not putToCache:
            # Create dummy cache that will be disposed by GC
            c = newAssetCache()
        loadAsset(url, path, c) do():
            let v = c.getOrDefault(p)
            if v.isEmpty:
                handler(v, "Could not load asset " & path)
            else:
                handler(v, nil)
    else:
        handler(v, nil)

proc getAssetAtPath*[T](am: AssetManager, path: string, putToCache: bool, handler: proc(res: T, err: string)) =
    am.getAssetAtPathAux(path, putToCache) do(res: Variant, err: string):
        if err.isNil:
            if res.ofType(T):
                handler(res.get(T), nil)
            else:
                var v: T
                handler(v, "Wrong asset type")
        else:
            var v: T
            handler(v, err)

proc getAssetAtPath*[T](am: AssetManager, path: string, handler: proc(res: T, err: string)) {.inline.} =
    am.getAssetAtPath(path, true, handler)

proc loadAssetsInBundles*(am: AssetManager, bundles: openarray[AssetBundle], onProgress: proc(p: float), onComplete: proc()) =
    let al = newAssetLoader()
    var tempCache = newAssetCache()

    al.onComplete = proc() =
        for k, v in tempCache:
            am.cacheAssetAux(k, v)
        onComplete()

    al.onProgress = onProgress
    al.assetCache = tempCache

    var allAssets = newSeq[string]()
    for b in bundles:
        let i = am.mountIndex(b)
        if i == -1:
            raise newException(Exception, "AssetBundle not mounted")
        allAssets &= b.allAssetsWithBasePath(am.mounts[i].path)

    al.loadAssets(allAssets)

registerUrlHandler("res") do(url: string, handler: Handler) {.gcsafe.}:
    openStreamForUrl(sharedAssetManager().resolveUrl(url), handler)
