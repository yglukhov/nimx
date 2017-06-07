import ospaths, strutils
import abstract_asset_bundle, url_stream

import nimx.pathutils

var resourceUrlMapper*: proc(p: string): string # Deprecated

when defined(js) or defined(emscripten):
    proc urlForResourcePath*(path: string): string {.deprecated.} =
        if resourceUrlMapper.isNil:
            path
        else:
            resourceUrlMapper(path)

type WebAssetBundle* = ref object of AssetBundle
    mHref: string
    mBaseUrl: string

proc newWebAssetBundle*(): WebAssetBundle =
    result.new()
    result.mHref = getCurrentHref().parentDir()
    result.mBaseUrl = result.mHref / "res"

method urlForPath*(ab: WebAssetBundle, path: string): string =
    if resourceUrlMapper.isNil:
        result = ab.mBaseUrl / path
    else:
        result = resourceUrlMapper("res" / path)
        if not result.startsWith("http"):
            result = ab.mHref / result
