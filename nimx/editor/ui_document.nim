import json

import nimx/undo_manager
import nimx/view
import nimx/serializers
import nimx/resource

const savingAndLoadingEnabled* = not defined(js) and not defined(emscripten) and
        not defined(ios) and not defined(android)

const ViewPboardKind* = "io.github.yglukhov.nimx"

when savingAndLoadingEnabled:
    import os_files / dialog

type UIDocument* = ref object
    view*: View
    undoManager*: UndoManager
    path*: string

proc newUIDocument*(): UIDocument =
    result.new()
    result.undoManager = newUndoManager()

when savingAndLoadingEnabled:
    proc save*(d: UIDocument) =
        if d.path.len == 0:
            var di: DialogInfo
            di.extension = "nimx"
            di.kind = dkSaveFile
            di.filters = @[(name:"Nimx", ext:"*.nimx")]
            di.title = "Save document"
            d.path = di.show()

        if d.path.len > 0:
            let s = newJsonSerializer()
            pushParentResource(d.path)
            s.serialize(d.view)
            popParentResource()
            writeFile(d.path, $s.jsonNode())

    proc saveAs*(d: UIDocument) =
        var di: DialogInfo
        di.extension = "nimx"
        di.kind = dkSaveFile
        di.filters = @[(name:"Nimx", ext:"*.nimx")]
        di.title = "Save document as"

        var path = di.show()
        if path.len > 0:
            d.path = path
            d.save()

    proc loadFromPath*(d: UIDocument, path: string) =
        d.path = path
        if d.path.len > 0:
            let j = try: parseFile(path) except: nil
            if not j.isNil:
                let superview = d.view.superview
                d.view.removeFromSuperview()
                let s = newJsonDeserializer(j)
                pushParentResource(path)
                d.view = nil
                s.deserialize(d.view)
                popParentResource()
                doAssert(not d.view.isNil)
                if not superview.isNil:
                    superview.addSubview(d.view)

    proc open*(d: UIDocument) =
        var di: DialogInfo
        di.extension = "nimx"
        di.kind = dkOpenFile
        di.filters = @[(name:"Nimx", ext:"*.nimx")]
        di.title = "Open document"

        var path = di.show()
        if path.len > 0:
            d.loadFromPath(path)
