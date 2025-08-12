when defined(js) or defined(wasm): {.error: "This file can not be used in wasm mode".}

import os, dynlib, strutils

const fontSearchPaths = when defined(macosx):
  [
    "/Library/Fonts"
  ]
elif defined(android):
  [
    "/system/fonts"
  ]
elif defined(windows):
  [
    r"c:\Windows\Fonts" #todo: system will not always in the c disk
  ]
elif defined(emscripten) or defined(wasm):
  [
    "res"
  ]
elif defined(haiku):
  [
    "/system/data/fonts/otfonts",
    "/system/data/fonts/ttfonts"
  ]
else:
  [
    "/usr/share/fonts/truetype",
    "/usr/share/fonts/truetype/ubuntu-font-family",
    "/usr/share/fonts/TTF",
    "/usr/share/fonts/truetype/dejavu",
    "/usr/share/fonts/dejavu",
    "/usr/share/fonts"
  ]

iterator potentialFontFilesForFace*(face: string): string =
  for sp in fontSearchPaths:
    yield sp / face & ".ttf"
  when not defined(emscripten) and not defined(wasm):
    yield getAppDir() / "res" / face & ".ttf"
    yield getAppDir() /../ "Resources" / face & ".ttf"
    yield getAppDir() / face & ".ttf"


const useLibfontconfig = defined(posix) and not defined(android) and not defined(ios) and not defined(emscripten) and not defined(wasm)


when useLibfontconfig:
  type
    Config = ptr object
    Pattern = ptr object

    FontConfigLib = ptr object
      m: LibHandle
      patternCreate: proc(): Pattern {.cdecl, gcsafe.}
      patternAddString: proc(p: Pattern, k, v: cstring): cint {.cdecl, gcsafe.}
      patternAddInteger: proc(p: Pattern, k: cstring, v: cint): cint {.cdecl, gcsafe.}
      configSubstitute: proc(c: Config, p: Pattern, kind: cint): cint {.cdecl, gcsafe.}
      defaultSubstitute: proc(p: Pattern) {.cdecl, gcsafe.}
      fontMatch: proc(c: Config, p: Pattern, res: ptr cint): Pattern {.cdecl, gcsafe.}
      patternGetString: proc(p: Pattern, obj: cstring, n: cint, s: var cstring): cint {.cdecl, gcsafe.}
      patternGetInteger: proc(p: Pattern, obj: cstring, n: cint, s: var cint): cint {.cdecl, gcsafe.}
      patternDestroy: proc(p: Pattern) {.cdecl, gcsafe.}
      configAppFontAddDir: proc(c: Config, d: cstring): cint {.cdecl, gcsafe.}

  var fcLib: FontConfigLib

  proc load(l: FontConfigLib) =
    l.m = loadLib("libfontconfig.so")
    if l.m.isNil: return

    template p(s: untyped, t: untyped) =
      l.s = cast[typeof(l.s)](symAddr(l.m, astToStr(t)))
      if l.s.isNil:
        unloadLib(l.m)
        l.m = nil
        return

    p patternCreate, FcPatternCreate
    p patternAddString, FcPatternAddString
    p patternAddInteger, FcPatternAddInteger
    p configSubstitute, FcConfigSubstitute
    p defaultSubstitute, FcDefaultSubstitute
    p fontMatch, FcFontMatch
    p patternGetString, FcPatternGetString
    p patternGetInteger, FcPatternGetInteger
    p patternDestroy, FcPatternDestroy
    p configAppFontAddDir, FcConfigAppFontAddDir

    when defined(linux):
      discard fcLib.configAppFontAddDir(nil, getAppDir() / "res")
    elif defined(macosx):
      discard fcLib.configAppFontAddDir(nil, getAppDir() /../ "Resources")

  proc getFcWeight(face: var string, weightSymbol: string): bool =
    # face and weightSymbol must be lowercase!
    # Find weightSymbol in face. e.g. face ends with "-Bold"
    # and weightSymbol is "bold. If found modify modify face so
    # that it doesn't contain weight, and return true. Return false
    # otherwise.
    let lSuffix = "-" & weightSymbol
    result = face.endsWith(lSuffix)
    if result:
      face.delete(face.len - lSuffix.len, face.high)

  proc findFontFileForFaceAux(face: string): string =
    if unlikely fcLib.isNil:
      fcLib = cast[FontConfigLib](alloc0(sizeof(fcLib[])))
      load(fcLib)

    if fcLib.m.isNil: return

    proc getString(p: Pattern, k: cstring, n: cint): string =
      var t: cstring
      if fcLib.patternGetString(p, k, n, t) == 0:
        result = $t

    let pat = fcLib.patternCreate()
    var face = face.toLowerAscii
    if getFcWeight(face, "black"):
      discard fcLib.patternAddString(pat, "family", face.cstring)
      discard fcLib.patternAddInteger(pat, "weight", 210)
    elif getFcWeight(face, "bold"):
      discard fcLib.patternAddString(pat, "family", face.cstring)
      discard fcLib.patternAddInteger(pat, "weight", 200)
    elif getFcWeight(face, "regular"):
      discard fcLib.patternAddString(pat, "family", face.cstring)
      discard fcLib.patternAddInteger(pat, "weight", 80)
    else:
      discard fcLib.patternAddString(pat, "family", face.cstring)

    discard fcLib.patternAddString(pat, "fontformat", "TrueType")

    discard fcLib.configSubstitute(nil, pat, 0)
    fcLib.defaultSubstitute(pat)
    var res: cint
    let match = fcLib.fontMatch(nil, pat, addr res)

    result = match.getString("file", 0)

    # var index: cint
    # discard fcLib.patternGetInteger(match, "index", 0, index)

    fcLib.patternDestroy(pat)
    fcLib.patternDestroy(match)

    # TODO: Our glyph rasterizer (stb_truetype) supports only ttf.
    # We should have gotten a ttf file by now, but verify it
    # just in case.
    if not result.endsWith(".ttf"):
      result = ""

proc findFontFileForFace*(face: string): string =
  when useLibfontconfig:
    result = findFontFileForFaceAux(face)
    if result.len != 0: return

  for f in potentialFontFilesForFace(face):
      if fileExists(f):
          return f
