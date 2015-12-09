import resource
import tables
import json
import strutils
import image
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

proc startPreloadingResource(ld: ResourceLoader, name: string) =
    case name.getFileExtension()
    of "png", "jpg", "jpeg", "gif", "tif", "tiff", "tga":
        when defined(js):
            proc handler(r: ref RootObj) =
                var onImLoad = proc (im: ref RootObj) =
                    var w, h: Coord
                    {.emit: "`w` = im.width; `h` = im.height;".}
                    let image = imageWithSize(newSize(w, h))
                    {.emit: "`image`.__image = im;".}
                    registerImageInCache(name, image)
                    ld.onResourceLoaded(name)
                {.emit:"""
                var im = new Image();
                im.onload = function(){`onImLoad`(im);};
                im.src = window.URL.createObjectURL(`r`);
                """.}

            loadJSResourceAsync(name, "blob", nil, nil, handler)
        else:
            registerImageInCache(name, imageWithResource(name))
            ld.onResourceLoaded(name)

    of "json", "zsm":
        loadJsonResourceAsync(name, proc(j: JsonNode) =
            gResCache.jsons[name] = j
            ld.onResourceLoaded(name)
        )
    of "obj", "txt":
        when defined(js):
            proc handler(r: ref RootObj) =
                var jsonstring = cast[cstring](r)
                gResCache.texts[name] = $jsonstring
                ld.onResourceLoaded(name)

            loadJSResourceAsync(name, "text", nil, nil, handler)
        else:
            loadResourceAsync name, proc(s: Stream) =
                gResCache.texts[name] = s.readAll()
                s.close()
                ld.onResourceLoaded(name)
    else:
        ld.onResourceLoaded(nil)
        logi "WARNING: Unknown resource type: ", name
        #raise newException(Exception, "Unknown resource type: " & name)

proc preloadResources*(ld: ResourceLoader, resourceNames: openarray[string]) =
    ld.itemsToLoad += resourceNames.len
    when debugResCache:
        ld.resourcesToLoad = @resourceNames
    for i in resourceNames:
        ld.startPreloadingResource(i)

proc isHiddenFile(path: string): bool =
    let lastSlash = path.rfind("/")
    if lastSlash == -1:
        result = path[0] == '.'
    elif lastSlash != path.len - 1:
        result = path[lastSlash + 1] == '.'

proc getResourceNames*(path: string = ""): seq[string] {.compileTime.} =
    result = newSeq[string]()
    const prefix = "res/"
    for f in walkDirRec(prefix & path):
        if not isHiddenFile(f):
            result.add(f.substr(prefix.len))
