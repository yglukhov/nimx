import strutils
import system_logger
import streams
import json
import tables
import async_http_request
import pathutils

when not defined(js):
    import os
    import sdl2
else:
    # What a hacky way to import ospaths...
    include "system/inclrtl"
    include ospaths

type ResourceCache*[T] = object
    cache: Table[string, T]

proc initResourceCache*[T](): ResourceCache[T] =
    result.cache = initTable[string, T]()

proc pathForResource*(name: string): string

template registerResource*[T](c: var ResourceCache[T], name: string, r: T) =
    c.cache[pathForResource(name)] = r

var warnWhenResourceNotCached* = false

template get*[T](c: var ResourceCache[T], name: string): T =
    let p = pathForResource(name)
    let r = c.cache.getOrDefault(p)
    if r.isNil and warnWhenResourceNotCached:
        logi "WARNING: Resource not cached: ", name, "(", if p.isNil: "nil" else: p, ")"
    r

var gJsonResCache* = initResourceCache[JsonNode]()

proc resourceNotCached*(name: string) =
    if warnWhenResourceNotCached:
        logi "WARNING: Resource not loaded: ", name

var parentResources = newSeq[string]()

proc pushParentResource*(name: string) =
    parentResources.add(pathForResource(name).parentDir)

proc popParentResource*() =
    parentResources.setLen(parentResources.len - 1)

proc pathForResourceAux(name: string): string =
    when defined(js):
        if name[0] == '/': return name # Absolute
    else:
        if name.isAbsolute: return name
    if parentResources.len > 0:
        return parentResources[^1] / name

    when defined(android):
        result = name
    elif defined(js):
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

when not defined(js):
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

    proc streamForResourceWithName*(name: string): Stream =
        streamForResourceWithPath(pathForResource(name))

when defined(js):
    import private.js_data_view_stream

type ResourceLoadingError* = object
    description*: string

when defined js:
    proc loadJSResourceAsync*(resourceName: string, resourceType: cstring, onProgress: proc(p: float), onError: proc(e: ResourceLoadingError), onComplete: proc(result: ref RootObj)) =
        let reqListener = proc(ev: ref RootObj) =
            var data : ref RootObj
            {.emit: "`data` = `ev`.target.response;".}
            onComplete(data)

        let oReq = newXMLHTTPRequest()
        oReq.responseType = resourceType
        oReq.addEventListener("load", reqListener)
        oReq.open("GET", pathForResource(resourceName))
        oReq.send()

proc loadResourceAsync*(resourceName: string, handler: proc(s: Stream)) =
    when defined(js):
        let reqListener = proc(data: ref RootObj) =
            var dataView : ref RootObj
            {.emit: "`dataView` = new DataView(`data`);".}
            handler(newStreamWithDataView(dataView))
        loadJSResourceAsync(resourceName, "arraybuffer", nil, nil, reqListener)
    else:
        handler(streamForResourceWithName(resourceName))

proc loadJsonResourceAsync*(resourceName: string, handler: proc(j: JsonNode)) =
    let j = gJsonResCache.get(resourceName)
    if j.isNil:
        when defined js:
            let reqListener = proc(data: ref RootObj) =
                var jsonstring = cast[cstring](data)
                handler(parseJson($jsonstring))
            loadJSResourceAsync(resourceName, "text", nil, nil, reqListener)
        else:
            loadResourceAsync resourceName, proc(s: Stream) =
                handler(parseJson(s, resourceName))
                s.close()
    else:
        handler(j)

when isMainModule and defined(js):
    var dv : ref RootObj
    {.emit: """
    var buffer = new ArrayBuffer(32);
    var tmpdv = new DataView(buffer, 0);

    tmpdv.setInt16(0, 42);
    tmpdv.getInt16(0); //42

    tmpdv.setInt8(2, "h".charCodeAt(0));
    tmpdv.setInt8(3, "e".charCodeAt(0));
    tmpdv.setInt8(4, "l".charCodeAt(0));
    tmpdv.setInt8(5, "l".charCodeAt(0));
    tmpdv.setInt8(6, "o".charCodeAt(0));

    tmpdv.setFloat32(7, 3.14);
    tmpdv.setFloat64(11, 3.14);

    `dv`[0] = tmpdv;
    """.}
    let s = newStreamWithDataView(dv)
    try:
        echo s.readInt16()
        echo s.readStr(4)
        echo s.readChar()
        echo s.readFloat32()
        echo s.readFloat64()
    except:
        echo "Exception caught"
