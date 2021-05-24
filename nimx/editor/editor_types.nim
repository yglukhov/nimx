import nimx / [
    view, panel_view, toolbar, button, menu, undo_manager,
    inspector_panel, gesture_detector, window_event_handling, event, view_event_handling,
    serializers, key_commands, pasteboard/pasteboard, property_editors/autoresizing_mask_editor
]

import ui_document
import grid_drawing

type
    EventCatchingView* = ref object of View
        keyUpDelegate*: proc (event: var Event)
        keyDownDelegate*: proc (event: var Event)
        mouseScrrollDelegate*: proc (event: var Event)
        panningView*: View # View that we're currently moving/resizing with `panOp`
        editor*: Editor
        panOp*: PanOperation
        dragStartTime*: float
        origPanRect*: Rect
        origPanPoint*: Point
        mGridSize*: float

    EditView* = ref object of View
        editor*: Editor

    UIDocument* = ref object
        view*: View
        undoManager*: UndoManager
        path*: string
        takenViewNames*: seq[string] #used only for propose default names

    Editor* = ref object
        eventCatchingView*: EventCatchingView
        inspector*: InspectorPanel
        mSelectedView*: View # View that we currently draw selection rect around
        document*: UIDocument
        workspace*: EditorWorkspace

    PanOperation* = enum
        poDrag
        poDragTL
        poDragT
        poDragTR
        poDragB
        poDragBR
        poDragBL
        poDragL
        poDragR

    EditorWorkspace* = ref object of View
        gridSize*: Size
