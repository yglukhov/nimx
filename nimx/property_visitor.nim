import nimx.types

import tables
import variant

type SetterAndGetter*[T] = tuple[setter: proc(v: T), getter: proc(): T]

type PropertyFlag* = enum
    pfEditable
    pfAnimatable

type EnumValue* = object
    possibleValues*: Table[string, int]
    curValue*: int

type PropertyVisitor* = object of RootObj
    qualifiers: seq[string]
    requireSetter*: bool
    requireGetter*: bool
    requireName*: bool
    flags*: set[PropertyFlag]

    setterAndGetter*: Variant

    name*: string
    commit*: proc()
    onChangeCallback*: proc()

proc clear*(p: var PropertyVisitor) =
    p.setterAndGetter = newVariant()

proc pushQualifier*(p: var PropertyVisitor, q: string) =
    if p.qualifiers.isNil:
        p.qualifiers = newSeq[string]()
    p.qualifiers.add(q)

proc popQualifier*(p: var PropertyVisitor) =
    p.qualifiers.setLen(p.qualifiers.len - 1)

template visitProperty*(p: PropertyVisitor, propName: string, s: untyped, defFlags: set[PropertyFlag] = { pfEditable, pfAnimatable }) =
    if (defFlags * p.flags) != {}:
        when s is enum:
            var sng : SetterAndGetter[EnumValue]
        else:
            var sng : SetterAndGetter[type(s)]

        if p.requireSetter:
            when s is enum:
                sng.setter = proc(v: EnumValue) =
                    s = type(s)(v.curValue)
            else:
                sng.setter = proc(v: type(s)) = s = v
        if p.requireGetter:
            when s is enum:
                sng.getter = proc(): EnumValue =
                    result.possibleValues = initTable[string, int]()
                    for i in low(type(s)) .. high(type(s)):
                        result.possibleValues[$i] = ord(i)
                    result.curValue = ord(s)
            else:
                sng.getter = proc(): type(s) = s
        if p.requireName:
            p.name = propName
        p.setterAndGetter = newVariant(sng)
        p.onChangeCallback = nil
        p.commit()

template visitProperty*(p: PropertyVisitor, propName: string, s: untyped, onChange: proc()) =
    var defFlags = { pfEditable, pfAnimatable }
    if (defFlags * p.flags) != {}:
        when s is enum:
            var sng : SetterAndGetter[EnumValue]
        else:
            var sng : SetterAndGetter[type(s)]

        if p.requireSetter:
            when s is enum:
                sng.setter = proc(v: EnumValue) =
                    s = type(s)(v.curValue)
            else:
                sng.setter = proc(v: type(s)) = s = v
        if p.requireGetter:
            when s is enum:
                sng.getter = proc(): EnumValue =
                    result.possibleValues = initTable[string, int]()
                    for i in low(type(s)) .. high(type(s)):
                        result.possibleValues[$i] = ord(i)
                    result.curValue = ord(s)
            else:
                sng.getter = proc(): type(s) = s
        if p.requireName:
            p.name = propName
        p.setterAndGetter = newVariant(sng)
        p.onChangeCallback = onChange

        p.commit()
