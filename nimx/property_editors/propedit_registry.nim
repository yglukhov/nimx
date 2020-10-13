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

template createEditorAUX(r: Rect) =
    let editor = creator(editedObject, v)
    editor.name = "editor"
    editor.setFrameOrigin(r.origin)
    var sz = newSize(r.size.width, editor.frame.height)
    editor.setFrameSize(sz)
    editor.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    result.addSubview(editor)

    sz = result.frame.size
    sz.height = editor.frame.height
    result.setFrameSize(sz)

    editor.changeInspector = changeInspectorCallback

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
        createEditorAUX(newRect(label.frame.width, 0, result.bounds.width - label.frame.width, result.bounds.height))

proc propertyEditorForProperty*(editedObject: Variant, v: Variant, changeInspectorCallback: proc() = nil): View =
    let creator = propEditors.getOrDefault(v.typeId)
    result = View.new(newRect(0, 0, 228, editorRowHeight))
    result.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    if creator.isNil:
        discard result.newLabel(newPoint(100, 0), newSize(128, editorRowHeight), "Unknown")
    else:
        createEditorAUX(newRect(0,0, result.bounds.width, result.bounds.height))
