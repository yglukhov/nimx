import nimx/linear_layout
import nimx/property_visitor
import nimx/property_editors/propedit_registry
import nimx/property_editors/standard_editors

import variant

export linear_layout

type InspectorView* = ref object of LinearLayout
    onPropertyChanged*: proc(name: string)

method init*(v: InspectorView, r: Rect) =
    procCall v.LinearLayout.init(r)
    v.horizontal = false

proc setInspectedObject*[T](v: InspectorView, o: T) =
    v.removeAllSubviews()
    if o.isNil: return

    proc onChanged(p: PropertyVisitor): proc() =
        let name = p.name
        result = proc() =
            if not v.onPropertyChanged.isNil:
                v.onPropertyChanged(name)

    let oo = newVariant(o)
    var visitor : PropertyVisitor
    visitor.requireName = true
    visitor.requireSetter = true
    visitor.requireGetter = true
    visitor.flags = { pfEditable }
    visitor.commit = proc() =
        v.addSubview(propertyEditorForProperty(oo, visitor.name, visitor.setterAndGetter, onChange = onChanged(visitor)))

    o.visitProperties(visitor)
