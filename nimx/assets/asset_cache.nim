import tables
import variant

type AssetCache* = TableRef[string, Variant]

template newAssetCache*(): AssetCache = newTable[string, Variant]()

template registerAsset*(ac: AssetCache, path: string, asset: typed) =
    ac[path] = newVariant(asset)
