import strutils
import system_logger
import streams
import json
import tables
import async_http_request

when not defined(js):
    import os
    import sdl2

type
    Resource* = ref ResourceObj
    ResourceObj* = object
        size*: int
        data*: pointer

type
    ResourceCache* = ref object
        jsons*: Table[string, JsonNode]
        texts*: Table[string, string]

proc newResourceCache*(): ResourceCache =
    result.new()
    result.jsons = initTable[string, JsonNode]()
    result.texts = initTable[string, string]()

var gResCache* = newResourceCache()


var warnWhenResourceNotCached* = false

when not defined(android) and not defined(js):
    proc pathForResource*(name: string): string =
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

    proc findResourceInFS(resourceName: string): Resource =
        let path = pathForResource(resourceName)
        if path != nil:
            result.new()
            let f = open(path)
            defer: f.close()

            let i = getFileInfo(f)
            result.size = i.size.int
            result.data = alloc(result.size)
            discard f.readBuffer(result.data, result.size)

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

    proc streamForResourceWithName*(name: string): Stream =
        when defined(android):
            result = newStreamWithRWops(rwFromFile(name, "rb"))
        else:
            result = newFileStream(pathForResource(name), fmRead)
        if result.isNil:
            logi "WARNING: Resource not found: ", name

    proc loadResourceByName*(resourceName: string): Resource =
        when defined(android):
            let rw = rwFromFile(resourceName, "rb")
            if rw.isNil:
                return

            result.new()
            result.size = rw.size(rw).int
            result.data = alloc(result.size)

            discard rw.read(rw, result.data, 1, result.size)
            discard rw.close(rw)
        else:
            # Generic resource loading from file
            result = findResourceInFS(resourceName)
        if result.isNil:
            logi "WARNING: resource not found: ", resourceName

    proc freeResource*(res: Resource) {.discardable.} =
        res.size = 0
        dealloc(res.data)

when defined(js):
    type DataViewStream = ref object of Stream
        view: ref RootObj # DataView
        pos: int

    proc abReadData(st: Stream, buffer: pointer, bufLen: int): int =
        let s = DataViewStream(st)
        let oldPos = s.pos
        let view = s.view
        var newPos = oldPos
        {.emit: """
        if (`view`.byteLength == `oldPos`) {
            return 0;
        }
        if (`buffer`.length == 1) {
            if (`buffer`[0] === 0) {
                if (`bufLen` == 1) {
                    // Int8 or char is expected
                    `buffer`[`buffer`_Idx] = `view`.getInt8(`oldPos`);
                    `newPos` += 1;
                    `result` = 1;
                    ok = true;
                }
                else if (`bufLen` == 2) {
                    // Int16 is expected
                    `buffer`[`buffer`_Idx] = `view`.getInt16(`oldPos`);
                    `newPos` += 2;
                    `result` = 2;
                    ok = true;
                }
                else if (`bufLen` == 4) {
                    // Int32 of Float32 expected
                    `buffer`[`buffer`_Idx] = `view`.getInt32(`oldPos`);
                    `newPos` += 4;
                    `result` = 4;
                    ok = true;
                }
            }
            else if (`buffer`[0] === 0.0) {
                if (`bufLen` == 4) {
                    console.log("Reading float32")
                    `buffer`[`buffer`_Idx] = `view`.getFloat32(`oldPos`);
                    `newPos` += 4;
                    `result` = 4;
                    ok = true;
                }
                else if (`bufLen` == 8) {
                    console.log("Reading float64")
                    `buffer`[`buffer`_Idx] = `view`.getFloat64(`oldPos`);
                    `newPos` += 8;
                    `result` = 8;
                    ok = true;
                }
            }
        }
        else if (`buffer`.length - 1 == `bufLen`) {
            // String is expected
            var toRead = `bufLen`;
            if (`oldPos` + `bufLen` >= `view`.byteLength) `bufLen` = `view`.byteLength - `oldPos`;
            for (var i = 0; i < `bufLen`; ++i) {
                `buffer`[i] = `view`.getInt8(`oldPos` + i);
            }
            `newPos` += `bufLen`;
            `result` = `bufLen`;
            ok = true;
        }

        if (!ok) {
            console.log("buf type: ", typeof(`buffer`))
            console.log("buf: ", `buffer`);
            console.log("idx: ", `buffer`_Idx);
            console.log("len: ", `bufLen`);
        }
        """.}
        s.pos = newPos

    proc newStreamWithDataView(v: ref RootObj): Stream =
        let r = DataViewStream.new()
        r.view = v
        r.readDataImpl = abReadData
        #r.atEndImpl
        result = r

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
        oReq.open("GET", "res/" & resourceName)
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
    let j = gResCache.jsons.getOrDefault(resourceName)
    if j.isNil:
        if warnWhenResourceNotCached:
            logi "WARNING: Resource not loaded: ", resourceName
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

when isMainModule and not defined(js):
    # Test for non-existing resource
    let r1: Resource = loadResourceByName("non-existing")
    assert(r1 == nil)

    # Test for existing resource
    discard execShellCmd("mkdir -p " & getAppDir() & "/resources/nested/")
    discard execShellCmd("(echo \"asdsadasdsadasdadsad\") > " & getAppDir() & "/resources/nested/somefile.png")

    let r2: Resource = loadResourceByName("somefile.png")
    assert(r2 != nil)
    freeResource(r2)

    discard execShellCmd("rm -r " & getAppDir() & "/resources/")

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
