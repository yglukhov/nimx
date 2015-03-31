import os
import strutils
import sdl2

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
