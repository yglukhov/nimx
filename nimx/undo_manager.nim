

type
  UndoManager* = ref object
    actions: seq[UndoAction]
    cursor: int

  UndoAction = object
    redo: proc() {.gcsafe.}
    undo: proc() {.gcsafe.}
    description: string

var gUndoManager : UndoManager

proc newUndoManager*(): UndoManager =
  result.new()
  result.actions = @[]

proc sharedUndoManager*(): UndoManager =
  if gUndoManager.isNil:
    gUndoManager = newUndoManager()
  result = gUndoManager

proc push*(u: UndoManager, description: string, redo: proc() {.gcsafe.}, undo: proc() {.gcsafe.}) {.inline.} =
  assert(not undo.isNil)
  if u.cursor != u.actions.len:
    u.actions.setLen(u.cursor)
  inc u.cursor
  u.actions.add(UndoAction(redo: redo, undo: undo, description: description))

proc pushAndDo*(u: UndoManager, description: string, redo: proc(){.gcsafe.}, undo: proc(){.gcsafe.}) {.inline.} =
  u.push(description, redo, undo)
  if not redo.isNil: redo()

proc canUndo*(u: UndoManager): bool = u.cursor > 0
proc canRedo*(u: UndoManager): bool =
  u.cursor >= 0 and
    u.cursor < u.actions.len and
    not u.actions[u.cursor].redo.isNil

proc undo*(u: UndoManager) =
  assert(u.canUndo)
  dec u.cursor
  let action = u.actions[u.cursor]
  action.undo()

proc redo*(u: UndoManager) =
  assert(u.canRedo)
  let action = u.actions[u.cursor]
  action.redo()
  inc u.cursor

proc clear*(u: UndoManager) =
  u.actions.setLen(0)
  u.cursor = 0

when isMainModule:
  let u = sharedUndoManager()
  u.pushAndDo("Move window") do():
    echo "do1"
  do():
    echo "undo1"

  u.undo()
  u.redo()

  u.pushAndDo("Move window2") do():
    echo "do2"
  do():
    echo "undo2"

  u.undo()
  u.undo()
  u.redo()
  u.redo()
