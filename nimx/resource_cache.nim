import resource
import tables
import json
import strutils
import image
import streams
import system_logger
import types
import sequtils

type ResourceLoader* = ref object
    totalSize : int
    loadedSize: int
    itemsToLoad: int
    onComplete*: proc()
    resourcesToLoad: seq[string]

proc getFileExtension(name: string): string =
    let p = name.rfind('.')
    if p != -1:
        result = name.substr(p + 1)

proc onResourceLoaded(ld: ResourceLoader) =
    dec ld.itemsToLoad
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
                    ld.onResourceLoaded()
                {.emit:"""
                var im = new Image();
                im.onload = function(){`onImLoad`(im);};
                im.src = window.URL.createObjectURL(`r`);
                """.}

            loadJSResourceAsync(name, "blob", nil, nil, handler)
        else:
            registerImageInCache(name, imageWithResource(name))
            ld.onResourceLoaded()

    of "json", "zsm":
        loadJsonResourceAsync(name, proc(j: JsonNode) =
            gResCache.jsons[name] = j
            ld.onResourceLoaded()
        )
    of "obj", "txt":
        when defined(js):
            proc handler(r: ref RootObj) =
                var jsonstring = cast[cstring](r)
                gResCache.texts[name] = $jsonstring
                ld.onResourceLoaded()

            loadJSResourceAsync(name, "text", nil, nil, handler)
        else:
            loadResourceAsync name, proc(s: Stream) =
                gResCache.texts[name] = s.readAll()
                s.close()
                ld.onResourceLoaded()
    else:
        ld.onResourceLoaded()
        logi "WARNING: Unknown resource type: ", name
        #raise newException(Exception, "Unknown resource type: " & name)

proc preloadResources*(ld: ResourceLoader, resourceNames: openarray[string]) =
    ld.itemsToLoad += resourceNames.len
    for i in resourceNames:
        ld.startPreloadingResource(i)

proc ctReadDir*(root, path: string, res: var seq[string]) {.compileTime.} =
    when defined(windows):
        discard
    else:
        let rp = root & "/" & path
        let lsOutput = staticExec("ls " & rp)
        let files = lsOutput.splitLines()
        for f in files:
            var fp = if path.len > 0: path & "/" & f else: f
            if f.getFileExtension().isNil:
                ctReadDir(root, fp, res)
            else:
                res.add(fp)

proc getResourceNames*(path: string = ""): seq[string] {.compileTime.} =
    result = newSeq[string]()
    ctReadDir("res", path, result)
