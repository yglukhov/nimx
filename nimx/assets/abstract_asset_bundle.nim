import tables, os
import variant

type
    AssetBundle* = ref object of RootObj

proc abstractMethod() = raise newException(Exception, "Abstract method called")

method allAssets*(ab: AssetBundle): seq[string] {.base.} = abstractMethod()
method urlForPath*(ab: AssetBundle, path: string): string {.base, gcsafe.} = abstractMethod()

proc allAssetsWithBasePath*(ab: AssetBundle, path: string): seq[string] =
    result = ab.allAssets()
    for i in 0 ..< result.len:
        result[i] = path & '/' & result[i]
