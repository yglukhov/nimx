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

proc deserializeView*(jn: JsonNode, gfx: GraphicsContext): View =
  newJsonDeserializer(jn).deserialize(result, RootRef(gfx))

proc deserializeView*(data: string, gfx: GraphicsContext): View =
  deserializeView(parseJson(data), gfx)

proc loadAUX[T](path: string, deser: proc(j: JsonNode, gfx: GraphicsContext): T, gfx: GraphicsContext, onLoad: proc(v: T))=
  loadAsset[JsonNode]("res://" & path) do(jn: JsonNode, err: string):
    onLoad(deser(jn, gfx))

proc loadAUXAsync[T](path: string, deser: proc(j: JsonNode, gfx: GraphicsContext): T, gfx: GraphicsContext): Future[T] =
  when defined js:
    newPromise() do (resolve: proc(response: T)):
      loadAUX[T](path, deser, gfx) do(v: T):
          resolve(v)
  else:
    let resf = newFuture[T]()
    loadAUX[T](path, deser, gfx) do(v: T):
      resf.complete(v)
    return resf

proc loadView*(path: string, gfx: GraphicsContext, onLoad: proc(v: View)) =
  loadAUX[View](path, deserializeView, gfx, onLoad)

proc loadViewAsync*(path: string, gfx: GraphicsContext): Future[View] =
  result = loadAUXAsync[View](path, deserializeView, gfx)


method deserializeFields*(v: View, s: Deserializer, gfx: RootRef) =
  assert not gfx.isNil
  var fr: Rect
  s.deserialize("frame", fr)
  v.init(GraphicsContext(gfx), fr)
  var bounds:Rect
  s.deserialize("bounds", bounds)
  v.setBounds(bounds)

  var subviews: seq[View]
  s.deserialize("subviews", subviews, GraphicsContext(gfx))
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

proc deserializeUIResource*(jn: JsonNode, gfx: GraphicsContext): UIResource =
  result.new()
  let deser = newJUIResourceDeserializer(jn)
  deser.deserialize(result.mView, gfx)
  result.outlets = deser.deserTable
  result.actions = initTable[UIResID, UIActionCallback]()

proc deserializeUIResource*(data: string, gfx: GraphicsContext): UIResource =
  deserializeUIResource(parseJson(data), gfx)

proc loadUiResource*(path: string, gfx: GraphicsContext, onLoad: proc(v: UIResource)) =
  loadAUX[UIResource](path, deserializeUIResource, gfx, onLoad)

proc loadUiResourceAsync*(path: string, gfx: GraphicsContext): Future[UIResource] =
  result = loadAUXAsync[UIResource](path, deserializeUIResource, gfx)

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
