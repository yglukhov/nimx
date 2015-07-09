
import view
export view

import event

type Control* = ref object of View
    actionHandler: proc(e: Event)

proc sendAction*(c: Control, e: Event) =
    if c.actionHandler != nil:
        c.actionHandler(e)

proc sendAction*(c: Control) =
    # Send action with unknown event
    c.sendAction(newUnknownEvent())

proc onAction*(c: Control, handler: proc(e: Event)) =
    c.actionHandler = handler

proc onAction*(c: Control, handler: proc()) =
    c.onAction do (e: Event):
        handler()
