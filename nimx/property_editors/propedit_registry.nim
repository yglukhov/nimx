import std/tables
import ../view
import ../text_field
import ../font
import ../property_visitor
import ../layout
import variant

type
  PropertyEditorView* = ref object of View
    onChange*: proc() {.gcsafe.}
    changeInspector*: proc() {.gcsafe.}
  PropertyEditorCreator*[T] = proc(setter: proc(s: T) {.gcsafe.}, getter: proc(): T {.gcsafe.}): PropertyEditorView {.gcsafe.}
  RegistryTableEntry = proc(v: Variant): PropertyEditorView {.gcsafe.}

var propEditors {.threadvar.}: Table[TypeId, RegistryTableEntry]
propEditors = initTable[TypeId, RegistryTableEntry]()

proc registerPropertyEditorAUX[T, C](createView: C) =
  propEditors[getTypeId(SetterAndGetter[T])] = proc(v: Variant): PropertyEditorView {.gcsafe.} =
    let sng = v.get(SetterAndGetter[T])
    var r: PropertyEditorView
    proc setterAUX(s: T) {.gcsafe.} =
      sng.setter(s)
      if not r.isNil and not r.onChange.isNil:
        r.onChange()
    r = createView(setterAUX, sng.getter)
    result = r

proc registerPropertyEditor*[T](createView: PropertyEditorCreator[T]) =
  registerPropertyEditorAUX[T, PropertyEditorCreator[T]](createView)

var gEditorFont {.threadvar.}: Font

proc editorFont*(): Font {.gcsafe.} =
  if gEditorFont.isNil: gEditorFont = systemFontOfSize(14)
  result = gEditorFont

const editorRowHeight* = 16

template createEditorAUX() =
  let editor = creator(v)
  editor.name = "editor"
  editor.makeLayout:
    x == super.x
    y == super.y
    width == super.width
    height == super

  editorSuper.addSubview(editor)
  editor.changeInspector = changeInspectorCallback
  editor.onChange = onChange

proc propertyEditorForProperty*(title: string, v: Variant, onChange: proc() {.gcsafe.} = nil, changeInspectorCallback: proc() {.gcsafe.} = nil): View =
  let creator = propEditors.getOrDefault(v.typeId)
  if creator.isNil:
    result = new(View)
    result.makeLayout:
      - Label:
        x == super.x
        top == super
        width == super
        height == editorRowHeight
        height == super
        text: title & " - Unknown property"
        font: editorFont()
    return

  result = new(View)
  result.makeLayout:
    - Label:
      y == super.y
      x == super.x
      height == editorRowHeight
      width == 128 @ WEAK
      name: "label"
      text: title & ":"
      font: editorFont()

    - View as editorSuper:
      y == super.y
      leading == prev.trailing
      trailing == super.trailing
      height == super
  createEditorAUX()


proc propertyEditorForProperty*(v: Variant, changeInspectorCallback: proc() {.gcsafe.} = nil): View =
  assert(false, "is it used?")
  let creator = propEditors.getOrDefault(v.typeId)
  result = new(View)
  if creator.isNil:
    let label = new(Label)
    label.makeLayout:
      x == super.x + 100
      y == super.y
      width == 128 @ WEAK
      height == editorRowHeight
      text: "Unknown"
      font: editorFont()
    result.addSubview(label)
  else:
    let editorSuper = result
    const onChange: proc() {.gcsafe.} = nil
    createEditorAUX()