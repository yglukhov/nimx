import std/[math, streams, logging, strutils]
import types, gpu_types, mini_profiler
import ./assets/[ asset_loading, url_stream, asset_manager ]
import ./serializers

const web = defined(wasm)

when not web:
  import load_image_impl

type
  Image* = ref object of RootObj
    texCoords*: array[4, Coord]
    mSize: Size
    texWidth*, texHeight*: int16

  SelfContainedImage* = ref SelfContainedImageObj
  SelfContainedImageObj = object of Image
    texture*: TextureRef
    pixels*: seq[byte]
    pixelWidth*, pixelHeight*: int
    mFilePath: string

  FixedTexCoordSpriteImage* = ref object of Image
    spriteSheet: Image

method setFilePath*(i: Image, path: string) {.gcsafe, base.} = discard
method setFilePath*(i: SelfContainedImage, path: string) = i.mFilePath = path

method filePath*(i: Image): string {.gcsafe, base.} = ""
method filePath*(i: SelfContainedImage): string = i.mFilePath

proc newSelfContainedImage(): SelfContainedImage {.inline.} =
  result.new()

proc imageWithResource*(name: string): Image =
  result = sharedAssetManager().cachedAsset(Image, name)

proc imageWithSize*(size: Size): SelfContainedImage =
  result = newSelfContainedImage()
  result.mSize = size
  result.texWidth = max(1, nextPowerOfTwo(size.width.int)).int16
  result.texHeight = max(1, nextPowerOfTwo(size.height.int)).int16
  result.texCoords = [0.Coord, 0, size.width / result.texWidth.Coord, size.height / result.texHeight.Coord]

method isLoaded*(i: Image): bool {.base, gcsafe.} = false
method isLoaded*(i: SelfContainedImage): bool = true
method isLoaded*(i: FixedTexCoordSpriteImage): bool = i.spriteSheet.isLoaded

method getTextureQuad*(i: Image, texCoords: var array[4, Coord]): TextureRef {.base, gcsafe.} =
  texCoords = [0.Coord, 0, 1, 1]

method getTextureQuad*(i: SelfContainedImage, texCoords: var array[4, Coord]): TextureRef =
  texCoords = i.texCoords
  result = i.texture

method getTextureQuad*(i: FixedTexCoordSpriteImage, texCoords: var array[4, Coord]): TextureRef =
  result = i.spriteSheet.getTextureQuad(texCoords)
  texCoords = i.texCoords

proc size*(i: Image): Size {.inline.} = i.mSize

method serialize*(s: Serializer, v: Image) {.base, gcsafe.} =
  var path = ""
  if v of SelfContainedImage:
    path = v.SelfContainedImage.mFilePath
  s.serialize("imagePath", path)

method deserialize*(s: Deserializer, v: var Image) {.base, gcsafe.} =
  var imagePath: string
  s.deserialize("imagePath", imagePath)
  if imagePath.len > 0:
    v = imageWithResource(imagePath)

when not web:
  proc initWithBitmap*(i: SelfContainedImage, data: ptr uint8, x, y, comp: int) =
    i.mSize = newSize(x.Coord, y.Coord)
    i.texWidth = max(1, nextPowerOfTwo(x)).int16
    i.texHeight = max(1, nextPowerOfTwo(y)).int16
    i.texCoords = [0.Coord, 0, x.Coord / i.texWidth.Coord, y.Coord / i.texHeight.Coord]
    i.pixelWidth = x
    i.pixelHeight = y
    i.pixels = newSeq[byte](x * y * 4)
    for p in 0 ..< x * y:
      let src = cast[ptr UncheckedArray[byte]](data)
      case comp
      of 1:
        i.pixels[p * 4 + 0] = 255
        i.pixels[p * 4 + 1] = 255
        i.pixels[p * 4 + 2] = 255
        i.pixels[p * 4 + 3] = src[p]
      of 2:
        i.pixels[p * 4 + 0] = src[p * 2]
        i.pixels[p * 4 + 1] = src[p * 2]
        i.pixels[p * 4 + 2] = src[p * 2]
        i.pixels[p * 4 + 3] = src[p * 2 + 1]
      of 3:
        i.pixels[p * 4 + 0] = src[p * 3]
        i.pixels[p * 4 + 1] = src[p * 3 + 1]
        i.pixels[p * 4 + 2] = src[p * 3 + 2]
        i.pixels[p * 4 + 3] = 255
      else:
        i.pixels[p * 4 + 0] = src[p * 4]
        i.pixels[p * 4 + 1] = src[p * 4 + 1]
        i.pixels[p * 4 + 2] = src[p * 4 + 2]
        i.pixels[p * 4 + 3] = src[p * 4 + 3]

  proc imageWithBitmap*(data: ptr uint8, x, y, comp: int): SelfContainedImage =
    result = newSelfContainedImage()
    result.initWithBitmap(data, x, y, comp)

  proc initWithContentsOfFile*(i: SelfContainedImage, path: string) =
    var x, y, comp: cint
    let data = stbi_load(path.cstring, addr x, addr y, addr comp, 0)
    if data.isNil:
      raise newException(IOError, "Could not load image: " & path)
    i.initWithBitmap(data, x.int, y.int, comp.int)
    stbi_image_free(data)
    i.setFilePath(path)

  proc imageWithContentsOfFile*(path: string): SelfContainedImage =
    result = newSelfContainedImage()
    result.initWithContentsOfFile(path)

proc subimageWithTexCoords*(i: Image, s: Size, texCoords: array[4, Coord]): FixedTexCoordSpriteImage =
  result.new()
  result.spriteSheet = i
  result.mSize = s
  result.texCoords = texCoords
  result.texWidth = i.texWidth
  result.texHeight = i.texHeight

proc flipVertically*(i: SelfContainedImage) {.inline.} = swap(i.texCoords[1], i.texCoords[3])
proc flipped*(i: Image): bool {.inline.} = i.texCoords[1] > i.texCoords[3]

proc backingSize*(i: Image): Size =
  result.width = i.texWidth.float32 * (i.texCoords[2] - i.texCoords[0])
  result.height = i.texHeight.float32 * abs(i.texCoords[1] - i.texCoords[3])

proc backingRect*(i: Image): Rect =
  result.origin.x = i.texWidth.float32 * i.texCoords[0]
  result.origin.y = i.texHeight.float32 * min(i.texCoords[1], i.texCoords[3])
  result.size = i.backingSize

proc resetToSize*(i: SelfContainedImage, size: Size) =
  i.mSize = size
  i.texWidth = max(1, nextPowerOfTwo(size.width.int)).int16
  i.texHeight = max(1, nextPowerOfTwo(size.height.int)).int16
  i.texCoords = [0.Coord, 0, size.width / i.texWidth.Coord, size.height / i.texHeight.Coord]

proc generateMipmap*(i: SelfContainedImage) = discard

when not web:
  proc writeToBMPFile*(i: Image, path: string) = discard
  proc writeToPNGFile*(i: Image, path: string) = discard
  proc writeToTGAFile*(i: Image, path: string) = discard

when not web:
  import ./http_request
  proc loadImageFromURL*(url: string, callback: proc(i: Image) {.gcsafe.}) =
    if url.startsWith("file://"):
      try:
        callback(imageWithContentsOfFile(url.substr(7)))
      except:
        callback(nil)
    else:
      sendRequest("GET", url, "", []) do(r: Response):
        if r.statusCode >= 200 and r.statusCode < 300 and r.body.len > 0:
          var x, y, comp: cint
          var body = r.body
          let data = stbi_load_from_memory(cast[ptr uint8](addr body[0]), body.len.cint, addr x, addr y, addr comp, 0)
          if data.isNil:
            callback(nil)
          else:
            let img = imageWithBitmap(data, x.int, y.int, comp.int)
            stbi_image_free(data)
            img.setFilePath(url)
            callback(img)
        else:
          callback(nil)
else:
  proc loadImageFromURL*(url: string, callback: proc(i: Image)) = callback(nil)

registerAssetLoader(["png", "jpg", "jpeg", "gif", "tif", "tiff", "tga", "webp"]) do(url: string, handler: proc(i: Image) {.gcsafe.}):
  when not web:
    try:
      let i = imageWithContentsOfFile(url)
      handler(i)
    except Exception as e:
      warn "Could not load image: ", url, ": ", e.msg
      handler(nil)
  else:
    handler(nil)
