import nimx/keyboard
import tables
import winim

const
  VK_0 = 0x30
  VK_1 = 0x31
  VK_2 = 0x32
  VK_3 = 0x33
  VK_4 = 0x34
  VK_5 = 0x35
  VK_6 = 0x36
  VK_7 = 0x37
  VK_8 = 0x38
  VK_9 = 0x39
  VK_A = 0x41
  VK_B = 0x42
  VK_C = 0x43
  VK_D = 0x44
  VK_E = 0x45
  VK_F = 0x46
  VK_G = 0x47
  VK_H = 0x48
  VK_I = 0x49
  VK_J = 0x4A
  VK_K = 0x4B
  VK_L = 0x4C
  VK_M = 0x4D
  VK_N = 0x4E
  VK_O = 0x4F
  VK_P = 0x50
  VK_Q = 0x51
  VK_R = 0x52
  VK_S = 0x53
  VK_T = 0x54
  VK_U = 0x55
  VK_V = 0x56
  VK_W = 0x57
  VK_X = 0x58
  VK_Y = 0x59
  VK_Z = 0x5A

const virtualKeyMapping: Table[int, VirtualKey] = {
  VK_0:        VirtualKey.Zero,
  VK_1:        VirtualKey.One,
  VK_2:        VirtualKey.Two,
  VK_3:        VirtualKey.Three,
  VK_4:        VirtualKey.Four,
  VK_5:        VirtualKey.Five,
  VK_6:        VirtualKey.Six,
  VK_7:        VirtualKey.Seven,
  VK_8:        VirtualKey.Eight,
  VK_9:        VirtualKey.Nine,

  VK_Q:        VirtualKey.Q,
  VK_W:        VirtualKey.W,
  VK_E:        VirtualKey.E,
  VK_R:        VirtualKey.R,
  VK_T:        VirtualKey.T,
  VK_Y:        VirtualKey.Y,
  VK_U:        VirtualKey.U,
  VK_I:        VirtualKey.I,
  VK_O:        VirtualKey.O,
  VK_P:        VirtualKey.P,
  VK_A:        VirtualKey.A,
  VK_S:        VirtualKey.S,
  VK_D:        VirtualKey.D,
  VK_F:        VirtualKey.F,
  VK_G:        VirtualKey.G,
  VK_H:        VirtualKey.H,
  VK_J:        VirtualKey.J,
  VK_K:        VirtualKey.K,
  VK_L:        VirtualKey.L,
  VK_Z:        VirtualKey.Z,
  VK_X:        VirtualKey.X,
  VK_C:        VirtualKey.C,
  VK_V:        VirtualKey.V,
  VK_B:        VirtualKey.B,
  VK_N:        VirtualKey.N,
  VK_M:        VirtualKey.M,

  VK_F1:         VirtualKey.F1,
  VK_F2:         VirtualKey.F2,
  VK_F3:         VirtualKey.F3,
  VK_F4:         VirtualKey.F4,
  VK_F5:         VirtualKey.F5,
  VK_F6:         VirtualKey.F6,
  VK_F7:         VirtualKey.F7,
  VK_F8:         VirtualKey.F8,
  VK_F9:         VirtualKey.F9,
  VK_F10:        VirtualKey.F10,
  VK_F11:        VirtualKey.F11,
  VK_F12:        VirtualKey.F12,
  VK_F13:        VirtualKey.F13,
  VK_F14:        VirtualKey.F14,
  VK_F15:        VirtualKey.F15,
  VK_F16:        VirtualKey.F16,
  VK_F17:        VirtualKey.F17,
  VK_F18:        VirtualKey.F18,
  VK_F19:        VirtualKey.F19,
  VK_F20:        VirtualKey.F20,
  VK_F21:        VirtualKey.F21,
  VK_F22:        VirtualKey.F22,
  VK_F23:        VirtualKey.F23,
  VK_F24:        VirtualKey.F24,

  VK_NUMLOCK:      VirtualKey.NumLock,
  VK_MULTIPLY:     VirtualKey.KeypadMultiply,
  VK_ESCAPE:       VirtualKey.Escape,
  VK_TAB:        VirtualKey.Tab,
  VK_RETURN:       VirtualKey.Return,
  VK_CONTROL:      VirtualKey.LeftControl,
  VK_SHIFT:      VirtualKey.LeftShift,
  # VK_LCONTROL:     VirtualKey.LeftControl,
  # VK_LSHIFT:       VirtualKey.LeftShift,
  # VK_RSHIFT:       VirtualKey.RightShift,
  # VK_RCONTROL:     VirtualKey.RightControl,
  VK_HOME:       VirtualKey.Home,
  VK_UP:         VirtualKey.Up,
  VK_LEFT:       VirtualKey.Left,
  VK_RIGHT:      VirtualKey.Right,
  VK_END:        VirtualKey.End,
  VK_DOWN:       VirtualKey.Down,
  VK_INSERT:       VirtualKey.Insert,
  VK_DELETE:       VirtualKey.Delete,
  VK_PAUSE:      VirtualKey.Pause,
  VK_SPACE:      VirtualKey.Space,

  VK_NUMPAD0:      VirtualKey.Keypad0,
  VK_NUMPAD1:      VirtualKey.Keypad1,
  VK_NUMPAD2:      VirtualKey.Keypad2,
  VK_NUMPAD3:      VirtualKey.Keypad3,
  VK_NUMPAD4:      VirtualKey.Keypad4,
  VK_NUMPAD5:      VirtualKey.Keypad5,
  VK_NUMPAD6:      VirtualKey.Keypad6,
  VK_NUMPAD7:      VirtualKey.Keypad7,
  VK_NUMPAD8:      VirtualKey.Keypad8,
  VK_NUMPAD9:      VirtualKey.Keypad9,

  VK_ADD:        VirtualKey.KeypadPlus,
  VK_BACK:       VirtualKey.Backspace,
  VK_CANCEL:       VirtualKey.Cancel,
  VK_DECIMAL:      VirtualKey.KeypadPeriod,
  VK_SUBTRACT:     VirtualKey.KeypadMinus,
  VK_DIVIDE:       VirtualKey.Slash,
  VK_PRIOR:      VirtualKey.PageUp,
  VK_NEXT:       VirtualKey.PageDown,

  189:      VirtualKey.Minus
  # SDL_SCANCODE_EQUALS:       VirtualKey.Equals,
  # SDL_SCANCODE_LEFTBRACKET:    VirtualKey.LeftBracket,
  # SDL_SCANCODE_RIGHTBRACKET:   VirtualKey.RightBracket,
  # SDL_SCANCODE_SEMICOLON:    VirtualKey.Semicolon,
  # SDL_SCANCODE_APOSTROPHE:     VirtualKey.Apostrophe,
  # SDL_SCANCODE_GRAVE:      VirtualKey.Backtick,
  # SDL_SCANCODE_BACKSLASH:    VirtualKey.BackSlash,
  # SDL_SCANCODE_COMMA:      VirtualKey.Comma,
  # SDL_SCANCODE_PERIOD:       VirtualKey.Period,
  # SDL_SCANCODE_SLASH:      VirtualKey.Slash,
  # SDL_SCANCODE_LALT:       VirtualKey.LeftAlt,
  # SDL_SCANCODE_CAPSLOCK:     VirtualKey.CapsLock,
  # SDL_SCANCODE_SCROLLLOCK:     VirtualKey.ScrollLock,



  # SDL_SCANCODE_NONUSBACKSLASH:   VirtualKey.NonUSBackSlash,

  # SDL_SCANCODE_KP_ENTER:     VirtualKey.KeypadEnter,
  # SDL_SCANCODE_KP_DIVIDE:    VirtualKey.KeypadDivide,
  # SDL_SCANCODE_PRINTSCREEN:    VirtualKey.PrintScreen,
  # SDL_SCANCODE_RALT:       VirtualKey.RightAlt,
  # SDL_SCANCODE_MUTE:       VirtualKey.Mute,
  # SDL_SCANCODE_VOLUMEDOWN:     VirtualKey.VolumeDown,
  # SDL_SCANCODE_VOLUMEUP:     VirtualKey.VolumeUp,
  # SDL_SCANCODE_POWER:      VirtualKey.Power,
  # SDL_SCANCODE_KP_EQUALS:    VirtualKey.KeypadEquals,
  # SDL_SCANCODE_KP_PLUSMINUS:   VirtualKey.KeypadPlusMinus,



  # SDL_SCANCODE_KP_COMMA:     VirtualKey.KeypadComma,

  # SDL_SCANCODE_LGUI:       VirtualKey.LeftGUI,
  # SDL_SCANCODE_RGUI:       VirtualKey.RightGUI,
  # SDL_SCANCODE_STOP:       VirtualKey.Stop,
  # SDL_SCANCODE_AGAIN:      VirtualKey.Again,
  # SDL_SCANCODE_UNDO:       VirtualKey.Undo,
  # SDL_SCANCODE_COPY:       VirtualKey.Copy,
  # SDL_SCANCODE_PASTE:      VirtualKey.Paste,
  # SDL_SCANCODE_FIND:       VirtualKey.Find,
  # SDL_SCANCODE_CUT:        VirtualKey.Cut,
  # SDL_SCANCODE_HELP:       VirtualKey.Help,
  # SDL_SCANCODE_MENU:       VirtualKey.Menu,
  # SDL_SCANCODE_CALCULATOR:     VirtualKey.Calculator,
  # SDL_SCANCODE_SLEEP:      VirtualKey.Sleep,
  # SDL_SCANCODE_MAIL:       VirtualKey.Mail,
  # SDL_SCANCODE_AC_BOOKMARKS:   VirtualKey.AcBookmarks,
  # SDL_SCANCODE_COMPUTER:     VirtualKey.Computer,
  # SDL_SCANCODE_AC_BACK:      VirtualKey.AcBack,
  # SDL_SCANCODE_AC_FORWARD:     VirtualKey.AcForward,
  # SDL_SCANCODE_EJECT:      VirtualKey.Eject,
  # SDL_SCANCODE_AUDIONEXT:    VirtualKey.AudioNext,
  # SDL_SCANCODE_AUDIOPLAY:    VirtualKey.AudioPlay,
  # SDL_SCANCODE_AUDIOPREV:    VirtualKey.AudioPrev,
  # SDL_SCANCODE_AC_HOME:      VirtualKey.AcHome,
  # SDL_SCANCODE_AC_REFRESH:     VirtualKey.AcRefresh,
  # SDL_SCANCODE_KP_LEFTPAREN:   VirtualKey.KeypadLeftPar,
  # SDL_SCANCODE_KP_RIGHTPAREN:  VirtualKey.KeypadRightPar,
  # SDL_SCANCODE_AC_SEARCH:    VirtualKey.AcSearch,
  # SDL_SCANCODE_ALTERASE:     VirtualKey.AltErase,
  # SDL_SCANCODE_CANCEL:       VirtualKey.Cancel,
  # SDL_SCANCODE_BRIGHTNESSDOWN:   VirtualKey.BrightnessDown,
  # SDL_SCANCODE_BRIGHTNESSUP:   VirtualKey.BrightnessUp,
  # SDL_SCANCODE_DISPLAYSWITCH:  VirtualKey.DisplaySwitch,
  # SDL_SCANCODE_KBDILLUMTOGGLE:   VirtualKey.IlluminateToggle,
  # SDL_SCANCODE_KBDILLUMDOWN:   VirtualKey.IlluminateDown,
  # SDL_SCANCODE_KBDILLUMUP:     VirtualKey.IlluminateUp
}.toTable()

template virtualKeyFromNative*(kc: int): VirtualKey = virtualKeyMapping.getOrDefault(kc)
