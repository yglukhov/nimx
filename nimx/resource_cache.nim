import resource
import tables
import json
import strutils
import streams
import system_logger
import types
import sequtils
import oswalkdir

const debugResCache = false

type ResourceLoader* = ref object
    totalSize : int
    loadedSize: int
    itemsToLoad: int
    onComplete*: proc()
    when debugResCache:
        resourcesToLoad: seq[string]

proc getFileExtension(name: string): string =
    let p = name.rfind('.')
    if p != -1:
        result = name.substr(p + 1)

proc onResourceLoaded(ld: ResourceLoader, name: string) =
    dec ld.itemsToLoad
    when debugResCache:
        ld.resourcesToLoad.keepIf(proc(a: string):bool = a != name)
        echo "REMAINING ITEMS: ", ld.resourcesToLoad
    if ld.itemsToLoad == 0:
        ld.onComplete()

type ResourceLoaderProc* = proc(name: string, completionCallback: proc())

var resourcePreloaders = newSeq[tuple[fileExtensions: seq[string], loader: ResourceLoaderProc]]()

proc startPreloadingResource(ld: ResourceLoader, name: string) =
    let extension = name.getFileExtension()

    for rp in resourcePreloaders:
        if extension in rp.fileExtensions:
            rp.loader name, proc() =
                ld.onResourceLoaded(name)
            return

    ld.onResourceLoaded(nil)
    logi "WARNING: Unknown resource type: ", name
    #raise newException(Exception, "Unknown resource type: " & name)

proc registerResourcePreloader*(fileExtensions: openarray[string], loader: proc(name: string, callback: proc())) {.deprecated.} =
    resourcePreloaders.add((@fileExtensions, loader))

proc registerResourcePreloader*[T](fileExtensions: openarray[string], loader: proc(name: string, callback: proc(r: T))) =
    proc wrapCb(name: string, callback: proc()) =
        loader(name) do(r: T):
            registerResource(name, r)
            callback()
    resourcePreloaders.add((@fileExtensions, wrapCb))

registerResourcePreloader(["json", "zsm"]) do(name: string, callback: proc(j: JsonNode)):
    loadJsonResourceAsync(name) do(j: JsonNode):
        callback(j)

registerResourcePreloader(["obj", "txt"]) do(name: string, callback: proc(s: string)):
    when defined(js):
        proc handler(r: ref RootObj) =
            var text = cast[cstring](r)
            callback($text)

        loadJSResourceAsync(name, "text", nil, nil, handler)
    else:
        loadResourceAsync name, proc(s: Stream) =
            callback(s.readAll())
            s.close()

proc preloadResources*(ld: ResourceLoader, resourceNames: openarray[string]) =
    ld.itemsToLoad += resourceNames.len
    when debugResCache:
        ld.resourcesToLoad = @resourceNames
    let oldWarn = warnWhenResourceNotCached
    warnWhenResourceNotCached = false
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
        result.removeSuffix()
    else:
        result = staticExec("echo $" & k)
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
