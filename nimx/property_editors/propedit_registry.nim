import tables
import nimx/view
import nimx/text_field
import nimx/font
import nimx/property_visitor
import nimx/context

import variant

type
    PropertyEditorView* = ref object of View
        onChange*: proc()
        changeInspector*: proc()
    PropertyEditorCreatorWO*[T] = proc(w: Window, editedObject: Variant, setter: proc(s: T), getter: proc(): T): PropertyEditorView
    PropertyEditorCreator*[T] = proc(w: Window, setter: proc(s: T), getter: proc(): T): PropertyEditorView

var propEditors = initTable[TypeId, proc(w: Window, editedObject: Variant, v: Variant): PropertyEditorView]()

proc registerPropertyEditorAUX[T, C](createView: C) =
    propEditors[getTypeId(SetterAndGetter[T])] = proc(w: Window, n: Variant, v: Variant): PropertyEditorView =
        let sng = v.get(SetterAndGetter[T])
        var r: PropertyEditorView
        proc setterAUX(s: T) =
            sng.setter(s)
            if not r.isNil and not r.onChange.isNil:
                r.onChange()
        when C is PropertyEditorCreatorWO:
            r = createView(w, n, setterAUX, sng.getter)
        else:
            r = createView(w, setterAUX, sng.getter)
        result = r

proc registerPropertyEditor*[T](createView: PropertyEditorCreatorWO[T]) =
    registerPropertyEditorAUX[T, PropertyEditorCreatorWO[T]](createView)

proc registerPropertyEditor*[T](createView: PropertyEditorCreator[T]) =
    registerPropertyEditorAUX[T, PropertyEditorCreator[T]](createView)

const editorRowHeight* = 16

template createEditorAUX(w: Window, r: Rect) =
    let editor = creator(w, editedObject, v)
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
    editor.onChange = onChange

proc propertyEditorForProperty*(w: Window, editedObject: Variant, title: string, v: Variant, onChange, changeInspectorCallback: proc() = nil): View =
    let creator = propEditors.getOrDefault(v.typeId)
    result = View.new(w, newRect(0, 0, 328, editorRowHeight))
    result.name = "'" & title & "'"
    result.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    let label = newLabel(w, newRect(0, 0, 100, editorRowHeight))
    label.textColor = blackColor()
    label.name = "label"
    label.text = title & ":"
    label.font = systemFontOfSize(w.gfxCtx.fontCtx, 14.0)
    result.addSubview(label)
    if creator.isNil:
        label.text = title & " - Unknown property"
    else:
        createEditorAUX(w, newRect(label.frame.width, 0, result.bounds.width - label.frame.width, result.bounds.height))

proc propertyEditorForProperty*(w: Window, editedObject: Variant, v: Variant, changeInspectorCallback: proc() = nil): View =
    let creator = propEditors.getOrDefault(v.typeId)
    result = View.new(w, newRect(0, 0, 228, editorRowHeight))
    result.autoresizingMask = {afFlexibleWidth, afFlexibleMaxY}
    if creator.isNil:
        discard result.newLabel(w, newPoint(100, 0), newSize(128, editorRowHeight), "Unknown")
    else:
        const onChange: proc() = nil
        createEditorAUX(w, newRect(0,0, result.bounds.width, result.bounds.height))