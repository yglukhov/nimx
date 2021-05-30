import std / [ tables, hashes, json ]
import nimx / [ view, serializers, control, types ]
import nimx / assets / asset_loading
import private / async

type
  UIResID = int
  UIActionCallback* = proc()
  UIResource* = ref object of RootObj
    mView: View
    outlets: Table[UIResID, View]
    actions: Table[UIResID, UIActionCallback]
  UIResourceDeserializer = ref object of JsonDeserializer
    deserTable: Table[UIResID, View]


#[
    View loading from resources
]#

proc `@`(str: string): UIResID =
  UIResID(hash(str))

proc deserializeView*(jn: JsonNode): View = newJsonDeserializer(jn).deserialize(result)
proc deserializeView*(data: string): View = deserializeView(parseJson(data))

proc loadAUX[T](path: string, deser: proc(j: JsonNode): T, onLoad: proc(v: T))=
  loadAsset[JsonNode]("res://" & path) do(jn: JsonNode, err: string):
    onLoad(deser(jn))

proc loadAUXAsync[T](path: string, deser: proc(j: JsonNode): T): Future[T] =
  when defined js:
    newPromise() do (resolve: proc(response: T)):
      loadAUX[T](path, deser) do(v: T):
          resolve(v)
  else:
    let resf = newFuture[T]()
    loadAUX[T](path, deser) do(v: T):
      resf.complete(v)
    return resf

proc loadView*(path: string, onLoad: proc(v: View))=
  loadAUX[View](path, deserializeView, onLoad)

proc loadViewAsync*(path: string): Future[View] =
  result = loadAUXAsync[View](path, deserializeView)


method deserializeFields*(v: View, s: Deserializer) =
  var fr: Rect
  s.deserialize("frame", fr)
  v.init(fr)
  var bounds:Rect
  s.deserialize("bounds", bounds)
  v.setBounds(bounds)

  var subviews: seq[View]
  s.deserialize("subviews", subviews)
  for sv in subviews:
      doAssert(not sv.isNil)
      v.addSubview(sv)
  s.deserialize("arMask", v.autoresizingMask)
  s.deserialize("color", v.backgroundColor)

  if s of UIResourceDeserializer:
    var name: string
    s.deserialize("name", name)
    s.UIResourceDeserializer.deserTable[@name] = v
  else:
    s.deserialize("name", v.name)

method init(d: UIResourceDeserializer, n: JsonNode) =
  procCall d.JsonDeserializer.init(n)
  d.deserTable = initTable[UIResID, View]()

proc newJUIResourceDeserializer*(n: JsonNode): UIResourceDeserializer =
  result.new()
  result.init(n)

proc deserializeUIResource*(jn: JsonNode): UIResource =
  result.new()
  let deser = newJUIResourceDeserializer(jn)
  deser.deserialize(result.mView)
  result.outlets = deser.deserTable
  result.actions = initTable[UIResID, UIActionCallback]()

proc deserializeUIResource*(data: string): UIResource = deserializeUIResource(parseJson(data))

proc loadUiResource*(path: string, onLoad: proc(v: UIResource)) =
  loadAUX[UIResource](path, deserializeUIResource, onLoad)

proc loadUiResourceAsync*(path: string): Future[UIResource] =
  result = loadAUXAsync[UIResource](path, deserializeUIResource)

proc getView(ui: UIResource, T: typedesc, id: UIResID): T =
  result = ui.outlets.getOrDefault(id).T

proc getView*(ui: UIResource, T: typedesc, id: string): T =
  result = getView(ui, T, @id)

proc view*(ui: UIResource): View =
  ui.mView

proc onAction*(ui: UIResource, name: string, cb: proc()) =
  let v = ui.getView(Control, name)
  if v.isNil:
    raise newException(Exception, "UIResource can't find view by id " & name)

# default tabs hacky registering
import nimx/assets/[asset_loading, json_loading]
registerAssetLoader(["nimx"]) do(url: string, callback: proc(j: JsonNode)):
  loadJsonFromURL(url, callback)


when isMainModule:
    loadAsset[JsonNode]("res://assets/back.nimx") do(jn: JsonNode, err: string):
        echo "res: " & $jn
    proc a {.async.} = echo await(loadViewAsync("assets/back.nimx")).dump
    asyncCheck a()
