when defined(macosx):
    import pasteboard_mac
    export pasteboard_mac
else:
    import abstract_pasteboard
    export abstract_pasteboard
    proc pasteboardWithName*(name: string): Pasteboard = result.new()
