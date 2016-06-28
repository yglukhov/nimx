import nimx.naketools

beforeBuild = proc(b: Builder) =
    b.mainFile = "nimxedit"
