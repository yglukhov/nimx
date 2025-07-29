import std/macros
import ./property_desc
import ../ui_resource
export ui_resource

proc genSerializeCall(view, serializer, field: NimNode, isSerialize: bool): NimNode {.compileTime.}=
  let call = if isSerialize: ident("serialize") else: ident("deserialize")
  let fieldLit = newLit($field)
  # if isSerialize:
  result = quote do:
    `serializer`.`call`(`fieldLit`, `view`.`field`)
  # else:
  #   result = quote do:
  #     `serializer`.`call`(`view`.`field`)

  # echo "genSerializeCall ", repr(result)

macro genSerializers(typdesc: typed{nkSym}): untyped=
  result = nnkStmtList.newNimNode()

  let viewArg = ident("v")
  let serArg = ident("s")

  var serializerBody = nnkStmtList.newNimNode()
  var deserializerBody = nnkStmtList.newNimNode()
  let parent = typdesc.inheritFrom()
  if parent.isNil:
    # echo "no inheritance "
    discard
  else:
    # echo "impl ", treeRepr(parent), " \ninherit from ", $parent
    serializerBody.add quote do:
      procCall `viewArg`.`parent`.serializeFields(`serArg`)

    deserializerBody.add quote do:
      procCall `viewArg`.`parent`.deserializeFields(`serArg`)

  for p in typdesc.propertyDescs():
    let serCall = genSerializeCall(viewArg, serArg, ident(p.name), true)
    let desCall = genSerializeCall(viewArg, serArg, ident(p.name), false)
    serializerBody.add quote do:
      `serCall`
    deserializerBody.add quote do:
      `desCall`

  result.add quote do:
    method serializeFields*(`viewArg`: `typdesc`, `serArg`: Serializer) {.gcsafe.} =
      `serializerBody`

    method deserializeFields*(`viewArg`: `typdesc`, `serArg`: Deserializer) {.gcsafe.}=
      `deserializerBody`

template genSerializeCodeForView*(c: typed) =
  import ../serializers

  genSerializers(c)
