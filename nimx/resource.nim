import os
import streams

const 
    ASSET_MANAGER_HEADER = "<android/asset_manager.h>"

type 
    Resource* = ref ResourceObj
    ResourceObj* = object
        size*: BiggestInt
        data*: pointer

    AAssetManagerObj {.final, header: ASSET_MANAGER_HEADER, importc: "AAssetManager".} = object
    AAssetManager = ptr AAssetManagerObj
    
    AAssetDirObj {.final, header: ASSET_MANAGER_HEADER, importc: "AAssetDir".} = object
    AAssetDir = ptr AAssetDirObj

    AAssetObj {.final, header: ASSET_MANAGER_HEADER, importc: "AAsset".} = object
    AAsset = ptr AAssetObj

# Android AssetManager methods
proc openDir(mgr: AAssetManager, dirName: cstring): AAssetDir {.header: ASSET_MANAGER_HEADER, importc: "AAssetManager_openDir".}
proc open(mgr: AAssetManager, filename: cstring, mode: int): AAsset {.header: ASSET_MANAGER_HEADER, importc: "AAssetManager_open".}

# Android AssetDir methods
proc getNextFileName(assetDir: AAssetDir): cstring {.header: ASSET_MANAGER_HEADER, importc: "AAssetDir_getNextFileName".}
proc rewind(assetDir: AAssetDir) {.header: ASSET_MANAGER_HEADER, importc: "AAssetDir_rewind".}
proc close(assetDir: AAssetDir) {.header: ASSET_MANAGER_HEADER, importc: "AAssetDir_close".}

proc read(asset: AAsset, buf: pointer, count: BiggestInt): int {.header: ASSET_MANAGER_HEADER, importc: "AAsset_read".}
proc seek(asset: AAsset, offset: BiggestInt, whence: BiggestInt): BiggestInt {.header: ASSET_MANAGER_HEADER, importc: "AAsset_seek".}
proc close(asset: AAsset) {.header: ASSET_MANAGER_HEADER, importc: "AAsset_close".}
proc getBuffer(asset: AAsset): cstring {.header: ASSET_MANAGER_HEADER, importc: "AAsset_getBuffer".}
proc getLength(asset: AAsset): BiggestInt {.header: ASSET_MANAGER_HEADER, importc: "AAsset_getLength".}
proc getRemainingLength(asset: AAsset): BiggestInt {.header: ASSET_MANAGER_HEADER, importc: "AAsset_getRemainingLength".}
proc openFileDescriptor(asset: AAsset, outStart: ptr BiggestInt, outLength: ptr BiggestInt): BiggestInt {.
    header: ASSET_MANAGER_HEADER, importc: "AAsset_openFileDescriptor".}
proc isAllocated(asset: AAsset): BiggestInt {.header: ASSET_MANAGER_HEADER, importc: "AAsset_isAllocated".}


proc walkAPKResources(mgr: AAssetManager, node: string): string =
    result = ""


proc loadResource*(resourceName: string): Resource =
    when defined(android):
        # Android code for resources loading
        result = Resource.new
    elif defined(ios) or defined(macos) or defined(linux) or defined(win32):
        # Generic resource loading from file
        result = Resource.new

        var assetManager: AAssetManager
        
        # open root folder
        assetManager.openDir("") 

        let f: File = open(path)
        defer: f.close

        let i: FileInfo = getFileInfo(f)

        let source = newFileStream(path, fmRead)
        defer: source.close
        
        result.size = i.size
        source.readData(result.data, result.size)
