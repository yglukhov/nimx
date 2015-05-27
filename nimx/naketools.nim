
proc externToolArgs(tool: string, args: openarray[string]): string
    result = ""
    for i in args:
        for j in i.split(" "):
            result &= "--" & tool & ":" & j & " "

proc ldArgs*(args: varargs[string]): string = externToolArgs("passL", args)
proc ccArgs*(args: varargs[string]): string = externToolArgs("passC", args)


type Builder* = object of RootObj
    command: string


type NativeBuilder* = object of Builder

type IOSBuilder* = object of NativeBuilder
type MacOSBuilder* = object of NativeBuilder
type AndroidBuilder* = object of NativeBuilder
type JSBuilder* object of Buidler

method build(builder: Builder) = discard

