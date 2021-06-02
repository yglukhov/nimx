import portable_gl

type
    CompiledComposition* = ref object
        program*: ProgramRef
        uniformLocations*: seq[UniformLocation]
        iTexIndex*: GLint
        iUniform*: int

    PostEffect* = ref object
        source*: string
        setupProc*: proc(cc: CompiledComposition)
        mainProcName*: string
        seenFlag*: bool # Used on compilation phase, should not be used elsewhere.
        id*: int
        argTypes*: seq[string]

    PostEffectStackElem* = object
        postEffect*: PostEffect
        setupProc*: proc(cc: CompiledComposition)
