import event, keyboard, window_event_handling

type KeyCommand* = enum
    kcUnknown
    kcCopy
    kcCut
    kcPaste
    kcDelete
    kcUseSelectionForFind
    kcUndo
    kcRedo
    kcNew
    kcOpen
    kcSave
    kcSaveAs

type Modifier = enum
    Shift
    Gui
    Ctrl
    Alt

const jsOrEmscripten = defined(emscripten)

when defined(js):
    proc isMacOsAux(): bool =
        {.emit: """
        try {
            `result` = navigator.platform.indexOf("Mac") != -1;
        } catch(e) {}
        """.}
    let isMacOs = isMacOsAux()
elif defined(emscripten):
    import emscripten
    proc isMacOsAux(): bool =
        let r = EM_ASM_INT("""
        try {
            return navigator.platform.indexOf("Mac") != -1;
        } catch(e) {}
        """)
        result = cast[bool](r)
    let isMacOs = isMacOsAux()

template macOsCommands(body: untyped) =
    when defined(macosx):
        body
    elif jsOrEmscripten:
        if isMacOs:
            body

template nonMacOsCommands(body: untyped) =
    when jsOrEmscripten:
        if not isMacOs:
            body
    elif not defined(macosx):
        body

proc commandFromEvent*(e: Event): KeyCommand =
    if e.kind == etKeyboard and e.buttonState == bsDown:
        var curModifiers: set[Modifier]
        if alsoPressed(VirtualKey.LeftGUI) or alsoPressed(VirtualKey.RightGUI): curModifiers.incl(Gui)
        if alsoPressed(VirtualKey.LeftShift) or alsoPressed(VirtualKey.RightShift): curModifiers.incl(Shift)
        if alsoPressed(VirtualKey.LeftControl) or alsoPressed(VirtualKey.RightControl): curModifiers.incl(Ctrl)
        if alsoPressed(VirtualKey.LeftAlt) or alsoPressed(VirtualKey.RightAlt): curModifiers.incl(Alt)

        template defineCmd(cmd: KeyCommand, vk: VirtualKey, modifiers: set[Modifier]) =
            if e.keyCode == vk and set[Modifier](modifiers) == curModifiers: return cmd

        macOsCommands:
            defineCmd kcUndo, VirtualKey.Z, {Gui}
            defineCmd kcRedo, VirtualKey.Z, {Shift, Gui}

            defineCmd kcCopy, VirtualKey.C, {Gui}
            defineCmd kcCut, VirtualKey.X, {Gui}
            defineCmd kcPaste, VirtualKey.V, {Gui}
            defineCmd kcUseSelectionForFind, VirtualKey.E, {Gui}

            defineCmd kcNew, VirtualKey.N, {Gui}
            defineCmd kcOpen, VirtualKey.O, {Gui}
            defineCmd kcSave, VirtualKey.S, {Gui}
            defineCmd kcSaveAs, VirtualKey.S, {Shift, Gui}

        nonMacOsCommands:
            defineCmd kcUndo, VirtualKey.Z, {Ctrl}
            defineCmd kcRedo, VirtualKey.Y, {Ctrl}

            defineCmd kcCopy, VirtualKey.C, {Ctrl}
            defineCmd kcCut, VirtualKey.X, {Ctrl}
            defineCmd kcPaste, VirtualKey.V, {Ctrl}

            defineCmd kcNew, VirtualKey.N, {Ctrl}
            defineCmd kcOpen, VirtualKey.O, {Ctrl}
            defineCmd kcSave, VirtualKey.S, {Ctrl}
            defineCmd kcSaveAs, VirtualKey.S, {Shift, Ctrl}

        defineCmd kcDelete, VirtualKey.Delete, {}
