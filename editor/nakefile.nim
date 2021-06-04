import nimx/naketools

beforeBuild = proc(b: Builder) =
  b.disableClosureCompiler = true
  b.mainFile = "nimxedit"
  b.appName = "nimxedit"
  b.originalResourcePath = "res"

preprocessResources = proc(b: Builder) =
  for f in walkDirRec("res"):
    let sf = f.splitFile()
    if sf.ext == ".nimx":
      b.copyResourceAsIs(f.replace("res/", ""))

task "debug", "Build for debugging":
    let b = newBuilder()
    b.additionalNimFlags.add "--debugger:on"
    b.runAfterBuild = false
    b.build()
