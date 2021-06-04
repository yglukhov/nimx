import nimx / meta_extensions / property_desc
import nimx / ui_resource
export ui_resource
import macros

proc genSerializeCall(view, serializer, field: NimNode): NimNode {.compileTime.}=
    let call = ident("serialize")
    let fieldLit = newLit($field)
    result = quote do:
        `serializer`.`call`(`fieldLit`, `view`.`field`)

proc genDeserializeCall(view, deserializer, field: NimNode): NimNode {.compileTime.}=
    let call = ident("deserialize")
    let gfx = ident("gfx")
    let fieldLit = newLit($field)
    result = quote do:
        `deserializer`.`call`(`fieldLit`, `view`.`field`, `gfx`)

macro genSerializers(typdesc: typed{nkSym}): untyped=
    result = nnkStmtList.newNimNode()

    let viewArg = ident("v")
    let serArg = ident("s")
    let gfx = ident("gfx")

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
            procCall `viewArg`.`parent`.deserializeFields(`serArg`, `gfx`)

    for p in typdesc.propertyDescs():
        let serCall = genSerializeCall(viewArg, serArg, ident(p.name))
        let desCall = genDeserializeCall(viewArg, serArg, ident(p.name))
        serializerBody.add quote do:
            `serCall`
        deserializerBody.add quote do:
            `desCall`

    result.add quote do:
        method serializeFields*(`viewArg`: `typdesc`, `serArg`: Serializer) =
            `serializerBody`

        method deserializeFields*(`viewArg`: `typdesc`, `serArg`: Deserializer, `gfx`: RootRef)=
            `deserializerBody`

template genSerializeCodeForView*(c: typed)=
    import nimx / serializers

    genSerializers(c)
