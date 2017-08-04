
import opengl
# export opengl

export GLuint, GLint, GLfloat, GLenum, GLsizei, GLushort, GLbitfield, opengl.`or`

when defined js:
    type
        FramebufferRef* = ref FramebufferObj
        FramebufferObj {.importc.} = object

        RenderbufferRef* = ref RenderbufferObj
        RenderbufferObj {.importc.} = object

        TextureRef* = ref TextureObj
        TextureObj {.importc.} = object

        UniformLocation* = ref UniformLocationObj
        UniformLocationObj {.importc.} = object

        ProgramRef* = ref ProgramObj
        ProgramObj {.importc.} = object

        ShaderRef* = ref ShaderObj
        ShaderObj {.importc.} = object

        BufferRef* = ref BufferObj
        BufferObj {.importc.} = object

        GL* = ref GLObj
        GLObj {.importc.} = object
            VERTEX_SHADER* : GLenum
            FRAGMENT_SHADER* : GLenum
            TEXTURE_2D* : GLenum
            ONE_MINUS_SRC_ALPHA*, ONE_MINUS_DST_ALPHA*, SRC_ALPHA*, DST_ALPHA*, ONE*, DST_COLOR*, CONSTANT_COLOR*, ONE_MINUS_SRC_COLOR*: GLenum
            BLEND* : GLenum
            TRIANGLES*, TRIANGLE_FAN*, TRIANGLE_STRIP*, LINES*, LINE_LOOP* : GLenum
            COLOR_BUFFER_BIT*: int
            STENCIL_BUFFER_BIT*: int
            DEPTH_BUFFER_BIT*: int
            TEXTURE_MIN_FILTER*, TEXTURE_MAG_FILTER*, TEXTURE_WRAP_S*, TEXTURE_WRAP_T*: GLenum
            LINEAR*, NEAREST*, CLAMP_TO_EDGE*, LINEAR_MIPMAP_NEAREST* : GLint
            PACK_ALIGNMENT*, UNPACK_ALIGNMENT*: GLenum
            FRAMEBUFFER* : GLenum
            RENDERBUFFER* : GLenum
            ARRAY_BUFFER* : GLenum
            ELEMENT_ARRAY_BUFFER* : GLenum
            R16F* : GLenum
            R32F* : GLenum
            RED* : GLenum
            RGBA* : GLenum
            RGBA16F*: GLenum
            ALPHA*, LUMINANCE* : GLenum
            UNSIGNED_BYTE* : GLenum
            COLOR_ATTACHMENT0* : GLenum
            DEPTH_ATTACHMENT*, STENCIL_ATTACHMENT*, DEPTH_STENCIL_ATTACHMENT* : GLenum
            DEPTH_COMPONENT16*, STENCIL_INDEX8* : GLenum
            DEPTH_STENCIL* : GLenum
            DEPTH24_STENCIL8* : GLenum
            FRAMEBUFFER_BINDING : GLenum
            RENDERBUFFER_BINDING : GLenum
            STENCIL_TEST*, DEPTH_TEST*, SCISSOR_TEST* : GLenum
            MAX_TEXTURE_SIZE*: GLenum
            NEVER*, LESS*, LEQUAL*, GREATER*, GEQUAL*, EQUAL*, NOTEQUAL*, ALWAYS*: GLenum
            KEEP*, ZERO*, REPLACE*, INCR*, INCR_WRAP*, DECR*, DECR_WRAP*, INVERT*: GLenum

            STREAM_DRAW*, STREAM_READ*, STREAM_COPY*, STATIC_DRAW*, STATIC_READ*,
                STATIC_COPY*, DYNAMIC_DRAW*, DYNAMIC_READ*, DYNAMIC_COPY* : GLenum

            FLOAT*, UNSIGNED_SHORT* : GLenum
            TEXTURE0*: GLenum

            CULL_FACE*, FRONT*, BACK*, FRONT_AND_BACK* : GLenum

            BUFFER_SIZE* : GLenum

    const invalidUniformLocation* : UniformLocation = nil
    const invalidProgram* : ProgramRef = nil
    const invalidShader* : ShaderRef = nil
    const invalidBuffer* : BufferRef = nil
    const invalidFrameBuffer* : FramebufferRef = nil
    const invalidRenderBuffer* : RenderbufferRef = nil
    const invalidTexture* : TextureRef = nil

    {.push importcpp.}

    proc compileShader*(gl: GL, shader: ShaderRef)
    proc deleteShader*(gl: GL, shader: ShaderRef)
    proc deleteProgram*(gl: GL, prog: ProgramRef)
    proc attachShader*(gl: GL, prog: ProgramRef, shader: ShaderRef)
    proc detachShader*(gl: GL, prog: ProgramRef, shader: ShaderRef)

    proc linkProgram*(gl: GL, prog: ProgramRef)
    proc drawArrays*(gl: GL, mode: GLenum, first: GLint, count: GLsizei)
    proc drawElements*(gl: GL, mode: GLenum, count: GLsizei, typ: GLenum, offset: int = 0)
    proc createShader*(gl: GL, shaderType: GLenum): ShaderRef
    proc createProgram*(gl: GL): ProgramRef
    proc createTexture*(gl: GL): TextureRef
    proc createFramebuffer*(gl: GL): FramebufferRef
    proc createRenderbuffer*(gl: GL): RenderbufferRef
    proc createBuffer*(gl: GL): BufferRef
    proc bufferData*(gl: GL, target: GLenum, size: int32, usage: GLenum)

    proc deleteFramebuffer*(gl: GL, name: FramebufferRef)
    proc deleteRenderbuffer*(gl: GL, name: RenderbufferRef)
    proc deleteBuffer*(gl: GL, name: BufferRef)
    proc deleteTexture*(gl: GL, name: TextureRef)

    proc bindAttribLocation*(gl: GL, program: ProgramRef, index: GLuint, name: cstring)
    proc enableVertexAttribArray*(gl: GL, attrib: GLuint)
    proc disableVertexAttribArray*(gl: GL, attrib: GLuint)
    proc vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, typ: GLenum,
        normalized: GLboolean, stride: GLsizei, offset: int)

    proc getUniformLocation*(gl: GL, prog: ProgramRef, name: cstring): UniformLocation
    proc useProgram*(gl: GL, prog: ProgramRef)
    proc enable*(gl: GL, flag: GLenum)
    proc disable*(gl: GL, flag: GLenum)
    proc isEnabled*(gl: GL, flag: GLenum): bool
    proc viewport*(gl: GL, x, y: GLint, width, height: GLsizei)
    proc clear*(gl: GL, mask: int)
    proc activeTexture*(gl: GL, t: GLenum)
    proc bindTexture*(gl: GL, target: GLenum, name: TextureRef)
    proc bindFramebuffer*(gl: GL, target: GLenum, name: FramebufferRef)
    proc bindRenderbuffer*(gl: GL, target: GLenum, name: RenderbufferRef)
    proc bindBuffer*(gl: GL, target: GLenum, name: BufferRef)

    proc uniform1fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat])
    proc uniform2fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat])
    proc uniform3fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat])
    proc uniform3iv*(gl: GL, location: UniformLocation, data: openarray[GLint])
    proc uniform4fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat])
    proc uniform1f*(gl: GL, location: UniformLocation, data: GLfloat)
    proc uniform1i*(gl: GL, location: UniformLocation, data: GLint)
    proc uniformMatrix4fv*(gl: GL, location: UniformLocation, transpose: GLboolean, data: array[16, GLfloat])
    proc uniformMatrix3fv*(gl: GL, location: UniformLocation, transpose: GLboolean, data: array[9, GLfloat])

    proc clearColor*(gl: GL, r, g, b, a: GLfloat)
    proc clearStencil*(gl: GL, s: GLint)
    proc blendFunc*(gl: GL, sfactor, dfactor: GLenum)
    proc blendColor*(gl: GL, r, g, b, a: Glfloat)
    proc blendFuncSeparate*(gl: GL, sfactor, dfactor, sfactorA, dfactorA: GLenum)
    proc texParameteri*(gl: GL, target, pname: GLenum, param: GLint)

    proc texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: ref RootObj)
    proc texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: openarray)
    proc texSubImage2D*(gl: GL, target: GLenum, level: GLint, xoffset, yoffset: GLint, width, height: GLsizei, format, t: GLenum, pixels: openarray)
    proc generateMipmap*(gl: GL, target: GLenum)
    proc pixelStorei*(gl: GL, pname: GLenum, param: GLint)

    proc framebufferTexture2D*(gl: GL, target, attachment, textarget: GLenum, texture: TextureRef, level: GLint)
    proc renderbufferStorage*(gl: GL, target, internalformat: GLenum, width, height: GLsizei)
    proc framebufferRenderbuffer*(gl: GL, target, attachment, renderbuffertarget: GLenum, renderbuffer: RenderbufferRef)

    proc stencilFunc*(gl: GL, fun: GLenum, refe: GLint, mask: GLuint)
    proc stencilOp*(gl: GL, fail, zfail, zpass: GLenum)
    proc colorMask*(gl: GL, r, g, b, a: bool)
    proc depthMask*(gl: GL, d: bool)
    proc stencilMask*(gl: GL, m: GLuint)
    proc cullFace*(gl: GL, mode: GLenum)
    proc scissor*(gl: GL, x, y: GLint, width, height: GLsizei)

    proc getError*(gl: GL): GLenum

    {.pop.}

    proc getParameterRef(gl: GL, mode: GLenum): ref RootObj {.importcpp: "getParameter".}

    template isEmpty*(obj: TextureRef or FramebufferRef or RenderbufferRef): bool = obj.isNil

else:
    type
        GL* = ref object
        FramebufferRef* = GLuint
        RenderbufferRef* = GLuint
        BufferRef* = GLuint
        TextureRef* = GLuint
        UniformLocation* = GLint
        ProgramRef* = GLuint
        ShaderRef* = GLuint

    const invalidUniformLocation* : UniformLocation = -1
    const invalidProgram* : ProgramRef = 0
    const invalidShader* : ShaderRef = 0
    const invalidBuffer* : BufferRef = 0
    const invalidFrameBuffer* : FramebufferRef = 0
    const invalidRenderBuffer* : RenderbufferRef = 0
    const invalidTexture* : TextureRef = 0

    template VERTEX_SHADER*(gl: GL): GLenum = GL_VERTEX_SHADER
    template FRAGMENT_SHADER*(gl: GL): GLenum = GL_FRAGMENT_SHADER
    template TEXTURE_2D*(gl: GL): GLenum = GL_TEXTURE_2D
    template CONSTANT_COLOR*(gl: GL): GLenum = GL_CONSTANT_COLOR
    template ONE_MINUS_SRC_COLOR*(gl: GL): GLenum = GL_ONE_MINUS_SRC_COLOR
    template ONE_MINUS_SRC_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_SRC_ALPHA
    template ONE_MINUS_DST_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_DST_ALPHA
    template SRC_ALPHA*(gl: GL): GLenum = GL_SRC_ALPHA
    template DST_ALPHA*(gl: GL): GLenum = GL_DST_ALPHA
    template DST_COLOR*(gl: GL): GLenum = GL_DST_COLOR
    template ONE*(gl: GL): GLenum = GL_ONE
    template BLEND*(gl: GL): GLenum = GL_BLEND
    template TRIANGLES*(gl: GL): GLenum = GL_TRIANGLES
    template TRIANGLE_FAN*(gl: GL): GLenum = GL_TRIANGLE_FAN
    template TRIANGLE_STRIP*(gl: GL): GLenum = GL_TRIANGLE_STRIP
    template LINES*(gl: GL): GLenum = GL_LINES
    template LINE_LOOP*(gl: GL): GLenum = GL_LINE_LOOP
    template COLOR_BUFFER_BIT*(gl: GL): GLbitfield = GL_COLOR_BUFFER_BIT
    template STENCIL_BUFFER_BIT*(gl: GL): GLbitfield = GL_STENCIL_BUFFER_BIT
    template DEPTH_BUFFER_BIT*(gl: GL): GLbitfield = GL_DEPTH_BUFFER_BIT
    template TEXTURE_MIN_FILTER*(gl: GL): GLenum = GL_TEXTURE_MIN_FILTER
    template TEXTURE_MAG_FILTER*(gl: GL): GLenum = GL_TEXTURE_MAG_FILTER
    template TEXTURE_WRAP_S*(gl: GL): GLenum = GL_TEXTURE_WRAP_S
    template TEXTURE_WRAP_T*(gl: GL): GLenum = GL_TEXTURE_WRAP_T
    template LINEAR*(gl: GL): GLint = GL_LINEAR
    template NEAREST*(gl: GL): GLint = GL_NEAREST
    template CLAMP_TO_EDGE*(gl: GL): GLint = GL_CLAMP_TO_EDGE
    template LINEAR_MIPMAP_NEAREST*(gl: GL): GLint = GL_LINEAR_MIPMAP_NEAREST
    template PACK_ALIGNMENT*(gl: GL): GLenum = GL_PACK_ALIGNMENT
    template UNPACK_ALIGNMENT*(gl: GL): GLenum = GL_UNPACK_ALIGNMENT
    template FRAMEBUFFER*(gl: GL): GLenum = GL_FRAMEBUFFER
    template RENDERBUFFER*(gl: GL): GLenum = GL_RENDERBUFFER
    template ARRAY_BUFFER*(gl: GL): GLenum = GL_ARRAY_BUFFER
    template ELEMENT_ARRAY_BUFFER*(gl: GL): GLenum = GL_ELEMENT_ARRAY_BUFFER
    template RED*(gl: GL): GLenum = GL_RED
    template R16F*(gl: GL): GLenum = GL_R16F
    template R32F*(gl: GL): GLenum = GL_R32F
    template RGBA*(gl: GL): GLenum = GL_RGBA
    template RGBA16F*(gl: GL): GLenum = GL_RGBA16F
    template ALPHA*(gl: GL): GLenum = GL_ALPHA
    template LUMINANCE*(gl: GL): GLenum = GL_LUMINANCE
    template UNSIGNED_BYTE*(gl: GL): GLenum = GL_UNSIGNED_BYTE
    template COLOR_ATTACHMENT0*(gl: GL): GLenum = GL_COLOR_ATTACHMENT0
    template DEPTH_ATTACHMENT*(gl: GL): GLenum = GL_DEPTH_ATTACHMENT
    template STENCIL_ATTACHMENT*(gl: GL): GLenum = GL_STENCIL_ATTACHMENT
    template DEPTH_STENCIL_ATTACHMENT*(gl: GL): GLenum = GL_DEPTH_STENCIL_ATTACHMENT
    template DEPTH_COMPONENT16*(gl: GL): GLenum = GL_DEPTH_COMPONENT16
    template STENCIL_INDEX8*(gl: GL): GLenum = GL_STENCIL_INDEX8
    template DEPTH_STENCIL*(gl: GL): GLenum = GL_DEPTH_STENCIL
    template DEPTH24_STENCIL8*(gl: GL): GLenum = GL_DEPTH24_STENCIL8
    #template FRAMEBUFFER_BINDING(gl: GL): GLenum = GL_FRAMEBUFFER_BINDING
    #template RENDERBUFFER_BINDING(gl: GL): GLenum = GL_RENDERBUFFER_BINDING
    template STENCIL_TEST*(gl: GL): GLenum = GL_STENCIL_TEST
    template DEPTH_TEST*(gl: GL): GLenum = GL_DEPTH_TEST
    template SCISSOR_TEST*(gl: GL): GLenum = GL_SCISSOR_TEST
    template MAX_TEXTURE_SIZE*(gl: GL): GLenum = GL_MAX_TEXTURE_SIZE

    template NEVER*(gl: GL): GLenum = GL_NEVER
    template LESS*(gl: GL): GLenum = GL_LESS
    template LEQUAL*(gl: GL): GLenum = GL_LEQUAL
    template GREATER*(gl: GL): GLenum = GL_GREATER
    template GEQUAL*(gl: GL): GLenum = GL_GEQUAL
    template EQUAL*(gl: GL): GLenum = GL_EQUAL
    template NOTEQUAL*(gl: GL): GLenum = GL_NOTEQUAL
    template ALWAYS*(gl: GL): GLenum = GL_ALWAYS

    template KEEP*(gl: GL): GLenum = GL_KEEP
    template ZERO*(gl: GL): GLenum = GL_ZERO
    template REPLACE*(gl: GL): GLenum = GL_REPLACE
    template INCR*(gl: GL): GLenum = GL_INCR
    template INCR_WRAP*(gl: GL): GLenum = GL_INCR_WRAP
    template DECR*(gl: GL): GLenum = GL_DECR
    template DECR_WRAP*(gl: GL): GLenum = GL_DECR_WRAP
    template INVERT*(gl: GL): GLenum = GL_INVERT

    template STREAM_DRAW*(gl: GL): GLenum = GL_STREAM_DRAW
    template STREAM_READ*(gl: GL): GLenum = GL_STREAM_READ
    template STREAM_COPY*(gl: GL): GLenum = GL_STREAM_COPY
    template STATIC_DRAW*(gl: GL): GLenum = GL_STATIC_DRAW
    template STATIC_READ*(gl: GL): GLenum = GL_STATIC_READ
    template STATIC_COPY*(gl: GL): GLenum = GL_STATIC_COPY
    template DYNAMIC_DRAW*(gl: GL): GLenum = GL_DYNAMIC_DRAW
    template DYNAMIC_READ*(gl: GL): GLenum = GL_DYNAMIC_READ
    template DYNAMIC_COPY*(gl: GL): GLenum = GL_DYNAMIC_COPY

    template FLOAT*(gl: GL): GLenum = cGL_FLOAT
    template UNSIGNED_SHORT*(gl: GL): GLenum = GL_UNSIGNED_SHORT

    template TEXTURE0*(gl: GL): GLenum = GL_TEXTURE0

    template CULL_FACE*(gl: GL) : GLenum = GL_CULL_FACE
    template FRONT*(gl: GL) : GLenum = GL_FRONT
    template BACK*(gl: GL) : GLenum = GL_BACK
    template FRONT_AND_BACK*(gl: GL) : GLenum = GL_FRONT_AND_BACK

    template BUFFER_SIZE*(gl: GL) : GLenum = GL_BUFFER_SIZE

    template compileShader*(gl: GL, shader: ShaderRef) = glCompileShader(shader)
    template deleteShader*(gl: GL, shader: ShaderRef) = glDeleteShader(shader)
    template deleteProgram*(gl: GL, prog: ProgramRef) = glDeleteProgram(prog)
    template attachShader*(gl: GL, prog: ProgramRef, shader: ShaderRef) = glAttachShader(prog, shader)
    template detachShader*(gl: GL, prog: ProgramRef, shader: ShaderRef) = glDetachShader(prog, shader)


    template linkProgram*(gl: GL, prog: ProgramRef) = glLinkProgram(prog)

    template drawArrays*(gl: GL, mode: GLenum, first: GLint, count: GLsizei) = glDrawArrays(mode, first, count)
    template drawElements*(gl: GL, mode: GLenum, count: GLsizei, typ: GLenum, offset: int = 0) = glDrawElements(mode, count, typ, cast[pointer](offset))
    template createShader*(gl: GL, shaderType: GLenum): ShaderRef = glCreateShader(shaderType)
    template createProgram*(gl: GL): ProgramRef = glCreateProgram()
    proc createTexture*(gl: GL): GLuint = glGenTextures(1, addr result)
    proc createFramebuffer*(gl: GL): GLuint {.inline.} = glGenFramebuffers(1, addr result)
    proc createRenderbuffer*(gl: GL): GLuint {.inline.} = glGenRenderbuffers(1, addr result)
    proc createBuffer*(gl: GL): GLuint {.inline.} = glGenBuffers(1, addr result)
    template bufferData*(gl: GL, target: GLenum, size: int32, usage: GLenum) = glBufferData(target, size, nil, usage)

    proc deleteFramebuffer*(gl: GL, name: FramebufferRef) {.inline.} =
        glDeleteFramebuffers(1, unsafeAddr name)

    proc deleteRenderbuffer*(gl: GL, name: RenderbufferRef) {.inline.} =
        glDeleteRenderbuffers(1, unsafeAddr name)

    proc deleteBuffer*(gl: GL, name: BufferRef) {.inline.} =
        glDeleteBuffers(1, unsafeAddr name)

    proc deleteTexture*(gl: GL, name: TextureRef) {.inline.} =
        glDeleteTextures(1, unsafeAddr name)

    template bindAttribLocation*(gl: GL, program: ProgramRef, index: GLuint, name: cstring) = glBindAttribLocation(program, index, name)
    template enableVertexAttribArray*(gl: GL, attrib: GLuint) = glEnableVertexAttribArray(attrib)
    template disableVertexAttribArray*(gl: GL, attrib: GLuint) = glDisableVertexAttribArray(attrib)
    template vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, typ: GLenum,
            normalized: GLboolean, stride: GLsizei, offset: int) =
        glVertexAttribPointer(index, size, typ, normalized, stride, cast[pointer](offset))

    template getUniformLocation*(gl: GL, prog: ProgramRef, name: cstring): UniformLocation = glGetUniformLocation(prog, name)
    template useProgram*(gl: GL, prog: ProgramRef) = glUseProgram(prog)
    template enable*(gl: GL, flag: GLenum) = glEnable(flag)
    template disable*(gl: GL, flag: GLenum) = glDisable(flag)
    template isEnabled*(gl: GL, flag: GLenum): bool = glIsEnabled(flag)
    template viewport*(gl: GL, x, y: GLint, width, height: GLsizei) = glViewport(x, y, width, height)
    template clear*(gl: GL, mask: GLbitfield) = glClear(mask)
    template activeTexture*(gl: GL, t: GLenum) = glActiveTexture(t)
    template bindTexture*(gl: GL, target: GLenum, name: TextureRef) = glBindTexture(target, name)
    template bindFramebuffer*(gl: GL, target: GLenum, name: FramebufferRef) = glBindFramebuffer(target, name)
    template bindRenderbuffer*(gl: GL, target: GLenum, name: RenderbufferRef) = glBindRenderbuffer(target, name)
    template bindBuffer*(gl: GL, target: GLenum, name: BufferRef) = glBindBuffer(target, name)

    template uniform1f*(gl: GL, location: UniformLocation, data: GLfloat) = glUniform1f(location, data)
    template uniform1i*(gl: GL, location: UniformLocation, data: GLint) = glUniform1i(location, data)
    template uniform2fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat]) = glUniform2fv(location, GLSizei(data.len / 2), unsafeAddr data[0])
    template uniform2fv*(gl: GL, location: UniformLocation, length: GLsizei, data: ptr GLfloat) = glUniform2fv(location, length, data)
    template uniform3fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat]) = glUniform3fv(location, GLSizei(data.len / 3), unsafeAddr data[0])
    template uniform3iv*(gl: GL, location: UniformLocation, data: openarray[GLint]) = glUniform3iv(location, GLSizei(data.len / 3), unsafeAddr data[0])
    template uniform4fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat]) = glUniform4fv(location, GLsizei(data.len / 4), unsafeAddr data[0])
    template uniform1fv*(gl: GL, location: UniformLocation, data: openarray[GLfloat]) = glUniform1fv(location, GLsizei(data.len), unsafeAddr data[0])
    template uniform1fv*(gl: GL, location: UniformLocation, length: GLsizei, data: ptr GLfloat) = glUniform1fv(location, length, data)
    proc uniformMatrix4fv*(gl: GL, location: UniformLocation, transpose: GLboolean, data: array[16, GLfloat]) {.inline.} =
        glUniformMatrix4fv(location, 1, transpose, unsafeAddr data[0])
    proc uniformMatrix3fv*(gl: GL, location: UniformLocation, transpose: GLboolean, data: array[9, GLfloat]) {.inline.} =
        glUniformMatrix3fv(location, 1, transpose, unsafeAddr data[0])

    template clearColor*(gl: GL, r, g, b, a: GLfloat) = glClearColor(r, g, b, a)
    template clearStencil*(gl: GL, s: GLint) = glClearStencil(s)

    template blendFunc*(gl: GL, sfactor, dfactor: GLenum) = glBlendFunc(sfactor, dfactor)
    template blendColor*(gl: GL, r, g, b, a: Glfloat) = glBlendColor(r, g, b, a)
    template blendFuncSeparate*(gl: GL, sfactor, dfactor, sfactorA, dfactorA: GLenum) = glBlendFuncSeparate(sfactor, dfactor, sfactorA, dfactorA)
    template texParameteri*(gl: GL, target, pname: GLenum, param: GLint) = glTexParameteri(target, pname, param)

    template texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: pointer) =
        glTexImage2D(target, level, internalformat, width, height, border, format, t, pixels)
    template texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: openarray) =
        glTexImage2D(target, level, internalformat, width, height, border, format, t, unsafeAddr pixels[0])
    template texSubImage2D*(gl: GL, target: GLenum, level: GLint, xoffset, yoffset: GLint, width, height: GLsizei, format, t: GLenum, pixels: pointer) =
        glTexSubImage2D(target, level, xoffset, yoffset, width, height, format, t, pixels)
    template texSubImage2D*(gl: GL, target: GLenum, level: GLint, xoffset, yoffset: GLint, width, height: GLsizei, format, t: GLenum, pixels: openarray) =
        glTexSubImage2D(target, level, xoffset, yoffset, width, height, format, t, unsafeAddr pixels[0])

    template generateMipmap*(gl: GL, target: GLenum) = glGenerateMipmap(target)
    template pixelStorei*(gl: GL, pname: GLenum, param: GLint) = glPixelStorei(pname, param)

    template framebufferTexture2D*(gl: GL, target, attachment, textarget: GLenum, texture: TextureRef, level: GLint) =
        glFramebufferTexture2D(target, attachment, textarget, texture, level)
    template renderbufferStorage*(gl: GL, target, internalformat: GLenum, width, height: GLsizei) = glRenderbufferStorage(target, internalformat, width, height)
    template framebufferRenderbuffer*(gl: GL, target, attachment, renderbuffertarget: GLenum, renderbuffer: RenderbufferRef) =
        glFramebufferRenderbuffer(target, attachment, renderbuffertarget, renderbuffer)

    template stencilFunc*(gl: GL, fun: GLenum, refe: GLint, mask: GLuint) = glStencilFunc(fun, refe, mask)
    template stencilOp*(gl: GL, fail, zfail, zpass: GLenum) = glStencilOp(fail, zfail, zpass)
    template colorMask*(gl: GL, r, g, b, a: bool) = glColorMask(r, g, b, a)
    template depthMask*(gl: GL, d: bool) = glDepthMask(d)
    template stencilMask*(gl: GL, m: GLuint) = glStencilMask(m)
    template cullFace*(gl: GL, mode: GLenum) = glCullFace(mode)
    template scissor*(gl: GL, x, y: GLint, width, height: GLsizei) = glScissor(x, y, width, height)

    template getError*(gl: GL): GLenum = glGetError()

    template isEmpty*(obj: TextureRef or FramebufferRef or RenderbufferRef): bool = obj == 0

# TODO: This is a quick and dirty hack for render to texture.
var globalGL: GL

proc newGL*(canvas: ref RootObj): GL =
    when defined js:
        asm """
            var options = {stencil: true, alpha: false, premultipliedAlpha: false, antialias: false};
            try {
                `result` = `canvas`.getContext("webgl", options);
            }
            catch(err) {}
            if (`result` === null) {
                try {
                    `result` = `canvas`.getContext("experimental-webgl", options);
                }
                catch(err) {}
            }

            if (`result` !== null) {
                var devicePixelRatio = 1; //window.devicePixelRatio || 1;
                `result`.viewportWidth = `canvas`.width * devicePixelRatio;
                `result`.viewportHeight = `canvas`.height * devicePixelRatio;
                `result`.getExtension('OES_standard_derivatives');
                `result`.pixelStorei(`result`.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
            } else {
                alert("Your browser does not support WebGL. Please, use a modern browser.");
            }
            """
    else:
        result.new()
    globalGL = result

proc sharedGL*(): GL = globalGL

proc shaderInfoLog*(gl: GL, s: ShaderRef): string =
    when defined js:
        var m: cstring
        # Chrome bug: getShaderInfoLog and getProgramInfoLog return zero terminated strings
        {.emit:"""
        `m` = `gl`.getShaderInfoLog(`s`);
        while (`m`.charCodeAt(`m`.length - 1) == 0) {
             `m` = `m`.substring(0, `m`.length - 1);
        }
        """.}
        result = $m
    else:
        var infoLen: GLint
        result = ""
        glGetShaderiv(s, GL_INFO_LOG_LENGTH, addr infoLen)
        if infoLen > 0:
            var infoLog : cstring = cast[cstring](alloc(infoLen + 1))
            glGetShaderInfoLog(s, infoLen, nil, infoLog)
            result = $infoLog
            dealloc(infoLog)

proc programInfoLog*(gl: GL, s: ProgramRef): string =
    when defined js:
        var m: cstring
        # Chrome bug: getShaderInfoLog and getProgramInfoLog return zero terminated strings
        {.emit:"""
        `m` = `gl`.getProgramInfoLog(`s`);
        while (`m`.charCodeAt(`m`.length - 1) == 0) {
             `m` = `m`.substring(0, `m`.length - 1);
        }
        """.}
        result = $m
    else:
        var infoLen: GLint
        result = ""
        glGetProgramiv(s, GL_INFO_LOG_LENGTH, addr infoLen)
        if infoLen > 0:
            var infoLog : cstring = cast[cstring](alloc(infoLen + 1))
            glGetProgramInfoLog(s, infoLen, nil, infoLog)
            result = $infoLog
            dealloc(infoLog)

proc shaderSource*(gl: GL, s: ShaderRef, src: cstring) =
    when defined js:
        asm "`gl`.shaderSource(`s`, `src`);"
    else:
        var srcArray = [src]
        glShaderSource(s, 1, cast[cstringArray](addr srcArray), nil)

proc isShaderCompiled*(gl: GL, shader: ShaderRef): bool {.inline.} =
    when defined js:
        asm "`result` = `gl`.getShaderParameter(`shader`, `gl`.COMPILE_STATUS);"
    else:
        var compiled: GLint
        glGetShaderiv(shader, GL_COMPILE_STATUS, addr compiled)
        result = GLboolean(compiled) == GLboolean(GL_TRUE)

proc isProgramLinked*(gl: GL, prog: ProgramRef): bool {.inline.} =
    when defined js:
        asm "`result` = `gl`.getProgramParameter(`prog`, `gl`.LINK_STATUS);"
    else:
        var linked: GLint
        glGetProgramiv(prog, GL_LINK_STATUS, addr linked)
        result = GLboolean(linked) == GLboolean(GL_TRUE)

when defined(js):
    proc newTypedSeq(t: typedesc[float32], data: openarray[t]): seq[float32] {.importc: "new Float32Array".}
    proc newTypedSeq(t: typedesc[float64], data: openarray[t]): seq[float64] {.importc: "new Float64Array".}
    proc newTypedSeq(t: typedesc[int16], data: openarray[t]): seq[int16] {.importc: "new Int16Array".}
    proc newTypedSeq(t: typedesc[int8], data: openarray[t]): seq[int8] {.importc: "new Int8Array".}
    proc newTypedSeq(t: typedesc[byte], data: openarray[t]): seq[byte] {.importc: "new Uint8Array".}
    proc newTypedSeq(t: typedesc[uint16], data: openarray[t]): seq[uint16] {.importc: "new Uint16Array".}

    proc newTypedSeq(t: typedesc[float32], buffer: RootRef, offset, len: int): seq[float32] {.importc: "new Float32Array".}
    proc newTypedSeq(t: typedesc[float64], buffer: RootRef, offset, len: int): seq[float64] {.importc: "new Float64Array".}
    proc newTypedSeq(t: typedesc[int16], buffer: RootRef, offset, len: int): seq[int16] {.importc: "new Int16Array".}
    proc newTypedSeq(t: typedesc[int8], buffer: RootRef, offset, len: int): seq[int8] {.importc: "new Int8Array".}
    proc newTypedSeq(t: typedesc[byte], buffer: RootRef, offset, len: int): seq[byte] {.importc: "new Uint8Array".}
    proc newTypedSeq(t: typedesc[uint16], buffer: RootRef, offset, len: int): seq[uint16] {.importc: "new Uint16Array".}

    proc buffer[T](data: openarray[T]): RootRef {.importcpp: "#.buffer".}
    proc isTypedSeq(v: openarray): bool {.importcpp: "(#.buffer !== undefined)".}
    proc bufferDataImpl(gl: GL, target: GLenum, data: openarray, usage: GLenum) {.importcpp: "bufferData".}
    proc bufferSubDataImpl(gl: GL, target: GLenum, offset: int32, data: openarray) {.importcpp: "bufferSubData".}

proc bufferData*[T](gl: GL, target: GLenum, data: openarray[T], size: int, usage: GLenum) {.inline.} =
    assert(size <= data.len)
    when defined(js):
        assert(data.isTypedSeq)
        gl.bufferDataImpl(target, newTypedSeq(T, data.buffer, 0, size), usage)
    else:
        glBufferData(target, GLsizei(size * sizeof(T)), cast[pointer](data), usage);

proc bufferData*[T](gl: GL, target: GLenum, data: openarray[T], usage: GLenum) {.inline.} =
    when defined(js):
        gl.bufferDataImpl(target, if data.isTypedSeq: data else: newTypedSeq(T, data), usage)
    else:
        glBufferData(target, GLsizei(data.len * sizeof(T)), cast[pointer](data), usage);

proc bufferSubData*[T](gl: GL, target: GLenum, offset: int32, data: openarray[T]) {.inline.} =
    when defined(js):
        gl.bufferSubDataImpl(target, offset, if data.isTypedSeq: data else: newTypedSeq(T, data));
    else:
        glBufferSubData(target, offset, GLsizei(data.len * sizeof(T)), cast[pointer](data));

proc getBufferParameteriv*(gl: GL, target, value: GLenum): GLint {.inline.} =
    when defined js:
        asm "`result` = `gl`.getBufferParameter(`target`, `value`);"
    else:
        glGetBufferParameteriv(target, value, addr result)

proc vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, normalized: GLboolean,
                        stride: GLsizei, data: openarray[GLfloat]) {.deprecated.} =
    # Better dont use this proc and work with buffers yourself, because look
    # how ugly it is in js.
    when defined js:
        asm """
        var buf = null;
        if (window.__nimxSharedBuffers === undefined) {
            window.__nimxSharedBuffers = {};
        }
        if (window.__nimxSharedBuffers[`index`] === undefined) {
            buf = `gl`.createBuffer();
            window.__nimxSharedBuffers[`index`] = buf;
        }
        else {
            buf = window.__nimxSharedBuffers[`index`];
        }

        `gl`.bindBuffer(`gl`.ARRAY_BUFFER, buf);
        if (`data`.buffer === undefined) `data` = new Float32Array(`data`);
        `gl`.bufferData(`gl`.ARRAY_BUFFER, `data`, `gl`.DYNAMIC_DRAW);
        """
        gl.vertexAttribPointer(index, size, gl.FLOAT, normalized, stride, 0)
    else:
        glVertexAttribPointer(index, size, cGL_FLOAT, normalized, stride, cast[pointer](data));

proc getParami*(gl: GL, pname: GLenum): GLint =
    when defined js:
        asm "`result` = `gl`.getParameter(`pname`);"
    else:
        glGetIntegerv(pname, addr result)

proc getParamf*(gl: GL, pname: GLenum): GLfloat =
    when defined js:
        asm "`result` = `gl`.getParameter(`pname`);"
    else:
        glGetFloatv(pname, addr result)

proc getParamb*(gl: GL, pname: GLenum): GLboolean =
    when defined js:
        asm "`result` = `gl`.getParameter(`pname`);"
    else:
        glGetBooleanv(pname, addr result)

proc getViewport*(gl: GL): array[4, GLint] =
    when defined js:
        asm "`result` = `gl`.getParameter(`gl`.VIEWPORT);"
    else:
        glGetIntegerv(GL_VIEWPORT, addr result[0])

template viewport*(gl: GL, vp: array[4, GLint]) = gl.viewport(vp[0], vp[1], vp[2], vp[3])

when defined(js):
    template boundFramebuffer*(gl: GL): FramebufferRef =
        cast[FramebufferRef](getParameterRef(gl, gl.FRAMEBUFFER_BINDING))
    template boundRenderbuffer*(gl: GL): RenderbufferRef =
        cast[RenderbufferRef](getParameterRef(gl, gl.RENDERBUFFER_BINDING))
else:
    template boundFramebuffer*(gl: GL): FramebufferRef =
        cast[FramebufferRef](gl.getParami(GL_FRAMEBUFFER_BINDING))
    template boundRenderbuffer*(gl: GL): RenderbufferRef =
        cast[RenderbufferRef](gl.getParami(GL_RENDERBUFFER_BINDING))

proc getClearColor*(gl: GL, colorComponents: var array[4, GLfloat]) =
    when defined js:
        asm """
        var color = `gl`.getParameter(`gl`.COLOR_CLEAR_VALUE);
        `colorComponents`[0] = color[0];
        `colorComponents`[1] = color[1];
        `colorComponents`[2] = color[2];
        `colorComponents`[3] = color[3];
        """
    else:
        glGetFloatv(GL_COLOR_CLEAR_VALUE, cast[ptr GLfloat](addr colorComponents))

proc clearWithColor*(gl: GL, r, g, b, a: GLfloat) =
    var oldColor: array[4, GLfloat]
    gl.getClearColor(oldColor)
    gl.clear(gl.COLOR_BUFFER_BIT or gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)
    gl.clearColor(oldColor[0], oldColor[1], oldColor[2], oldColor[3])

proc clearDepthStencil*(gl: GL) =
    gl.clear(gl.STENCIL_BUFFER_BIT or gl.DEPTH_BUFFER_BIT)
