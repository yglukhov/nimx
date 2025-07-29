import nimx/naketools
import osproc

beforeBuild = proc(b: Builder) =
  b.disableClosureCompiler = true
  b.mainFile = "tests/main"
  b.originalResourcePath = "test/res"
  b.screenOrientation = "sensorLandscape"
  b.additionalNimFlags = @["--gc:orc"]
  #b.targetArchitectures = @["armeabi-v7a", "arm64-v8a", "x86_64"]
  b.targetArchitectures = @["x86"]
  b.androidApi = 21

task "samples", "Build and run samples":
  newBuilder().build()

task "tests", "Build and run autotests":
  let b = newBuilder()

  if b.platform == "js":
    b.runAfterBuild = false

  b.additionalNimFlags.add "-d:runAutoTests"
  b.build()

  if b.platform == "js":
    b.runAutotestsInFirefox()

task "docs", "Build documentation":
  createDir "./build/doc"
  withDir "./build/doc":
    for t, f in walkDir "../../nimx":
      if f.endsWith(".nim"):
        shell "nim doc2 -d:js " & f & " &>/dev/null"

    for t, f in walkDir "../../doc":
      if f.endsWith(".rst"):
        direShell "nim rst2html " & f & " &>/dev/null"

    copyDir "../js", "./livedemo"
