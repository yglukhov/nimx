import strutils, tables
import variant
import abstract_asset_bundle, asset_cache, url_stream, asset_loading, asset_loader
import nimx/pathutils

type
    MountEntry = tuple
        ab: AssetBundle
        cache: AssetCache
        path: string
        refCount: int

    AssetManager* = ref object
        mounts: seq[MountEntry]
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
        if m.ab == ab or m.ab.urlForPath("") == ab.urlForPath(""):
            return i
    return -1

when defined(windows):
    template normalizeSlashes(s: string): string = s.replace('\\', '/')
else:
    template normalizeSlashes(s: string): string = s

proc mountForPath(am: AssetManager, path: string): MountEntry =
    let i = am.mountIndex(path)
    if i == -1:
        return (am.defaultAssetBundle, am.defaultCache, path, 0)
    return (am.mounts[i].ab, am.mounts[i].cache, path.substr(am.mounts[i].path.len + 1), am.mounts[i].refCount)

proc mount*(am: AssetManager, path: string, assetBundle: AssetBundle) =
    let i = am.mountIndex(path)
    if i == -1:
        am.mounts.add((assetBundle, newAssetCache(), path, 1))
    else:
        inc am.mounts[i].refCount

proc unmountAUX(am: AssetManager, i: int) =
    if i < 0 or i >= am.mounts.len: return
    dec am.mounts[i].refCount
    if am.mounts[i].refCount == 0:
        am.mounts.del(i)

proc unmount*(am: AssetManager, path: string) =
    let i = am.mountIndex(path)
    am.unmountAUX(i)

proc unmount*(am: AssetManager, ab: AssetBundle) =
    let i = am.mountIndex(ab)
    am.unmountAUX(i)

proc unmountAll*(am: AssetManager) =
    am.mounts.setLen(0)

proc assetBundleForPath*(am: AssetManager, path: string): AssetBundle =
    am.mountForPath(path.normalizeSlashes).ab

proc urlForResource*(am: AssetManager, path: string): string =
    var (a, _, p, _) = am.mountForPath(path.normalizeSlashes)
    result = a.urlForPath(p)

proc resolveUrl*(am: AssetManager, url: string): string =
    const prefix = "res://"
    if url.startsWith(prefix):
        let path = url.substr(prefix.len)
        result = am.urlForResource(path)
    else:
        result = url

proc cachedAssetAux(am: AssetManager, path: string): Variant =
    let (_, c, p, _) = am.mountForPath(path.normalizeSlashes)
    result = c.getOrDefault(p)

proc cacheAssetAux(am: AssetManager, path: string, v: Variant) =
    assert(not v.isNil)
    let (_, c, p, _) = am.mountForPath(path.normalizeSlashes)
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

proc getAssetAtPathAux(am: AssetManager, path: string, putToCache: bool, handler: proc(res: Variant, err: string) {.gcsafe.}) =
    let v = am.cachedAssetAux(path)
    if v.isNil:
        var (a, c, p, _) = am.mountForPath(path.normalizeSlashes)
        let url = a.urlForPath(p)
        if not putToCache:
            # Create dummy cache that will be disposed by GC
            c = newAssetCache()
        loadAsset(url, p, c) do():
            let v = c.getOrDefault(p)
            if v.isNil:
                handler(v, "Could not load asset " & path)
            else:
                handler(v, "")
    else:
        handler(v, "")

proc getAssetAtPath*[T](am: AssetManager, path: string, putToCache: bool, handler: proc(res: T, err: string) {.gcsafe.}) =
    am.getAssetAtPathAux(path, putToCache) do(res: Variant, err: string):
        if err.len == 0:
            if res.ofType(T):
                handler(res.get(T), "")
            else:
                var v: T
                handler(v, "Wrong asset type")
        else:
            var v: T
            handler(v, err)

proc getAssetAtPath*[T](am: AssetManager, path: string, handler: proc(res: T, err: string) {.gcsafe.}) {.inline.} =
    am.getAssetAtPath(path, true, handler)

proc assetCacheForPath(am: AssetManager, path: string): AssetCache =
    result = am.mountForPath(path.normalizeSlashes).cache

proc loadAssetsInBundles*(am: AssetManager, bundles: openarray[AssetBundle], onProgress: proc(p: float) {.gcsafe.}, onComplete: proc() {.gcsafe.}) =
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
        let cache = am.assetCacheForPath(am.mounts[i].path)
        for a in b.allAssetsWithBasePath(am.mounts[i].path):
            if a.substr(am.mounts[i].path.len + 1) notin cache:
                allAssets.add(a)

    if allAssets.len == 0:
        onComplete()
    else:
        al.loadAssets(allAssets)

proc dump*(am: AssetManager): string =
    result = "AssetManager DUMP:"
    for m in am.mounts:
        result &= "\n" & m.path & ": " & $m.refCount

registerUrlHandler("res") do(url: string, handler: Handler) {.gcsafe.}:
    openStreamForUrl(sharedAssetManager().resolveUrl(url), handler)

hackyResUrlLoader = proc(url, path: string, cache: AssetCache, handler: proc(err: string) {.gcsafe.}) {.gcsafe.} =
    const prefix = "res://"
    assert(url.startsWith(prefix))
    let p = url.substr(prefix.len)
    sharedAssetManager().getAssetAtPathAux(p, false) do(res: Variant, err: string):
        cache[path] = res
        handler(err)
