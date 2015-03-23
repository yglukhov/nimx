
import window
import event

method onKeyDown*(w: Window, e: var Event): bool =
    if w.canPassEventToFirstResponder:
        result = w.firstResponder.onKeyDown(e)

method onKeyUp*(w: Window, e: var Event): bool =
    if w.canPassEventToFirstResponder:
        result = w.firstResponder.onKeyUp(e)

method onTextInput*(w: Window, s: string): bool =
    if w.canPassEventToFirstResponder:
        result = w.firstResponder.onTextInput(s)

