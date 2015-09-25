import strutils
import system_logger
import streams
import json

when not defined(js):
    import os
    import sdl2

type
    Resource* = ref ResourceObj
    ResourceObj* = object
        size*: int
        data*: pointer

when not defined(android) and not defined(js):
    proc pathForResource(name: string): string =
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
        if RWOpsStream(s).ops != nil:
            discard close(RWOpsStream(s).ops)
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
        if write(s.RWOpsStream.ops, buffer, 1, bufLen) != bufLen:
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

proc loadResourceAsync*(resourceName: string, handler: proc(s: Stream)) =
    when defined(js):
        let cresName : cstring = "res/" & resourceName

        let reqListener = proc(ev: ref RootObj) =
            var data : ref RootObj
            {.emit: "`data` = new DataView(`ev`.target.response);".}
            handler(newStreamWithDataView(data))

        {.emit: """
        var oReq = new XMLHttpRequest();
        oReq.responseType = "arraybuffer";
        oReq.addEventListener('load', `reqListener`);
        oReq.open("GET", `cresName`, true);
        oReq.send();
        """.}
    else:
        handler(streamForResourceWithName(resourceName))

when defined(js):
    proc parseJson(s: Stream, filename: string): JsonNode =
        var fullJson = ""
        while true:
            const chunkSize = 1024
            let r = s.readStr(chunkSize)
            fullJson &= r
            if r.len != chunkSize: break
        result = parseJson(fullJson)

proc loadJsonResourceAsync*(resourceName: string, handler: proc(j: JsonNode)) =
    loadResourceAsync resourceName, proc(s: Stream) =
        handler(parseJson(s, resourceName))
        s.close()

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
