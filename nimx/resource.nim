import os
import strutils
import sdl2
import system_logger

type
    Resource* = ref ResourceObj
    ResourceObj* = object
        size*: int
        data*: pointer

when not defined(android):
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
    import streams
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

when isMainModule:
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
