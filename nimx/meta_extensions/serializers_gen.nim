import nimx / meta_extensions / property_desc
import nimx / ui_resource
export ui_resource
import macros

proc genSerializeCall(view, serializer, field: NimNode, isSerialize: bool): NimNode {.compileTime.}=
    let call = if isSerialize: ident("serialize") else: ident("deserialize")
    let fieldLit = newLit($field)
    # if isSerialize:
    result = quote do:
        `serializer`.`call`(`fieldLit`, `view`.`field`)
    # else:
    #     result = quote do:
    #         `serializer`.`call`(`view`.`field`)

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
        method serializeFields*(`viewArg`: `typdesc`, `serArg`: Serializer) =
            `serializerBody`

        method deserializeFields*(`viewArg`: `typdesc`, `serArg`: Deserializer)=
            `deserializerBody`

template genSerializeCodeForView*(c: typed)=
    import nimx / serializers

    genSerializers(c)
