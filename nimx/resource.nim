import strutils
import system_logger
import streams
import json
import tables
import async_http_request
import pathutils
import variant
import typetraits

{.deprecated.} # this file is deprecated. Use the nimx/assets stuff instead.

when defined(js) or defined(emscripten):
    import ospaths

    # Deprecated stuff
    import nimx/assets/web_asset_bundle
    export web_asset_bundle/resourceUrlMapper
    export web_asset_bundle/urlForResourcePath
else:
    import os
    when defined(android):
        import sdl2

type ResourceCache* = ref object
    cache: Table[string, Variant]

var resourceCaches = newSeq[ResourceCache]()

proc newResourceCache*(): ResourceCache =
    result.new()
    result.cache = initTable[string, Variant]()
    resourceCaches.add(result)

proc release*(rc: ResourceCache) =
    for i, r in resourceCaches:
        if r == rc:
            resourceCaches.delete(i)
            break

proc pathForResource*(name: string): string

proc currentResourceCache*(): ResourceCache =
    if resourceCaches.len > 0:
        result = resourceCaches[^1]
    else:
        result = newResourceCache()

template registerResource*(c: ResourceCache, name: string, r: Variant) =
    c.cache[pathForResource(name)] = r

template registerResource*[T](c: ResourceCache, name: string, r: T) =
    c.registerResource(name, newVariant(r))

template registerResource*(name: string, r: Variant) =
    currentResourceCache().registerResource(name, r)

template registerResource*[T](name: string, r: T) =
    registerResource(name, newVariant(r))

var warnWhenResourceNotCached* = false

proc get*[T](c: ResourceCache, name: string): T =
    let p = pathForResource(name)
    let r = c.cache.getOrDefault(p)
    if not r.isEmpty: return r.get(T)

proc findCachedResource*[T](name: string): T =
    let p = pathForResource(name)
    for rc in resourceCaches:
        let v = rc.cache.getOrDefault(p)
        if not v.isEmpty: return v.get(T)

proc findCachedResources*[T](): seq[T] =
    result = newSeq[T]()
    for rc in resourceCaches:
        for v in rc.cache.values:
            if not v.isEmpty and v.ofType(T):
                result.add(v.get(T))

proc resourceNotCached*(name: string) =
    if warnWhenResourceNotCached:
        logi "WARNING: Resource not loaded: ", name

var parentResources = newSeq[string]()

proc pushParentResource*(name: string) =
    parentResources.add(name.parentDir)

proc popParentResource*() =
    parentResources.setLen(parentResources.len - 1)

proc pathForResourceAux(name: string): string =
    when defined(js):
        if name[0] == '/': return name # Absolute
    else:
        if name.isAbsolute: return name
    if parentResources.len > 0 and parentResources[^1] != "":
        return parentResources[^1] / name

    when defined(android):
        result = name
    elif defined(js) or defined(emscripten):
        result = "res/" & name
    else:
        let appDir = getAppDir()
        result = appDir / name
        if fileExists(result): return
        result = appDir /../ "Resources" / name
        if fileExists(result): return
        result = appDir / "res" / name
        if fileExists(result): return
        result = appDir / "resources" / name
        if fileExists(result): return
        result = nil

proc pathForResource*(name: string): string =
    result = pathForResourceAux(name)
    if not result.isNil:
        result.normalizePath()

proc resourceNameForPathAux(path: string): string =
    if parentResources.len > 0:
        return relativePathToPath(parentResources[^1], path)
    result = path

proc resourceNameForPath*(path: string): string =
    result = resourceNameForPathAux(path)

when defined(js):
    import private/js_data_view_stream
else:
    when defined(android):
        type
            RWOpsStream = ref RWOpsStreamObj
            RWOpsStreamObj = object of StreamObj
                ops: RWopsPtr

        proc rwClose(s: Stream) {.nimcall.} =
            let ops = RWOpsStream(s).ops
            if ops != nil:
                discard ops.close(ops)
                RWOpsStream(s).ops = nil
        proc rwAtEnd(s: Stream): bool {.nimcall.} =
            let ops = s.RWOpsStream.ops
            result = ops.size(ops) == ops.seek(ops, 0, 1)
        proc rwSetPosition(s: Stream, pos: int) {.nimcall.} =
            let ops = s.RWOpsStream.ops
            discard ops.seek(ops, pos.int64, 0)
        proc rwGetPosition(s: Stream): int {.nimcall.} =
            let ops = s.RWOpsStream.ops
            result = ops.seek(ops, 0, 1).int

        proc rwReadData(s: Stream, buffer: pointer, bufLen: int): int {.nimcall.} =
            let ops = s.RWOpsStream.ops
            let res = ops.read(ops, buffer, 1, bufLen.csize)
            result = res

        proc rwWriteData(s: Stream, buffer: pointer, bufLen: int) {.nimcall.} =
            let ops = s.RWOpsStream.ops
            if ops.write(ops, buffer, 1, bufLen) != bufLen:
                raise newException(IOError, "cannot write to stream")

        proc newStreamWithRWops*(ops: RWopsPtr): RWOpsStream =
            if ops.isNil: return
            result.new()
            result.ops = ops
            result.closeImpl = cast[type(result.closeImpl)](rwClose)
            result.atEndImpl = cast[type(result.atEndImpl)](rwAtEnd)
            result.setPositionImpl = cast[type(result.setPositionImpl)](rwSetPosition)
            result.getPositionImpl = cast[type(result.getPositionImpl)](rwGetPosition)
            result.readDataImpl = cast[type(result.readDataImpl)](rwReadData)
            result.writeDataImpl = cast[type(result.writeDataImpl)](rwWriteData)

    proc streamForResourceWithPath*(path: string): Stream =
        when defined(android):
            result = newStreamWithRWops(rwFromFile(path, "rb"))
        else:
            result = newFileStream(path, fmRead)
        if result.isNil:
            logi "WARNING: Resource not found: ", path
            raise newException(Exception, "Resource not found")

    proc streamForResourceWithName*(name: string): Stream =
        let p = pathForResource(name)
        if p.isNil:
            raise newException(Exception, "Resource not found: " & name)
        streamForResourceWithPath(p)

type ResourceLoadingError* = object
    description*: string

when defined(js) or defined(emscripten):
    import jsbind
    proc loadJSResourceAsync*(resourceName: string, resourceType: cstring, onProgress: proc(p: float), onError: proc(e: ResourceLoadingError), onComplete: proc(result: JSObj)) =
        let oReq = newXMLHTTPRequest()
        var reqListener: proc()
        var errorListener: proc()
        reqListener = proc() =
            jsUnref(reqListener)
            jsUnref(errorListener)
            handleJSExceptions:
                onComplete(oReq.response)
        errorListener = proc() =
            jsUnref(reqListener)
            jsUnref(errorListener)
            handleJSExceptions:
                var err: ResourceLoadingError
                var statusText = oReq.statusText
                if statusText.isNil: statusText = "(nil)"
                err.description = "XMLHTTPRequest error(" & resourceName & "): " & $oReq.status & ": " & $statusText
                logi "XMLHTTPRequest failure: ", err.description
                onError(err)
        jsRef(reqListener)
        jsRef(errorListener)

        oReq.addEventListener("load", reqListener)
        oReq.addEventListener("error", errorListener)
        oReq.open("GET", urlForResourcePath(pathForResource(resourceName)))
        oReq.responseType = resourceType
        oReq.send()

when defined(emscripten):
    import jsbind/emscripten

proc loadResourceAsync*(resourceName: string, handler: proc(s: Stream)) =
    when defined(js):
        let reqListener = proc(data: JSObj) =
            var dataView : ref RootObj
            {.emit: "`dataView` = new DataView(`data`);".}
            handler(newStreamWithDataView(dataView))
        loadJSResourceAsync(resourceName, "arraybuffer", nil, nil, reqListener)
    elif defined(emscripten):
        let path = pathForResource(resourceName)
        emscripten_async_wget_data(urlForResourcePath(path)) do(data: pointer, sz: cint):
            handleJSExceptions:
                var str = newString(sz)
                copyMem(addr str[0], data, sz)
                let s = newStringStream(str)
                handler(s)
        do():
            handleJSExceptions:
                logi "WARNING: Resource not found: ", path
                handler(nil)
    else:
        handler(streamForResourceWithName(resourceName))

when defined(emscripten) or defined(js):
    proc jsObjToString*(str: JSObj): string =
        # Private. Do not use.
        when defined(emscripten):
            if str.p == 0: return
            let s = EM_ASM_INT("""
            return _nimem_s(_nimem_o[$0]);
            """, str.p)
            result = cast[string](s)
        else:
            if str.isNil: return
            result = $(cast[cstring](str))

proc loadJsonResourceAsync*(resourceName: string, handler: proc(j: JsonNode)) =
    let j = findCachedResource[JsonNode](resourceName)
    if j.isNil:
        when defined(js) or defined(emscripten):
            let reqListener = proc(str: JSObj) =
                handler(parseJson(jsObjToString(str)))
            loadJSResourceAsync(resourceName, "text", nil, nil, reqListener)
        else:
            loadResourceAsync resourceName, proc(s: Stream) =
                handler(parseJson(s, resourceName))
                s.close()
    else:
        handler(j)
