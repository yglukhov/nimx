include "../nimx/naketools"

beforeBuild = proc(b: Builder) =
  b.disableClosureCompiler = true
  if b.platform == "emscripten":
    b.additionalCompilerFlags.add("-g4")

task "em", "Emscripten":
  let b = newBuilder("emscripten")
  b.build()
