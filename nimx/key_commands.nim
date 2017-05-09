import event, keyboard, window_event_handling

type KeyCommand* = enum
    kcUnknown
    kcCopy
    kcCut
    kcPaste
    kcDelete
    kcUseSelectionForFind
    kcSelectAll
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

const jsOrEmscripten = defined(emscripten) or defined(js)

when defined(js):
    proc isMacOsAux(): bool =
        {.emit: """
        try {
            `result` = navigator.platform.indexOf("Mac") != -1;
        } catch(e) {}
        """.}
    let isMacOs = isMacOsAux()
elif defined(emscripten):
    import jsbind.emscripten
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
        if e.modifiers.anyGui(): curModifiers.incl(Gui)
        if e.modifiers.anyShift(): curModifiers.incl(Shift)
        if e.modifiers.anyCtrl(): curModifiers.incl(Ctrl)
        if e.modifiers.anyAlt(): curModifiers.incl(Alt)

        template defineCmd(cmd: KeyCommand, vk: VirtualKey, modifiers: set[Modifier]) =
            if e.keyCode == vk and curModifiers == modifiers: return cmd

        macOsCommands:
            defineCmd kcUndo, VirtualKey.Z, {Gui}
            defineCmd kcRedo, VirtualKey.Z, {Shift, Gui}

            defineCmd kcCopy, VirtualKey.C, {Gui}
            defineCmd kcCut, VirtualKey.X, {Gui}
            defineCmd kcPaste, VirtualKey.V, {Gui}
            defineCmd kcUseSelectionForFind, VirtualKey.E, {Gui}

            defineCmd kcSelectAll, VirtualKey.A, {Gui}

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

            defineCmd kcSelectAll, VirtualKey.A, {Ctrl}

            defineCmd kcNew, VirtualKey.N, {Ctrl}
            defineCmd kcOpen, VirtualKey.O, {Ctrl}
            defineCmd kcSave, VirtualKey.S, {Ctrl}
            defineCmd kcSaveAs, VirtualKey.S, {Shift, Ctrl}

        defineCmd kcDelete, VirtualKey.Delete, {}
