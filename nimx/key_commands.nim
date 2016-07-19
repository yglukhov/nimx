import event, keyboard, window_event_handling

type KeyCommand* = enum
    kcUnknown
    kcCopy
    kcCut
    kcPaste
    kcUndo
    kcRedo
    kcSave
    kcSaveAs

type Modifier = enum
    Shift
    Gui
    Ctrl
    Alt

proc isMacOS(): bool =
    # TODO: On JS and Emscripten this has to do smth different...
    defined(macosx)

proc commandFromEvent*(e: Event): KeyCommand =
    if e.kind == etKeyboard and e.buttonState == bsDown:
        var curModifiers: set[Modifier]
        if alsoPressed(VirtualKey.LeftGUI) or alsoPressed(VirtualKey.RightGUI): curModifiers.incl(Gui)
        if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift): curModifiers.incl(Shift)
        if alsoPressed(VirtualKey.LeftControl) or alsoPressed(VirtualKey.RightControl): curModifiers.incl(Ctrl)
        if alsoPressed(VirtualKey.LeftAlt) or alsoPressed(VirtualKey.RightAlt): curModifiers.incl(Alt)

        template defineCmd(cmd: KeyCommand, vk: VirtualKey, modifiers: set[Modifier]) =
            if e.keyCode == vk and modifiers == curModifiers: return cmd

        if isMacOS():
            defineCmd kcUndo, VirtualKey.Z, {Gui}
            defineCmd kcRedo, VirtualKey.Z, {Shift, Gui}

            defineCmd kcCopy, VirtualKey.C, {Gui}
            defineCmd kcCut, VirtualKey.X, {Gui}
            defineCmd kcPaste, VirtualKey.V, {Gui}

            defineCmd kcSave, VirtualKey.S, {Gui}
            defineCmd kcSaveAs, VirtualKey.S, {Shift, Gui}
        else:
            defineCmd kcUndo, VirtualKey.Z, {Ctrl}
            defineCmd kcRedo, VirtualKey.Y, {Ctrl}

            defineCmd kcCopy, VirtualKey.C, {Ctrl}
            defineCmd kcCut, VirtualKey.X, {Ctrl}
            defineCmd kcPaste, VirtualKey.V, {Ctrl}

            defineCmd kcSave, VirtualKey.S, {Ctrl}
            defineCmd kcSaveAs, VirtualKey.S, {Shift, Ctrl}
