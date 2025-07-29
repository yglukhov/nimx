
import view, view_event_handling
export view

type Control* = ref object of View
  actionHandler: proc(e: Event) {.gcsafe.}
  clickable*: bool

method sendAction*(c: Control, e: Event) {.base, gcsafe.} =
  if not c.actionHandler.isNil:
    c.actionHandler(e)

proc sendAction*(c: Control) =
  # Send action with unknown event
  c.sendAction(newUnknownEvent())

proc onAction*(c: Control, handler: proc(e: Event) {.gcsafe.}) =
  c.actionHandler = handler

proc onAction*(c: Control, handler: proc() {.gcsafe.}) =
  if handler.isNil:
    c.actionHandler = nil
  else:
    c.onAction do (e: Event):
      handler()

method onTouchEv*(b: Control, e: var Event): bool =
  discard procCall b.View.onTouchEv(e)
  if b.clickable:
    case e.buttonState
    of bsUp:
      if e.localPosition.inRect(b.bounds):
        b.sendAction(e)
    else: discard
    result = true
