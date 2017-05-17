import tables, ospaths
import variant

type
    AssetBundle* = ref object of RootObj

proc abstractMethod() = raise newException(Exception, "Abstract method called")

method isEnumerable*(ab: AssetBundle): bool {.base.} = true
method forEachAsset*(ab: AssetBundle, action: proc(path: string): bool) {.base.} = abstractMethod()
method urlForPath*(ab: AssetBundle, path: string): string {.base, gcsafe.} = abstractMethod()
