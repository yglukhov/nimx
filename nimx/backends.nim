type OsApi* {.pure.} = enum
  web
  android
  ios
  macosx
  linux
  windows

type WindowApi* {.pure.} = enum
  web
  sdl
  x11
  appkit
  winapi

type InputApi* {.pure.} = enum
  web
  sdl
  x11
  appkit
  winapi

type GraphicApi* {.pure.} = enum
  opengles2

type AudioApi* {.pure.} = enum
  web
  sdl
  appkit
  winapi

type Backend* = tuple
  os: OsApi
  win: WindowApi
  input: InputApi
  gfx: GraphicApi
  audio: AudioApi

const backend*: Backend = 
  when defined js:
    (OsApi.web, WindowApi.web, InputApi.web, GraphicApi.opengles2, AudioApi.web)
  elif defined emscripten:
    (OsApi.web, WindowApi.web, InputApi.web, GraphicApi.opengles2, AudioApi.web)
  elif defined wasm:
    (OsApi.web, WindowApi.web, InputApi.web, GraphicApi.opengles2, AudioApi.web)
  elif defined ios:
    (OsApi.ios, WindowApi.sdl, InputApi.sdl, GraphicApi.opengles2, AudioApi.sdl)
  elif defined android:
    (OsApi.android, WindowApi.sdl, InputApi.sdl, GraphicApi.opengles2, AudioApi.sdl)
  elif defined macosx:
    (OsApi.macosx, WindowApi.sdl, InputApi.sdl, GraphicApi.opengles2, AudioApi.sdl)
  elif defined linux:
    (OsApi.linux, WindowApi.sdl, InputApi.sdl, GraphicApi.opengles2, AudioApi.sdl)
  elif defined windows:
    (OsApi.windows, WindowApi.sdl, InputApi.sdl, GraphicApi.opengles2, AudioApi.sdl)
  else: {.error: "unknown backend".}


const web* = backend.os == OsApi.web
const mobile* = defined(ios) or defined(android)
