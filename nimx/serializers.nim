import json
type Serializer* = ref object of RootObj
    curKey*: string

template abstractCall() = raise newException(Exception, "Abstract method called")

# Methods to override
method serializeNil*(s: Serializer) {.base.} = abstractCall()
method serialize*(s: Serializer, v: bool) {.base.} = abstractCall()

method serialize(s: Serializer, v: int8) {.base.} = abstractCall()
method serialize(s: Serializer, v: int16) {.base.} = abstractCall()
method serialize(s: Serializer, v: int32) {.base.} = abstractCall()
method serialize(s: Serializer, v: int64) {.base.} = abstractCall()

method serialize(s: Serializer, v: uint8) {.base.} = abstractCall()
method serialize(s: Serializer, v: uint16) {.base.} = abstractCall()
method serialize(s: Serializer, v: uint32) {.base.} = abstractCall()
method serialize(s: Serializer, v: uint64) {.base.} = abstractCall()

method serialize(s: Serializer, v: float32) {.base.} = abstractCall()
method serialize(s: Serializer, v: float64) {.base.} = abstractCall()

method serialize*(s: Serializer, v: string) {.base.} = abstractCall()

method beginObject*(s: Serializer) {.base.} = abstractCall()
method beginArray*(s: Serializer) {.base.} = abstractCall()
method endObjectOrArray*(s: Serializer) {.base.} = abstractCall()

template serialize*(s: Serializer, v: int) =
    when sizeof(int) <= 4:
        s.serialize(int32(v))
    else:
        s.serialize(int64(v))

proc serialize*[T](s: Serializer, k: string, v: T) {.inline.} =
    s.curKey = k
    s.serialize(v)

method serializeFields*(o: RootRef, s: Serializer) {.base.} = discard

proc serialize*[T](s: Serializer, o: T) =
    when o is object | tuple:
        s.beginObject()
        for k, v in fieldPairs(o):
            when compiles((proc() =
                    let t = v)()):
                s.serialize(k, v)
        s.endObjectOrArray()
    elif o is array | openarray | seq:
        s.beginArray()
        for i, v in o:
            s.serialize(v)
        s.endObjectOrArray()
    elif o is ref object:
        if o.isNil:
            s.serializeNil()
        else:
            # TODO: Implement shared references...
            s.beginObject()
            when o is RootRef:
                s.serialize("_c", o.className)
                o.serializeFields(s)
            else:
                for k, v in fieldPairs(o[]):
                    when compiles((proc() =
                            let t = v)()):
                        s.serialize(k, v)
            s.endObjectOrArray()
    elif o is ref:
        # TODO: Implement shared references...
        s.serialize(o[])
    elif o is enum:
        s.serialize(int(o))
    elif o is set:
        s.beginArray()
        for i in o:
            s.serialize(int(i))
        s.endObjectOrArray()
    elif o is (proc):
        discard
    else:
        proc cannotSerialize(i: int) = discard
        cannotSerialize(o)
        {.error: "oops: " & o.}

################################################################################
type Deserializer* = ref object of RootObj
    curKey*: string
    curIndex*: int

# Methods to override
method deserialize*(s: Deserializer, v: var bool) {.base.} = abstractCall()

method deserialize(s: Deserializer, v: var int8) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var int16) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var int32) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var int64) {.base.} = abstractCall()

method deserialize(s: Deserializer, v: var uint8) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var uint16) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var uint32) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var uint64) {.base.} = abstractCall()

method deserialize(s: Deserializer, v: var float32) {.base.} = abstractCall()
method deserialize(s: Deserializer, v: var float64) {.base.} = abstractCall()

method deserialize*(s: Deserializer, v: var string) {.base.} = abstractCall()

method beginObject*(s: Deserializer) {.base.} = abstractCall()
method beginArray*(s: Deserializer): int {.base.} = -1
method endObjectOrArray*(s: Deserializer) {.base.} = abstractCall()

proc deserialize*[T](s: Deserializer, k: string, v: var T) {.inline.} =
    s.curKey = k
    s.deserialize(v)

template deserialize*(s: Deserializer, v: var int) =
    when sizeof(int) <= 4:
        var t: int32
        s.deserialize(t)
        v = int(t)
    else:
        var t: int64
        s.deserialize(t)
        v = int(t)

method deserializeFields*(o: RootRef, s: Deserializer) {.base.} = discard

template typeOfSetElem[T](s: set[T]): typedesc = T

proc deserialize*[T](s: Deserializer, o: var T) =
    when o is object | tuple:
        s.beginObject()
        for k, v in fieldPairs(o):
            when compiles(s.deserialize(k, v)):
                s.deserialize(k, v)
        s.endObjectOrArray()
    elif o is array:
        if s.beginArray() != o.len: raiseException(Exception, "wrong array length")
        for i in 0 ..< o.len:
            s.curIndex = i
            s.deserialize(o[i])
        s.endObjectOrArray()
    elif o is seq:
        let ln = s.beginArray()
        o.setLen(ln)
        for i in 0 ..< ln:
            s.curIndex = i
            s.deserialize(o[i])
        s.endObjectOrArray()
    elif o is ref object:
        # TODO: Implement shared references...
        s.beginObject()
        when o is RootRef:
            var cn : string
            s.deserialize("_c", cn)
            o = T(newObjectOfClass(cn))
            o.deserializeFields(s)
        else:
            for k, v in fieldPairs(o[]):
                when compiles(s.deserialize(k, v)):
                    s.deserialize(k, v)
        s.endObjectOrArray()
    elif o is ref:
        # TODO: Implement shared references...
        o.new()
        s.deserialize(o[])
    elif o is enum:
        var i : int
        s.deserialize(i)
        o = T(i)
    elif o is set:
        let ln = s.beginArray()
        for i in 0 ..< ln:
            var val : int
            s.curIndex = i
            s.deserialize(val)
            o.incl(typeOfSetElem(o)(val))
        s.endObjectOrArray()
    elif o is (proc):
        discard
    else:
        proc cannotDeserialize(i: int) = discard
        cannotDeserialize(o)
        {.error: "oops: " & o.}

################################################################################
type JsonSerializer* = ref object of Serializer
    nodeStack: seq[JsonNode]
    curIndex: int

proc newJsonSerializer*(): JsonSerializer =
    result.new()

proc serializeJsonNode(s: JsonSerializer, n: JsonNode) =
    let ln = s.nodeStack[^1]
    if ln.kind == JObject:
        ln[s.curKey] = n
    elif ln.kind == JArray:
        ln.add(n)
    else:
        assert(false, "Wrong node kind")

proc pushJsonNode(s: JsonSerializer, n: JsonNode) =
    if s.nodeStack.len > 0:
        s.serializeJsonNode(n)
        s.nodeStack.add(n)
    else:
        s.nodeStack.add(n)

method serializeNil*(s: JsonSerializer) = s.serializeJsonNode(newJNull())
method serialize(s: JsonSerializer, v: bool) = s.serializeJsonNode(%v)

method serialize(s: JsonSerializer, v: int8) = s.serializeJsonNode(%v)
method serialize(s: JsonSerializer, v: int16) = s.serializeJsonNode(%v)
method serialize(s: JsonSerializer, v: int32) = s.serializeJsonNode(%v)
method serialize(s: JsonSerializer, v: int64) = s.serializeJsonNode(%v)

method serialize(s: JsonSerializer, v: uint8) = s.serializeJsonNode(%(v.int8))
method serialize(s: JsonSerializer, v: uint16) = s.serializeJsonNode(%(v.int16))
method serialize(s: JsonSerializer, v: uint32) = s.serializeJsonNode(%(v.int32))
method serialize(s: JsonSerializer, v: uint64) = s.serializeJsonNode(%(v.int64))

method serialize(s: JsonSerializer, v: float32) = s.serializeJsonNode(%v)
method serialize(s: JsonSerializer, v: float64) = s.serializeJsonNode(%v)

method serialize(s: JsonSerializer, v: string) = s.serializeJsonNode(%v)

method beginObject*(s: JsonSerializer) = s.pushJsonNode(newJObject())
method beginArray*(s: JsonSerializer) = s.pushJsonNode(newJArray())
method endObjectOrArray*(s: JsonSerializer) =
    let ln = s.nodeStack.len
    if ln > 1: s.nodeStack.setLen(ln - 1)

proc jsonNode*(s: JsonSerializer): JsonNode =
    assert(s.nodeStack.len == 1, "Serialization incomplete")
    result = s.nodeStack[0]
################################################################################

type JsonDeserializer* = ref object of Deserializer
    nodeStack: seq[JsonNode]
    node: JsonNode

proc newJsonDeserializer*(n: JsonNode): JsonDeserializer =
    result.new()
    result.nodeStack = @[]
    result.node = n

proc deserializeJsonNode(s: JsonDeserializer): JsonNode =
    let ln = s.nodeStack[^1]
    if ln.kind == JObject:
        assert(s.curKey.len != 0)

        result = ln{s.curKey}
    elif ln.kind == JArray:
        result = ln[s.curIndex]
    else:
        assert(false, "Wrong node kind")

proc pushJsonNode(s: JsonDeserializer) =
    if s.nodeStack.len == 0:
        s.nodeStack.add(s.node)
    else:
        let n = s.deserializeJsonNode()
        s.nodeStack.add(n)

method deserialize(s: JsonDeserializer, v: var bool) = v = s.deserializeJsonNode().getBool()

method deserialize(s: JsonDeserializer, v: var int8) =
    v = s.deserializeJsonNode.getInt().int8
method deserialize(s: JsonDeserializer, v: var int16) =
    v = s.deserializeJsonNode.getInt().int16
method deserialize(s: JsonDeserializer, v: var int32) =
    v = s.deserializeJsonNode.getint().int32
method deserialize(s: JsonDeserializer, v: var int64) =
    v = s.deserializeJsonNode.getBiggestInt().int64

method deserialize(s: JsonDeserializer, v: var uint8) =
    v = s.deserializeJsonNode.getint().uint8
method deserialize(s: JsonDeserializer, v: var uint16) =
    v = s.deserializeJsonNode.getInt().uint16
method deserialize(s: JsonDeserializer, v: var uint32) =
    v = s.deserializeJsonNode.getInt().uint32
method deserialize(s: JsonDeserializer, v: var uint64) =
    v = s.deserializeJsonNode.getBiggestInt().uint64

method deserialize(s: JsonDeserializer, v: var float32) =
    v = s.deserializeJsonNode.getFNum().float32
method deserialize(s: JsonDeserializer, v: var float64) =
    v = s.deserializeJsonNode.getFNum().float64

method deserialize(s: JsonDeserializer, v: var string) =
    let n = s.deserializeJsonNode()
    if n.kind == JString:
        v = n.str

method beginObject*(s: JsonDeserializer) = s.pushJsonNode()

method beginArray*(s: JsonDeserializer): int =
    s.pushJsonNode()
    let ln = s.nodeStack[^1]
    if not ln.isNil:
        result = ln.len

method endObjectOrArray*(s: JsonDeserializer) =
    let ln = s.nodeStack.len
    if ln > 1: s.nodeStack.setLen(ln - 1)

################################################################################


when isMainModule:
    type
        MyObj = ref object
            yo: int
            children: seq[MyObj]

        MyObj2 = object
            hi: string
            o: MyObj

    # proc serialize(s: Serializer, v: MyObj) =
    #     s.beginObject()
    #     s.serialize("hello", 5)
    #     s.endObjectOrArray()

    proc newMyObj(i: int): MyObj =
        result.new()
        result.yo = i
        result.children = newSeq[MyObj]()

    var o: MyObj2
    o.hi = "hello"
    o.o = newMyObj(5)
    o.o.children.add(newMyObj(3))
    o.o.children.add(newMyObj(4))
    o.o.children = nil

    o.o.yo = 5

    var s: JsonSerializer
    s.new()

    s.serialize(o)
    echo s.jsonNode()
