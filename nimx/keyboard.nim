## Unified NimX Framework Keyboard Scan Codes.
##
## Scan Code defines specific physical key on keyboard, and enumeration
## member names do not define characters but rather 'common' characters
## on those keys places (so that e.g. 'k' and 'K' share same scan code).

import tables

# Linux-specific scan codes
type VirtualKey* {.pure.} = enum
    Unknown = 0.cint
    Escape
    One
    Two
    Three
    Four
    Five
    Six
    Seven
    Eight
    Nine
    Zero
    Minus
    Equals
    Backspace
    Tab
    Q
    W
    E
    R
    T
    Y
    U
    I
    O
    P
    LeftBracket
    RightBracket
    Return
    LeftControl
    A
    S
    D
    F
    G
    H
    J
    K
    L
    Semicolon
    Apostrophe
    Backtick
    LeftShift
    BackSlash
    Z
    X
    C
    V
    B
    N
    M
    Comma
    Period
    Slash
    RightShift
    KeypadMultiply
    LeftAlt
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
    RightControl
    KeypadDivide
    PrintScreen
    RightAlt
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
    LeftGUI
    RightGUI
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

when defined(js):
    const virtualKeyMapping: Table[VirtualKey, cint] = {
        VirtualKey.Unknown:           0.cint,
        VirtualKey.Escape:           27.cint,
        VirtualKey.One:              49.cint,
        VirtualKey.Two:              50.cint,
        VirtualKey.Three:            51.cint,
        VirtualKey.Four:             52.cint,
        VirtualKey.Five:             53.cint,
        VirtualKey.Six:              54.cint,
        VirtualKey.Seven:            55.cint,
        VirtualKey.Eight:            56.cint,
        VirtualKey.Nine:             57.cint,
        VirtualKey.Zero:             48.cint,
        VirtualKey.Minus:           189.cint,
        VirtualKey.Equals:          187.cint,
        VirtualKey.Backspace:         8.cint,
        VirtualKey.Tab:               9.cint,
        VirtualKey.Q:                81.cint,
        VirtualKey.W:                87.cint,
        VirtualKey.E:                69.cint,
        VirtualKey.R:                82.cint,
        VirtualKey.T:                84.cint,
        VirtualKey.Y:                89.cint,
        VirtualKey.U:                85.cint,
        VirtualKey.I:                73.cint,
        VirtualKey.O:                79.cint,
        VirtualKey.P:                80.cint,
        VirtualKey.LeftBracket:     219.cint,
        VirtualKey.RightBracket:    221.cint,
        VirtualKey.Return:           13.cint,
        VirtualKey.LeftControl:      17.cint,
        VirtualKey.A:                65.cint,
        VirtualKey.S:                83.cint,
        VirtualKey.D:                68.cint,
        VirtualKey.F:                70.cint,
        VirtualKey.G:                71.cint,
        VirtualKey.H:                72.cint,
        VirtualKey.J:                74.cint,
        VirtualKey.K:                75.cint,
        VirtualKey.L:                76.cint,
        VirtualKey.Semicolon:       186.cint,
        VirtualKey.Apostrophe:      222.cint,
        VirtualKey.Backtick:        192.cint,
        VirtualKey.LeftShift:        16.cint,
        VirtualKey.BackSlash:       220.cint,
        VirtualKey.Z:                90.cint,
        VirtualKey.X:                88.cint,
        VirtualKey.C:                67.cint,
        VirtualKey.V:                86.cint,
        VirtualKey.B:                66.cint,
        VirtualKey.N:                78.cint,
        VirtualKey.M:                77.cint,
        VirtualKey.Comma:           188.cint,
        VirtualKey.Period:          190.cint,
        VirtualKey.Slash:           191.cint,
        VirtualKey.RightShift:       16.cint,
        VirtualKey.KeypadMultiply:  106.cint,
        VirtualKey.LeftAlt:          18.cint,
        VirtualKey.Space:            32.cint,
        VirtualKey.CapsLock:         20.cint,
        VirtualKey.F1:              112.cint,
        VirtualKey.F2:              113.cint,
        VirtualKey.F3:              114.cint,
        VirtualKey.F4:              115.cint,
        VirtualKey.F5:              116.cint,
        VirtualKey.F6:              117.cint,
        VirtualKey.F7:              118.cint,
        VirtualKey.F8:              119.cint,
        VirtualKey.F9:              120.cint,
        VirtualKey.F10:             121.cint,
        VirtualKey.NumLock:         144.cint,
        VirtualKey.ScrollLock:      145.cint,
        VirtualKey.Keypad7:         103.cint,
        VirtualKey.Keypad8:         104.cint,
        VirtualKey.Keypad9:         105.cint,
        VirtualKey.KeypadMinus:     109.cint,
        VirtualKey.Keypad4:         100.cint,
        VirtualKey.Keypad5:         101.cint,
        VirtualKey.Keypad6:         102.cint,
        VirtualKey.KeypadPlus:      107.cint,
        VirtualKey.Keypad1:          97.cint,
        VirtualKey.Keypad2:          98.cint,
        VirtualKey.Keypad3:          99.cint,
        VirtualKey.Keypad0:          96.cint,
        VirtualKey.KeypadPeriod:    110.cint,
        VirtualKey.NonUSBackSlash:    0.cint, # -
        VirtualKey.F11:             122.cint,
        VirtualKey.F12:             123.cint,
        VirtualKey.International1:    0.cint, # -
        VirtualKey.Lang3:             0.cint, # -
        VirtualKey.Lang4:             0.cint, # -
        VirtualKey.International4:    0.cint, # -
        VirtualKey.International2:    0.cint, # -
        VirtualKey.International5:    0.cint, # -
        VirtualKey.International6:    0.cint, # -
        VirtualKey.KeypadEnter:      13.cint,
        VirtualKey.RightControl:     17.cint,
        VirtualKey.KeypadDivide:    111.cint,
        VirtualKey.PrintScreen:      42.cint,
        VirtualKey.RightAlt:         18.cint,
        VirtualKey.Home:             36.cint,
        VirtualKey.Up:               38.cint,
        VirtualKey.PageUp:           33.cint,
        VirtualKey.Left:             37.cint,
        VirtualKey.Right:            39.cint,
        VirtualKey.End:              35.cint,
        VirtualKey.Down:             40.cint,
        VirtualKey.PageDown:         34.cint,
        VirtualKey.Insert:           45.cint,
        VirtualKey.Delete:           46.cint,
        VirtualKey.Mute:              0.cint, # -
        VirtualKey.VolumeDown:        0.cint, # -
        VirtualKey.VolumeUp:          0.cint, # -
        VirtualKey.Power:             0.cint, # -
        VirtualKey.KeypadEquals:      0.cint, # -
        VirtualKey.KeypadPlusMinus:   0.cint, # -
        VirtualKey.Pause:             0.cint, # -
        VirtualKey.KeypadComma:       0.cint, # -
        VirtualKey.Lang1:             0.cint, # -
        VirtualKey.Lang2:             0.cint, # -
        VirtualKey.RightGUI:          0.cint, # -
        VirtualKey.Stop:              0.cint, # -
        VirtualKey.Again:             0.cint, # -
        VirtualKey.Undo:              0.cint, # -
        VirtualKey.Copy:              0.cint, # -
        VirtualKey.Paste:             0.cint, # -
        VirtualKey.Find:              0.cint, # -
        VirtualKey.Cut:               0.cint, # -
        VirtualKey.Help:              0.cint, # -
        VirtualKey.Menu:              0.cint, # -
        VirtualKey.Calculator:        0.cint, # -
        VirtualKey.Sleep:             0.cint, # -
        VirtualKey.Mail:              0.cint, # -
        VirtualKey.AcBookmarks:       0.cint, # -
        VirtualKey.Computer:          0.cint, # -
        VirtualKey.AcBack:            0.cint, # -
        VirtualKey.AcForward:         0.cint, # -
        VirtualKey.Eject:             0.cint, # -
        VirtualKey.AudioNext:         0.cint, # -
        VirtualKey.AudioPlay:         0.cint, # -
        VirtualKey.AudioPrev:         0.cint, # -
        VirtualKey.AcHome:            0.cint, # -
        VirtualKey.AcRefresh:         0.cint, # -
        VirtualKey.KeypadLeftPar:     0.cint, # -
        VirtualKey.KeypadRightPar:    0.cint, # -
        VirtualKey.F13:               0.cint, # -
        VirtualKey.F14:               0.cint, # -
        VirtualKey.F15:               0.cint, # -
        VirtualKey.F16:               0.cint, # -
        VirtualKey.F17:               0.cint, # -
        VirtualKey.F18:               0.cint, # -
        VirtualKey.F19:               0.cint, # -
        VirtualKey.F20:               0.cint, # -
        VirtualKey.F21:               0.cint, # -
        VirtualKey.F22:               0.cint, # -
        VirtualKey.F23:               0.cint, # -
        VirtualKey.F24:               0.cint, # -
        VirtualKey.AcSearch:          0.cint, # -
        VirtualKey.AltErase:          0.cint, # -
        VirtualKey.Cancel:            0.cint, # -
        VirtualKey.BrightnessDown:    0.cint, # -
        VirtualKey.BrightnessUp:      0.cint, # -
        VirtualKey.DisplaySwitch:     0.cint, # -
        VirtualKey.IlluminateToggle:  0.cint, # -
        VirtualKey.IlluminateDown:    0.cint, # -
        VirtualKey.IlluminateUp:      0.cint, # -
    }.toTable()

else:
    import sdl2

    const virtualKeyMapping: Table[VirtualKey, cint] = {
        VirtualKey.Unknown:         K_UNKNOWN,
        VirtualKey.Escape:          K_ESCAPE,
        VirtualKey.One:             K_1,
        VirtualKey.Two:             K_2,
        VirtualKey.Three:           K_3,
        VirtualKey.Four:            K_4,
        VirtualKey.Five:            K_5,
        VirtualKey.Six:             K_6,
        VirtualKey.Seven:           K_7,
        VirtualKey.Eight:           K_8,
        VirtualKey.Nine:            K_9,
        VirtualKey.Zero:            K_0,
        VirtualKey.Minus:           K_MINUS,
        VirtualKey.Equals:          K_EQUALS,
        VirtualKey.Backspace:       K_BACKSPACE,
        VirtualKey.Tab:             K_TAB,
        VirtualKey.Q:               K_q,
        VirtualKey.W:               K_w,
        VirtualKey.E:               K_e,
        VirtualKey.R:               K_r,
        VirtualKey.T:               K_t,
        VirtualKey.Y:               K_y,
        VirtualKey.U:               K_u,
        VirtualKey.I:               K_i,
        VirtualKey.O:               K_o,
        VirtualKey.P:               K_p,
        VirtualKey.LeftBracket:     K_LEFTBRACKET,
        VirtualKey.RightBracket:    K_RIGHTBRACKET,
        VirtualKey.Return:          K_RETURN,
        VirtualKey.LeftControl:     K_LCTRL,
        VirtualKey.A:               K_a,
        VirtualKey.S:               K_s,
        VirtualKey.D:               K_d,
        VirtualKey.F:               K_f,
        VirtualKey.G:               K_g,
        VirtualKey.H:               K_h,
        VirtualKey.J:               K_j,
        VirtualKey.K:               K_k,
        VirtualKey.L:               K_l,
        VirtualKey.Semicolon:       K_SEMICOLON,
        VirtualKey.Apostrophe:      K_QUOTE,
        VirtualKey.Backtick:        K_BACKQUOTE,
        VirtualKey.LeftShift:       K_LSHIFT,
        VirtualKey.BackSlash:       K_BACKSLASH,
        VirtualKey.Z:               K_z,
        VirtualKey.X:               K_x,
        VirtualKey.C:               K_c,
        VirtualKey.V:               K_v,
        VirtualKey.B:               K_b,
        VirtualKey.N:               K_n,
        VirtualKey.M:               K_m,
        VirtualKey.Comma:           K_COMMA,
        VirtualKey.Period:          K_PERIOD,
        VirtualKey.Slash:           K_SLASH,
        VirtualKey.RightShift:      K_RSHIFT,
        VirtualKey.KeypadMultiply:  K_KP_MULTIPLY,
        VirtualKey.LeftAlt:         K_LALT,
        VirtualKey.Space:           K_SPACE,
        VirtualKey.CapsLock:        K_CAPSLOCK,
        VirtualKey.F1:              K_F1,
        VirtualKey.F2:              K_F2,
        VirtualKey.F3:              K_F3,
        VirtualKey.F4:              K_F4,
        VirtualKey.F5:              K_F5,
        VirtualKey.F6:              K_F6,
        VirtualKey.F7:              K_F7,
        VirtualKey.F8:              K_F8,
        VirtualKey.F9:              K_F9,
        VirtualKey.F10:             K_F10,
        VirtualKey.NumLock:         K_NUMLOCKCLEAR,
        VirtualKey.ScrollLock:      K_SCROLLLOCK,
        VirtualKey.Keypad7:         K_KP_7,
        VirtualKey.Keypad8:         K_KP_8,
        VirtualKey.Keypad9:         K_KP_9,
        VirtualKey.KeypadMinus:     K_KP_MINUS,
        VirtualKey.Keypad4:         K_KP_4,
        VirtualKey.Keypad5:         K_KP_5,
        VirtualKey.Keypad6:         K_KP_6,
        VirtualKey.KeypadPlus:      K_KP_PLUS,
        VirtualKey.Keypad1:         K_KP_1,
        VirtualKey.Keypad2:         K_KP_2,
        VirtualKey.Keypad3:         K_KP_3,
        VirtualKey.Keypad0:         K_KP_0,
        VirtualKey.KeypadPeriod:    K_KP_PERIOD,
        VirtualKey.NonUSBackSlash:  0.cint, # -
        VirtualKey.F11:             K_F11,
        VirtualKey.F12:             K_F12,
        VirtualKey.International1:  0.cint, # -
        VirtualKey.Lang3:           0.cint, # -
        VirtualKey.Lang4:           0.cint, # -
        VirtualKey.International4:  0.cint, # -
        VirtualKey.International2:  0.cint, # -
        VirtualKey.International5:  0.cint, # -
        VirtualKey.International6:  0.cint, # -
        VirtualKey.KeypadEnter:     K_KP_ENTER,
        VirtualKey.RightControl:    K_RCTRL,
        VirtualKey.KeypadDivide:    K_KP_DIVIDE,
        VirtualKey.PrintScreen:     K_PRINTSCREEN,
        VirtualKey.RightAlt:        K_RALT,
        VirtualKey.Home:            K_HOME,
        VirtualKey.Up:              K_UP,
        VirtualKey.PageUp:          K_PAGEUP,
        VirtualKey.Left:            K_LEFT,
        VirtualKey.Right:           K_RIGHT,
        VirtualKey.End:             K_END,
        VirtualKey.Down:            K_DOWN,
        VirtualKey.PageDown:        K_PAGEDOWN,
        VirtualKey.Insert:          K_INSERT,
        VirtualKey.Delete:          K_DELETE,
        VirtualKey.Mute:            K_MUTE,
        VirtualKey.VolumeDown:      K_VOLUMEDOWN,
        VirtualKey.VolumeUp:        K_VOLUMEUP,
        VirtualKey.Power:           K_POWER,
        VirtualKey.KeypadEquals:    K_KP_EQUALS,
        VirtualKey.KeypadPlusMinus: K_KP_PLUSMINUS,
        VirtualKey.Pause:           K_PAUSE,
        VirtualKey.KeypadComma:     K_KP_COMMA,
        VirtualKey.Lang1:           0.cint, # -
        VirtualKey.Lang2:           0.cint, # -
        VirtualKey.RightGUI:        K_RGUI,
        VirtualKey.Stop:            K_STOP,
        VirtualKey.Again:           K_AGAIN,
        VirtualKey.Undo:            K_UNDO,
        VirtualKey.Copy:            K_COPY,
        VirtualKey.Paste:           K_PASTE,
        VirtualKey.Find:            K_FIND,
        VirtualKey.Cut:             K_CUT,
        VirtualKey.Help:            K_HELP,
        VirtualKey.Menu:            K_MENU,
        VirtualKey.Calculator:      K_CALCULATOR,
        VirtualKey.Sleep:           K_SLEEP,
        VirtualKey.Mail:            K_MAIL,
        VirtualKey.AcBookmarks:     K_AC_BOOKMARKS,
        VirtualKey.Computer:        K_COMPUTER,
        VirtualKey.AcBack:          K_AC_BACK,
        VirtualKey.AcForward:       K_AC_FORWARD,
        VirtualKey.Eject:           K_EJECT,
        VirtualKey.AudioNext:       K_AUDIONEXT,
        VirtualKey.AudioPlay:       K_AUDIOPLAY,
        VirtualKey.AudioPrev:       K_AUDIOPREV,
        VirtualKey.AcHome:          K_AC_HOME,
        VirtualKey.AcRefresh:       K_AC_REFRESH,
        VirtualKey.KeypadLeftPar:   K_KP_LEFTPAREN,
        VirtualKey.KeypadRightPar:  K_KP_RIGHTPAREN,
        VirtualKey.F13:             K_F13,
        VirtualKey.F14:             K_F14,
        VirtualKey.F15:             K_F15,
        VirtualKey.F16:             K_F16,
        VirtualKey.F17:             K_F17,
        VirtualKey.F18:             K_F18,
        VirtualKey.F19:             K_F19,
        VirtualKey.F20:             K_F20,
        VirtualKey.F21:             K_F21,
        VirtualKey.F22:             K_F22,
        VirtualKey.F23:             K_F23,
        VirtualKey.F24:             K_F24,
        VirtualKey.AcSearch:        K_AC_SEARCH,
        VirtualKey.AltErase:        K_ALTERASE,
        VirtualKey.Cancel:          K_CANCEL,
        VirtualKey.BrightnessDown:  K_BRIGHTNESSDOWN,
        VirtualKey.BrightnessUp:    K_BRIGHTNESSUP,
        VirtualKey.DisplaySwitch:   K_DISPLAYSWITCH,
        VirtualKey.IlluminateToggle:K_KBDILLUMTOGGLE,
        VirtualKey.IlluminateDown:  K_KBDILLUMDOWN,
        VirtualKey.IlluminateUp:    K_KBDILLUMUP,
    }.toTable()

proc nativeKeyFromVirtual*(vk: VirtualKey): cint = virtualKeyMapping[vk]
    ## Converts NimX defined virtual keyboard key codes to native
    ## implementation: either JS or SDL2

proc virtualKeyFromNative*(kc: cint): VirtualKey =
    ## Converts native virtual keycode to NimX defined
    for vkt, kct in virtualKeyMapping.pairs():
        if kc == kct: return vkt
    return VirtualKey.Unknown
