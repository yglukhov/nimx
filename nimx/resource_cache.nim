import resource
import tables
import json
import strutils
import streams
import system_logger
import types
import sequtils
import oswalkdir
import variant

import nimx.assets.asset_loading
import nimx.assets.url_stream
import nimx.assets.json_loading

const debugResCache = false

const jsEnv = defined(js) or defined(emscripten)

type ResourceLoader* = ref object
    when jsEnv:
        remainingItemsToLoad: seq[string]
        itemsLoading: int
    totalSize : int
    loadedSize: int
    itemsToLoad: int
    itemsLoaded: int
    onComplete*: proc()
    onProgress*: proc(p: float)
    resourceCache*: ResourceCache # Cache to put the loaded resources to. If nil, default cache is used.
    when debugResCache:
        resourcesToLoad: seq[string]

proc getFileExtension(name: string): string =
    let p = name.rfind('.')
    if p != -1:
        result = name.substr(p + 1)

when jsEnv:
    proc loadNextResources(ld: ResourceLoader)

proc onResourceLoaded(ld: ResourceLoader, name: string) =
    when jsEnv: dec ld.itemsLoading
    inc ld.itemsLoaded
    when debugResCache:
        ld.resourcesToLoad.keepIf(proc(a: string):bool = a != name)
        echo "REMAINING ITEMS: ", ld.resourcesToLoad
    if ld.itemsToLoad == ld.itemsLoaded:
        ld.onComplete()
    if not ld.onProgress.isNil:
        ld.onProgress( ld.itemsLoaded.float / ld.itemsToLoad.float)

    when jsEnv: ld.loadNextResources()

type ResourceLoaderProc = proc(name: string, completionCallback: proc(r: Variant))

var resourcePreloaders = newSeq[tuple[fileExtensions: seq[string], loader: ResourceLoaderProc]]()

proc startPreloadingResource(ld: ResourceLoader, name: string) =
    let extension = name.getFileExtension()
    when jsEnv: inc ld.itemsLoading

    for rp in resourcePreloaders:
        if extension in rp.fileExtensions:
            rp.loader name, proc(r: Variant) =
                ld.resourceCache.registerResource(name, r)
                ld.onResourceLoaded(name)
            return

    ld.onResourceLoaded(nil)
    logi "WARNING: Unknown resource type: ", name
    #raise newException(Exception, "Unknown resource type: " & name)

when jsEnv:
    proc loadNextResources(ld: ResourceLoader) =
        const parallelLoaders = 10
        while ld.itemsLoading < parallelLoaders and ld.remainingItemsToLoad.len > 0:
            let next = ld.remainingItemsToLoad.pop()
            ld.startPreloadingResource(next)

proc registerResourcePreloader*[T](fileExtensions: openarray[string], loader: proc(name: string, callback: proc(r: T))) =
    proc wrapCb(name: string, callback: proc(r: Variant)) =
        loader(name) do(r: T):
            callback(newVariant(r))
    resourcePreloaders.add((@fileExtensions, wrapCb))

registerResourcePreloader(["json", "zsm"]) do(name: string, callback: proc(j: JsonNode)):
    loadJsonResourceAsync(name) do(j: JsonNode):
        callback(j)

registerAssetLoader(["json", "zsm"]) do(url: string, callback: proc(j: JsonNode)):
    loadJsonFromURL(url, callback)

when defined(js) or defined(emscripten):
    import jsbind

registerAssetLoader(["obj", "txt"]) do(s: Stream, callback: proc(s: string)):
    callback(s.readAll())

registerResourcePreloader(["obj", "txt"]) do(name: string, callback: proc(s: string)):
    when defined(js) or defined(emscripten):
        proc handler(str: JSObj) =
            callback(jsObjToString(str))
        loadJSResourceAsync(name, "text", nil, nil, handler)
    else:
        loadResourceAsync name, proc(s: Stream) =
            callback(s.readAll())
            s.close()

proc preloadResources*(ld: ResourceLoader, resourceNames: openarray[string]) =
    ld.itemsToLoad += resourceNames.len
    if ld.resourceCache.isNil:
        ld.resourceCache = currentResourceCache()
    when debugResCache:
        ld.resourcesToLoad = @resourceNames
    let oldWarn = warnWhenResourceNotCached
    warnWhenResourceNotCached = false
    when jsEnv:
        ld.remainingItemsToLoad = @resourceNames
        ld.loadNextResources()
    else:
        for i in resourceNames:
            ld.startPreloadingResource(i)
    warnWhenResourceNotCached = oldWarn

proc isHiddenFile(path: string): bool =
    let lastSlash = path.rfind("/")
    if lastSlash == -1:
        result = path[0] == '.'
    elif lastSlash != path.len - 1:
        result = path[lastSlash + 1] == '.'

proc getEnvCt(k: string): string {.compileTime.} =
    when defined(buildOnWindows): # This should be defined by the naketools.nim
        result = staticExec("cmd /c \"echo %NIMX_RES_PATH%\"")
    else:
        result = staticExec("echo $" & k)
    result.removeSuffix()
    if result == "": result = nil

proc getResourceNames*(path: string = ""): seq[string] {.compileTime.} =
    ## Collects file names inside resource folder in compile time.
    ## Path to resource folder should be provided by `NIMX_RES_PATH` environment
    ## variable. If no `NIMX_RES_PATH` is set, a compile time warning is emitted
    ## and "./res" is used as resource folder path.
    ## Returns a seq of file names which can then be used as an argument to
    ## `preloadResources`
    result = newSeq[string]()

    var prefix = getEnvCt("NIMX_RES_PATH")
    if prefix.isNil:
        prefix = "res/"
        echo "WARNING: NIMX_RES_PATH environment variable not set"
    else:
        prefix &= "/"

    for f in oswalkdir.walkDirRec(prefix & path):
        if not isHiddenFile(f):
            var str = f.substr(prefix.len)
            when defined(buildOnWindows):
                str = str.replace('\\', '/')
            result.add(str)
