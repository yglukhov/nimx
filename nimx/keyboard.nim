## Unified NimX Framework Keyboard Scan Codes.
##
## Scan Code defines specific physical key on keyboard, and enumeration
## member names do not define characters but rather 'common' characters
## on those keys places (so that e.g. 'k' and 'K' share same scan code).
when defined(js) or defined(emscripten):
    import private/js_platform_detector

type VirtualKey* {.pure.} = enum
    Unknown = 0

    LeftControl  # Modifier, order shouldn't be changed
    LeftShift    # Modifier, order shouldn't be changed
    RightShift   # Modifier, order shouldn't be changed
    LeftAlt      # Modifier, order shouldn't be changed
    RightControl # Modifier, order shouldn't be changed
    RightAlt     # Modifier, order shouldn't be changed
    LeftGUI      # Modifier, order shouldn't be changed
    RightGUI     # Modifier, order shouldn't be changed


    MouseButtonPrimary
    MouseButtonSecondary
    MouseButtonMiddle
    Escape
    Zero
    One
    Two
    Three
    Four
    Five
    Six
    Seven
    Eight
    Nine
    Minus
    Equals
    Backspace
    Tab
    LeftBracket
    RightBracket
    Return

    A
    B
    C
    D
    E
    F
    G
    H
    I
    J
    K
    L
    M
    N
    O
    P
    Q
    R
    S
    T
    U
    V
    W
    X
    Y
    Z

    Semicolon
    Apostrophe
    Backtick

    BackSlash
    Comma
    Period
    Slash

    KeypadMultiply

    Space
    CapsLock
    F1
    F2
    F3
    F4
    F5
    F6
    F7
    F8
    F9
    F10
    NumLock
    ScrollLock
    Keypad7
    Keypad8
    Keypad9
    KeypadMinus
    Keypad4
    Keypad5
    Keypad6
    KeypadPlus
    Keypad1
    Keypad2
    Keypad3
    Keypad0
    KeypadPeriod
    NonUSBackSlash
    F11
    F12
    International1
    Lang3
    Lang4
    International4
    International2
    International5
    International6
    KeypadEnter

    KeypadDivide
    PrintScreen

    Home
    Up
    PageUp
    Left
    Right
    End
    Down
    PageDown
    Insert
    Delete
    Mute
    VolumeDown
    VolumeUp
    Power
    KeypadEquals
    KeypadPlusMinus
    Pause
    KeypadComma
    Lang1
    Lang2
    International3

    Stop
    Again
    Undo
    Copy
    Paste
    Find
    Cut
    Help
    Menu
    Calculator
    Sleep
    Mail
    AcBookmarks
    Computer
    AcBack
    AcForward
    Eject
    AudioNext
    AudioPlay
    AudioPrev
    AcHome
    AcRefresh
    KeypadLeftPar
    KeypadRightPar
    F13
    F14
    F15
    F16
    F17
    F18
    F19
    F20
    F21
    F22
    F23
    F24
    AcSearch
    AltErase
    Cancel
    BrightnessDown
    BrightnessUp
    DisplaySwitch
    IlluminateToggle
    IlluminateDown
    IlluminateUp

type ModifiersSet* = distinct int16

{.push inline.}

proc isModifier*(vk: VirtualKey): bool =
    vk in VirtualKey.LeftControl .. VirtualKey.RightGUI

proc toAscii*(vk: VirtualKey): char =
    case vk
    of VirtualKey.A .. VirtualKey.Z:
        char(ord(vk) - ord(VirtualKey.A) + ord('a'))
    of VirtualKey.Zero .. VirtualKey.Nine:
        char(ord(vk) - ord(VirtualKey.Zero) + ord('0'))
    of VirtualKey.Space: ' '
    of VirtualKey.RightBracket: ']'
    of VirtualKey.LeftBracket: '['
    else:
        char(0)

proc incl*(s: var ModifiersSet, vk: VirtualKey) =
    assert(vk.isModifier)
    s = (s.int16 or (1 shl vk.int16)).ModifiersSet

proc excl*(s: var ModifiersSet, vk: VirtualKey) =
    assert(vk.isModifier)
    s = (s.int16 and not (1 shl vk.int16)).ModifiersSet

proc contains*(s: ModifiersSet, vk: VirtualKey): bool =
    assert(vk.isModifier)
    ((s.int16 shr vk.int16) and 1).bool

proc anyCtrl*(s: ModifiersSet): bool =
    VirtualKey.LeftControl in s or VirtualKey.RightControl in s

proc anyAlt*(s: ModifiersSet): bool =
    VirtualKey.LeftAlt in s or VirtualKey.RightAlt in s

proc anyGui*(s: ModifiersSet): bool =
    VirtualKey.LeftGUI in s or VirtualKey.RightGUI in s

proc anyShift*(s: ModifiersSet): bool =
    VirtualKey.LeftShift in s or VirtualKey.RightShift in s

proc anyOsModifier*(s: ModifiersSet): bool =
    # Cmd for MacOS, else Ctrl

    when defined(macosx):
        s.anyGui()
    elif defined(js) or defined(emscripten):
        if isMacOs:
            s.anyGui()
        else:
            s.anyCtrl()
    else:
        s.anyCtrl()

proc isEmpty*(s: ModifiersSet): bool = s.int16 == 0


{.pop.}
