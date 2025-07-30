when defined(js):
  proc isMacOsAux(): bool =
    {.emit: """
    try {
      `result` = navigator.platform.indexOf("Mac") != -1;
    } catch(e) {}
    """.}
  let isMacOs* = isMacOsAux()
elif defined(emscripten):
  import jsbind/emscripten
  proc isMacOsAux(): bool =
    let r = EM_ASM_INT("""
    try {
      return navigator.platform.indexOf("Mac") != -1;
    } catch(e) {}
    """)
    result = cast[bool](r)
  let isMacOs* = isMacOsAux()
elif defined(wasm):
  import wasmrt
  proc isMacOsAux(): bool {.importwasmp: """navigator.platform.indexOf("Mac")""".}
  let isMacOs* = isMacOsAux()
