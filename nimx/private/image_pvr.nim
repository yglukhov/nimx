import ../[types, gpu_types]

proc isPVRHeader*(data: openarray[byte]): bool = false
proc loadPVRDataToTexture*(data: ptr uint8, texture: var TextureRef, size: var Size, texCoords: var array[4, Coord]) = discard
