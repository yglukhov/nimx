import asset_loading, asset_cache

const jsEnv = defined(js) or defined(emscripten)
const debugResCache = false

type AssetLoader* = ref object
  when jsEnv:
    remainingItemsToLoad: seq[string]
    itemsLoading: int
  totalSize : int
  loadedSize: int
  itemsToLoad: int
  itemsLoaded: int
  onComplete*: proc() {.gcsafe.}
  onProgress*: proc(p: float) {.gcsafe.}
  assetCache*: AssetCache # Cache to put the loaded resources to. If nil, default cache is used.
  when debugResCache:
    assetsToLoad: seq[string]

proc newAssetLoader*(): AssetLoader {.inline.} =
  result.new()

when jsEnv:
  proc loadNextAssets(ld: AssetLoader) {.gcsafe.}

proc onAssetLoaded(ld: AssetLoader, path: string) =
  when jsEnv: dec ld.itemsLoading
  inc ld.itemsLoaded
  when debugResCache:
    ld.assetsToLoad.keepIf(proc(a: string):bool = a != path)
    echo "REMAINING ITEMS: ", ld.assetsToLoad
  if ld.itemsToLoad == ld.itemsLoaded:
    ld.onComplete()
  if not ld.onProgress.isNil:
    ld.onProgress( ld.itemsLoaded.float / ld.itemsToLoad.float)

  when jsEnv: ld.loadNextAssets()

proc startLoadingAsset(ld: AssetLoader, path: string) =
  let url = "res://" & path
  loadAsset(url, path, ld.assetCache) do():
    ld.onAssetLoaded(path)

when jsEnv:
  proc loadNextAssets(ld: AssetLoader) =
    const parallelLoaders = 10
    while ld.itemsLoading < parallelLoaders and ld.remainingItemsToLoad.len > 0:
      let next = ld.remainingItemsToLoad.pop()
      inc ld.itemsLoading
      ld.startLoadingAsset(next)

proc loadAssets*(ld: AssetLoader, resourceNames: openarray[string]) =
  ld.itemsToLoad += resourceNames.len
  if ld.assetCache.isNil:
    ld.assetCache = newAssetCache()
  when debugResCache:
    ld.assetsToLoad = @resourceNames
  when jsEnv:
    ld.remainingItemsToLoad = @resourceNames
    ld.loadNextAssets()
  else:
    for i in resourceNames:
      ld.startLoadingAsset(i)
