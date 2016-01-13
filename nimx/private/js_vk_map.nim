import tables
import nimx.keyboard

const virtualKeyMapping: Table[int, VirtualKey] = {
    # 0: VirtualKey.Unknown,
    27: VirtualKey.Escape,
    49: VirtualKey.One,
    50: VirtualKey.Two,
    51: VirtualKey.Three,
    52: VirtualKey.Four,
    53: VirtualKey.Five,
    54: VirtualKey.Six,
    55: VirtualKey.Seven,
    56: VirtualKey.Eight,
    57: VirtualKey.Nine,
    48: VirtualKey.Zero,
   189: VirtualKey.Minus,
   187: VirtualKey.Equals,
     8: VirtualKey.Backspace,
     9: VirtualKey.Tab,
    81: VirtualKey.Q,
    87: VirtualKey.W,
    69: VirtualKey.E,
    82: VirtualKey.R,
    84: VirtualKey.T,
    89: VirtualKey.Y,
    85: VirtualKey.U,
    73: VirtualKey.I,
    79: VirtualKey.O,
    80: VirtualKey.P,
   219: VirtualKey.LeftBracket,
   221: VirtualKey.RightBracket,
    13: VirtualKey.Return,
    17: VirtualKey.LeftControl,
    65: VirtualKey.A,
    83: VirtualKey.S,
    68: VirtualKey.D,
    70: VirtualKey.F,
    71: VirtualKey.G,
    72: VirtualKey.H,
    74: VirtualKey.J,
    75: VirtualKey.K,
    76: VirtualKey.L,
   186: VirtualKey.Semicolon,
   222: VirtualKey.Apostrophe,
   192: VirtualKey.Backtick,
    16: VirtualKey.LeftShift,
   220: VirtualKey.BackSlash,
    90: VirtualKey.Z,
    88: VirtualKey.X,
    67: VirtualKey.C,
    86: VirtualKey.V,
    66: VirtualKey.B,
    78: VirtualKey.N,
    77: VirtualKey.M,
   188: VirtualKey.Comma,
   190: VirtualKey.Period,
   191: VirtualKey.Slash,
    16: VirtualKey.RightShift,
   106: VirtualKey.KeypadMultiply,
    18: VirtualKey.LeftAlt,
    32: VirtualKey.Space,
    20: VirtualKey.CapsLock,
   112: VirtualKey.F1,
   113: VirtualKey.F2,
   114: VirtualKey.F3,
   115: VirtualKey.F4,
   116: VirtualKey.F5,
   117: VirtualKey.F6,
   118: VirtualKey.F7,
   119: VirtualKey.F8,
   120: VirtualKey.F9,
   121: VirtualKey.F10,
   144: VirtualKey.NumLock,
   145: VirtualKey.ScrollLock,
   103: VirtualKey.Keypad7,
   104: VirtualKey.Keypad8,
   105: VirtualKey.Keypad9,
   109: VirtualKey.KeypadMinus,
   100: VirtualKey.Keypad4,
   101: VirtualKey.Keypad5,
   102: VirtualKey.Keypad6,
   107: VirtualKey.KeypadPlus,
    97: VirtualKey.Keypad1,
    98: VirtualKey.Keypad2,
    99: VirtualKey.Keypad3,
    96: VirtualKey.Keypad0,
   110: VirtualKey.KeypadPeriod,
    # 0: VirtualKey.NonUSBackSlash, # -
   122: VirtualKey.F11,
   123: VirtualKey.F12,
    # 0: VirtualKey.International1, # -
    # 0: VirtualKey.Lang3, # -
    # 0: VirtualKey.Lang4, # -
    # 0: VirtualKey.International4, # -
    # 0: VirtualKey.International2, # -
    # 0: VirtualKey.International5, # -
    # 0: VirtualKey.International6, # -
    13: VirtualKey.KeypadEnter,
    17: VirtualKey.RightControl,
   111: VirtualKey.KeypadDivide,
    42: VirtualKey.PrintScreen,
    18: VirtualKey.RightAlt,
    36: VirtualKey.Home,
    38: VirtualKey.Up,
    33: VirtualKey.PageUp,
    37: VirtualKey.Left,
    39: VirtualKey.Right,
    35: VirtualKey.End,
    40: VirtualKey.Down,
    34: VirtualKey.PageDown,
    45: VirtualKey.Insert,
    46: VirtualKey.Delete,
    # 0: VirtualKey.Mute, # -
    # 0: VirtualKey.VolumeDown, # -
    # 0: VirtualKey.VolumeUp, # -
    # 0: VirtualKey.Power, # -
    # 0: VirtualKey.KeypadEquals, # -
    # 0: VirtualKey.KeypadPlusMinus, # -
    # 0: VirtualKey.Pause, # -
    # 0: VirtualKey.KeypadComma, # -
    # 0: VirtualKey.Lang1, # -
    # 0: VirtualKey.Lang2, # -
    # 0: VirtualKey.RightGUI, # -
    # 0: VirtualKey.Stop, # -
    # 0: VirtualKey.Again, # -
    # 0: VirtualKey.Undo, # -
    # 0: VirtualKey.Copy, # -
    # 0: VirtualKey.Paste, # -
    # 0: VirtualKey.Find, # -
    # 0: VirtualKey.Cut, # -
    # 0: VirtualKey.Help, # -
    # 0: VirtualKey.Menu, # -
    # 0: VirtualKey.Calculator, # -
    # 0: VirtualKey.Sleep, # -
    # 0: VirtualKey.Mail, # -
    # 0: VirtualKey.AcBookmarks, # -
    # 0: VirtualKey.Computer, # -
    # 0: VirtualKey.AcBack, # -
    # 0: VirtualKey.AcForward, # -
    # 0: VirtualKey.Eject, # -
    # 0: VirtualKey.AudioNext, # -
    # 0: VirtualKey.AudioPlay, # -
    # 0: VirtualKey.AudioPrev, # -
    # 0: VirtualKey.AcHome, # -
    # 0: VirtualKey.AcRefresh, # -
    # 0: VirtualKey.KeypadLeftPar, # -
    # 0: VirtualKey.KeypadRightPar, # -
    # 0: VirtualKey.F13, # -
    # 0: VirtualKey.F14, # -
    # 0: VirtualKey.F15, # -
    # 0: VirtualKey.F16, # -
    # 0: VirtualKey.F17, # -
    # 0: VirtualKey.F18, # -
    # 0: VirtualKey.F19, # -
    # 0: VirtualKey.F20, # -
    # 0: VirtualKey.F21, # -
    # 0: VirtualKey.F22, # -
    # 0: VirtualKey.F23, # -
    # 0: VirtualKey.F24, # -
    # 0: VirtualKey.AcSearch, # -
    # 0: VirtualKey.AltErase, # -
    # 0: VirtualKey.Cancel, # -
    # 0: VirtualKey.BrightnessDown, # -
    # 0: VirtualKey.BrightnessUp, # -
    # 0: VirtualKey.DisplaySwitch, # -
    # 0: VirtualKey.IlluminateToggle, # -
    # 0: VirtualKey.IlluminateDown, # -
    # 0: VirtualKey.IlluminateUp, # -
}.toTable()

template virtualKeyFromNative*(kc: int): VirtualKey = virtualKeyMapping.getOrDefault(kc)
