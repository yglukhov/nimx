import nimx.naketools

beforeBuild = proc(b: Builder) =
    b.disableClosureCompiler = true
    b.mainFile = "nimxedit"
    b.appName = "nimxedit"
