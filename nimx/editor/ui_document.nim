import json

import nimx/undo_manager
import nimx/view
import nimx/serializers

const savingAndLoadingEnabled* = not defined(js) and not defined(emscripten) and
        not defined(ios) and not defined(android)

const ViewPboardKind* = "io.github.yglukhov.nimx"

when savingAndLoadingEnabled:
    import os_files/dialog

type UIDocument* = ref object
    view*: View
    undoManager*: UndoManager
    path*: string

proc newUIDocument*(): UIDocument =
    result.new()
    result.undoManager = newUndoManager()

proc fileDialog(title: string, kind: DialogKind): string =
    var di:DialogInfo
    di.title = title
    di.kind = kind
    di.filters = @[(name:"Nimx UI", ext:"*.nimx")]
    di.extension = "nimx"
    di.show()

when savingAndLoadingEnabled:
    proc save*(d: UIDocument) =
        if d.path.len == 0:
            d.path = fileDialog("Save", dkSaveFile)

        if d.path.len != 0:
            let s = newJsonSerializer()
            # pushParentResource(d.path)
            s.serialize(d.view)
            # popParentResource()
            writeFile(d.path, $s.jsonNode())

    proc saveAs*(d: UIDocument) =
        let path = fileDialog("Save", dkSaveFile)
        if path.len != 0:
            d.path = path
            d.save()

    proc loadFromPath*(d: UIDocument, path: string) =
        d.path = path
        if d.path.len != 0:
            let j = try: parseFile(path) except: nil
            if not j.isNil:
                let superview = d.view.superview
                d.view.removeFromSuperview()
                let s = newJsonDeserializer(j)
                # pushParentResource(path)
                d.view = nil
                s.deserialize(d.view)
                # popParentResource()
                doAssert(not d.view.isNil)
                if not superview.isNil:
                    superview.addSubview(d.view)

    proc open*(d: UIDocument) =
        let path = fileDialog("Open", dkOpenFile)
        if path.len != 0:
            d.loadFromPath(path)
