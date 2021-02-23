import nimx / view
import tables

type UIResource* = ref object or RootObj
    


#[
    View loading from resources
]#

import nimx / serializers
import nimx / assets / [asset_loading]
import json

proc deserializeView*(jn: JsonNode): View = newJsonDeserializer(jn).deserialize(result)
proc deserializeView*(data: string): View = deserializeView(parseJson(data))

proc loadView*(path: string, onLoad: proc(v: View))=
    loadAsset[JsonNode]("res://" & path) do(jn: JsonNode, err: string):
        var v = deserializeView(jn)
        onLoad(v)

import async

proc loadViewAsync*(path: string): Future[View]=
    let resf = newFuture[View]()
    loadAsset[JsonNode]("res://" & path) do(jn: JsonNode, err: string):
        var v = deserializeView(jn)
        resf.complete(v)

    return resf

# default tabs hacky registering
import nimx/assets/[asset_loading, json_loading]
registerAssetLoader(["nimx"]) do(url: string, callback: proc(j: JsonNode)):
    loadJsonFromURL(url, callback)


