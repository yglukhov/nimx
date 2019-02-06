import tables
import nimx/view
import nimx/text_field
import nimx/font
import nimx/property_visitor

import variant

type PropertyEditorView* = ref object of View
    onChange*: proc()
    changeInspector*: proc()

var propEditors = initTable[TypeId, proc(editedObject: Variant, v: Variant): PropertyEditorView]()

proc registerPropertyEditor*[T](createView: proc(editedObject: Variant, setter: proc(s: T), getter: proc(): T): PropertyEditorView) =
    propEditors[getTypeId(SetterAndGetter[T])] = proc(n: Variant, v: Variant): PropertyEditorView =
        let sng = v.get(SetterAndGetter[T])
        result = createView(n, sng.setter, sng.getter)

proc registerPropertyEditor*[T](createView: proc(setter: proc(s: T), getter: proc(): T): PropertyEditorView) =
    propEditors[getTypeId(SetterAndGetter[T])] = proc(n: Variant, v: Variant): PropertyEditorView =
        let sng = v.get(SetterAndGetter[T])
        result = createView(sng.setter, sng.getter)

var gEditorFont: Font

proc editorFont*(): Font =
    if gEditorFont.isNil: gEditorFont = systemFontOfSize(14)
    result = gEditorFont

const editorRowHeight* = 16

proc propertyEditorForProperty*(editedObject: Variant, title: string, v: Variant, notUsed, changeInspectorCallback: proc() = nil): View =
    let creator = propEditors.getOrDefault(v.typeId)
    result = View.new(newRect(0, 0, 328, editorRowHeight))
    result.name = "'" & title & "'"
    result.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    let label = newLabel(newRect(0, 0, 100, editorRowHeight))
    label.textColor = blackColor()
    label.name = "label"
    label.text = title & ":"
    label.font = editorFont()
    result.addSubview(label)
    if creator.isNil:
        label.text = title & " - Unknown property"
    else:
        let editor = creator(editedObject, v)
        editor.name = "editor"
        editor.setFrameOrigin(newPoint(label.frame.width, 0))
        var sz = newSize(result.bounds.width - label.frame.width, editor.frame.height)
        editor.setFrameSize(sz)
        editor.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
        result.addSubview(editor)

        sz = result.frame.size
        sz.height = editor.frame.height
        result.setFrameSize(sz)

        editor.changeInspector = changeInspectorCallback



