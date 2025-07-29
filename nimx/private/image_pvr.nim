
type PVRTextureHeaderV3 {.packed.} = object
  version: uint32
  flags: uint32
  pixelFormat: uint64
  colourSpace: uint32
  channelType: uint32
  height: uint32
  width: uint32
  depth: uint32
  numSurfaces: uint32
  numFaces: uint32
  numMipmaps: uint32
  metaDataSize: uint32

type ePVR3Format* = enum
  PVR3_PVRTC_2BPP_RGB = 0,
  PVR3_PVRTC_2BPP_RGBA = 1,
  PVR3_PVRTC_4BPP_RGB = 2,
  PVR3_PVRTC_4BPP_RGBA = 3,
  PVR3_PVRTC2_2BPP = 4,
  PVR3_PVRTC2_4BPP = 5,
  PVR3_ETC1 = 6,
  PVR3_DXT1_OR_BC1 = 7,
  PVR3_DXT2 = 8,
  PVR3_DXT3_OR_BC2 = 9,
  PVR3_DXT4 = 10,
  PVR3_DXT5_OR_BC3 = 11,
  PVR3_BC4 = 12,
  PVR3_BC5 = 13,
  PVR3_BC6 = 14,
  PVR3_BC7 = 15,
  PVR3_UYVY = 16,
  PVR3_YUY2 = 17,
  PVR3_BW_1BPP = 18,
  PVR3_R9G9B9E5 = 19,
  PVR3_RGBG8888 = 20,
  PVR3_GRGB8888 = 21,
  PVR3_ETC2_RGB = 22,
  PVR3_ETC2_RGBA = 23,
  PVR3_ETC2_RGB_A1 = 24,
  PVR3_EAC_R11_U = 25,
  PVR3_EAC_R11_S = 26,
  PVR3_EAC_RG11_U = 27,
  PVR3_EAC_RG11_S = 28,

proc loadPVRDataToTexture(data: ptr uint8, texture: var TextureRef, size: var Size, texCoords: var array[4, GLfloat]) =
  let header = cast[ptr PVRTextureHeaderV3](data)

  texCoords[2] = 1.0
  texCoords[3] = 1.0

  # dimensions
  let width = header.width
  let height = header.height
  #self.size = CGSizeMake((float)width/self.scale, (float)height/self.scale);
  #self.textureSize = CGSizeMake(width, height);
  #self.clipRect = CGRectMake(0.0f, 0.0f, width, height);
  #self.contentRect = CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);

  # used for caching
  #self.cost = [data length] - header->headerLength;

  #alpha
  #self.premultipliedAlpha = YES;

  size.width = Coord(width)
  size.height = Coord(height)

  # format
  var compressed = false
  var typ: GLenum
  var format: GLenum
  var bpp: GLsizei

  let pf = ePVR3Format(header.pixelFormat and 0xff)
  case pf
  of PVR3_ETC2_RGBA:
    compressed = true
    format = GL_COMPRESSED_RGBA8_ETC2_EAC
    bpp = 8
#    typ = GL_UNSIGNED_SHORT_4_4_4_4
  else:
    raise newException(Exception, "Unsupported format: " & $pf)

  # create texture
  glGenTextures(1, addr texture)
  glBindTexture(GL_TEXTURE_2D, texture)
  let filter = GLint(if header.numMipmaps == 1: GL_LINEAR else: GL_LINEAR_MIPMAP_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  var offset = sizeof(PVRTextureHeaderV3).uint + header.metaDataSize.uint
  let nm = header.numMipmaps
  var i = 0'u32
  while i < nm:
    let mipmapWidth = GLsizei(width shr i)
    let mipmapHeight = GLsizei(height shr i)
    var pixelBytes = GLsizei(mipmapWidth * mipmapHeight * bpp / 8)
    let pImageData = cast[pointer](cast[uint](data) + offset)
    if compressed:
      pixelBytes = max(32, pixelBytes);
      glCompressedTexImage2D(GL_TEXTURE_2D, i.GLint, format, mipmapWidth, mipmapHeight, 0,
                   pixelBytes, pImageData)
    else:
      glTexImage2D(GL_TEXTURE_2D, i.GLint, format.GLint, mipmapWidth, mipmapHeight,
             0, format, typ, pImageData)
    offset += pixelBytes.uint
    inc i

proc isPVRHeader*(data: openarray[byte]): bool =
  assert(data.len >= 4)
  let u = cast[ptr uint32](unsafeAddr data[0])[]
  u == 0x03525650 or u == 0x50565203
