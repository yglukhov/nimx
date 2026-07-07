import wgpu

var currentWgpuDevice* {.threadvar.}: Device

type
  GpuScalar* = float32
  TextureRef* = Texture
  BufferRef* = Buffer

proc isEmpty*(t: TextureRef): bool {.inline.} = t.isNil
proc isEmpty*(b: BufferRef): bool {.inline.} = b.isNil
