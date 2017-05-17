import ospaths, os
import abstract_asset_bundle

type NativeAssetBundle* = ref object of AssetBundle
    mBaseUrl: string

proc newNativeAssetBundle*(): NativeAssetBundle =
    result.new()
    when defined(macosx):
        result.mBaseUrl = "file://" & getAppDir() /../ "Resources"
    elif defined(ios):
        result.mBaseUrl = "file://" & getAppDir()
    else:
        result.mBaseUrl = "file://" & getAppDir() / "res"

method urlForPath*(ab: NativeAssetBundle, path: string): string =
    return ab.mBaseUrl / path
