
import opengl
# export opengl

export GLuint, GLint, GLfloat, GLenum, GLsizei, GLushort

when defined js:
    type
        FramebufferRef* = ref FramebufferObj
        FramebufferObj {.importc.} = object

        RenderbufferRef* = ref FramebufferObj
        RenderbufferObj {.importc.} = object

        TextureRef* = ref TextureObj
        TextureObj {.importc.} = object

        GL* = ref GLObj
        GLObj {.importc.} = object
            VERTEX_SHADER* : GLenum
            FRAGMENT_SHADER* : GLenum
            TEXTURE_2D* : GLenum
            ONE_MINUS_SRC_ALPHA*, ONE_MINUS_DST_ALPHA*, SRC_ALPHA*, DST_ALPHA*, ONE* : GLenum
            BLEND* : GLenum
            TRIANGLES*, TRIANGLE_FAN*, TRIANGLE_STRIP* : GLenum
            COLOR_BUFFER_BIT*: int
            STENCIL_BUFFER_BIT*: int
            DEPTH_BUFFER_BIT*: int
            TEXTURE_MIN_FILTER*, TEXTURE_MAG_FILTER*, TEXTURE_WRAP_S*, TEXTURE_WRAP_T*: GLenum
            LINEAR*, NEAREST*, CLAMP_TO_EDGE*, LINEAR_MIPMAP_NEAREST* : GLint
            FRAMEBUFFER* : GLenum
            RENDERBUFFER* : GLenum
            ARRAY_BUFFER* : GLenum
            ELEMENT_ARRAY_BUFFER* : GLenum
            RGBA* : GLenum
            ALPHA* : GLenum
            UNSIGNED_BYTE* : GLenum
            COLOR_ATTACHMENT0* : GLenum
            DEPTH_ATTACHMENT* : GLenum
            DEPTH_STENCIL_ATTACHMENT* : GLenum
            DEPTH_COMPONENT16* : GLenum
            DEPTH_STENCIL* : GLenum
            DEPTH24_STENCIL8* : GLenum
            FRAMEBUFFER_BINDING : GLenum
            RENDERBUFFER_BINDING : GLenum
            STENCIL_TEST*, DEPTH_TEST* : GLenum
            NEVER*, LESS*, LEQUAL*, GREATER*, GEQUAL*, EQUAL*, NOTEQUAL*, ALWAYS*: GLenum
            KEEP*, ZERO*, REPLACE*, INCR*, INCR_WRAP*, DECR*, DECR_WRAP*, INVERT*: GLenum

            STREAM_DRAW*, STREAM_READ*, STREAM_COPY*, STATIC_DRAW*, STATIC_READ*,
                STATIC_COPY*, DYNAMIC_DRAW*, DYNAMIC_READ*, DYNAMIC_COPY* : GLenum

            FLOAT*, UNSIGNED_SHORT* : GLenum
            TEXTURE0*: GLenum

            CULL_FACE*, FRONT*, BACK*, FRONT_AND_BACK* : GLenum

    {.push importcpp.}

    proc compileShader*(gl: GL, shader: GLuint)
    proc deleteShader*(gl: GL, shader: GLuint)
    proc deleteProgram*(gl: GL, prog: GLuint)
    proc attachShader*(gl: GL, prog, shader: GLuint)
    proc detachShader*(gl: GL, prog, shader: GLuint)

    proc linkProgram*(gl: GL, prog: GLuint)
    proc drawArrays*(gl: GL, mode: GLenum, first: GLint, count: GLsizei)
    proc drawElements*(gl: GL, mode: GLenum, count: GLsizei, typ: GLenum, alwaysZeroOffset: int = 0)
    proc createShader*(gl: GL, shaderType: GLenum): GLuint
    proc createProgram*(gl: GL): GLuint
    proc createTexture*(gl: GL): TextureRef
    proc createFramebuffer*(gl: GL): FramebufferRef
    proc createRenderbuffer*(gl: GL): RenderbufferRef
    proc createBuffer*(gl: GL): GLuint

    proc deleteFramebuffer*(gl: GL, name: GLuint)
    proc deleteRenderbuffer*(gl: GL, name: GLuint)

    proc bindAttribLocation*(gl: GL, program, index: GLuint, name: cstring)
    proc enableVertexAttribArray*(gl: GL, attrib: GLuint)
    proc disableVertexAttribArray*(gl: GL, attrib: GLuint)
    proc getUniformLocation*(gl: GL, prog: GLuint, name: cstring): GLint
    proc useProgram*(gl: GL, prog: GLuint)
    proc enable*(gl: GL, flag: GLenum)
    proc disable*(gl: GL, flag: GLenum)
    proc isEnabled*(gl: GL, flag: GLenum): bool
    proc viewport*(gl: GL, x, y: GLint, width, height: GLsizei)
    proc clear*(gl: GL, mask: int)
    proc activeTexture*(gl: GL, t: GLenum)
    proc bindTexture*(gl: GL, target: GLenum, name: TextureRef)
    proc bindFramebuffer*(gl: GL, target: GLenum, name: FramebufferRef)
    proc bindRenderbuffer*(gl: GL, target: GLenum, name: RenderbufferRef)
    proc bindBuffer*(gl: GL, target: GLenum, name: GLuint)

    proc uniform1fv*(gl: GL, location: GLint, data: openarray[GLfloat])
    proc uniform2fv*(gl: GL, location: GLint, data: openarray[GLfloat])
    proc uniform4fv*(gl: GL, location: GLint, data: openarray[GLfloat])
    proc uniform1f*(gl: GL, location: GLint, data: GLfloat)
    proc uniform1i*(gl: GL, location: GLint, data: GLint)
    proc uniformMatrix4fv*(gl: GL, location: GLint, transpose: GLboolean, data: array[16, GLfloat])
    proc uniformMatrix3fv*(gl: GL, location: GLint, transpose: GLboolean, data: array[9, GLfloat])

    proc clearColor*(gl: GL, r, g, b, a: GLfloat)
    proc clearStencil*(gl: GL, s: GLint)
    proc blendFunc*(gl: GL, sfactor, dfactor: GLenum)
    proc texParameteri*(gl: GL, target, pname: GLenum, param: GLint)

    proc texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: ref RootObj)
    proc generateMipmap*(gl: GL, target: GLenum)

    proc framebufferTexture2D*(gl: GL, target, attachment, textarget: GLenum, texture: TextureRef, level: GLint)
    proc renderbufferStorage*(gl: GL, target, internalformat: GLenum, width, height: GLsizei)
    proc framebufferRenderbuffer*(gl: GL, target, attachment, renderbuffertarget: GLenum, renderbuffer: RenderbufferRef)

    proc stencilFunc*(gl: GL, fun: GLenum, refe: GLint, mask: GLuint)
    proc stencilOp*(gl: GL, fail, zfail, zpass: GLenum)
    proc colorMask*(gl: GL, r, g, b, a: bool)
    proc depthMask*(gl: GL, d: bool)
    proc stencilMask*(gl: GL, m: GLuint)
    proc cullFace*(gl: GL, mode: GLenum)

    proc getError*(gl: GL): GLenum

    {.pop.}

    proc getParameterRef(gl: GL, mode: GLenum): ref RootObj {.importcpp: "getParameter".}

    template isEmpty*(obj: TextureRef or FramebufferRef or RenderbufferRef): bool = obj.isNil

else:
    type
        GL* = ref object
        FramebufferRef* = GLuint
        RenderbufferRef* = GLuint
        TextureRef* = GLuint
    template VERTEX_SHADER*(gl: GL): GLenum = GL_VERTEX_SHADER
    template FRAGMENT_SHADER*(gl: GL): GLenum = GL_FRAGMENT_SHADER
    template TEXTURE_2D*(gl: GL): GLenum = GL_TEXTURE_2D
    template ONE_MINUS_SRC_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_SRC_ALPHA
    template ONE_MINUS_DST_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_DST_ALPHA
    template SRC_ALPHA*(gl: GL): GLenum = GL_SRC_ALPHA
    template DST_ALPHA*(gl: GL): GLenum = GL_DST_ALPHA
    template ONE*(gl: GL): GLenum = GL_ONE
    template BLEND*(gl: GL): GLenum = GL_BLEND
    template TRIANGLES*(gl: GL): GLenum = GL_TRIANGLES
    template TRIANGLE_FAN*(gl: GL): GLenum = GL_TRIANGLE_FAN
    template TRIANGLE_STRIP*(gl: GL): GLenum = GL_TRIANGLE_STRIP
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
    template FRAMEBUFFER*(gl: GL): GLenum = GL_FRAMEBUFFER
    template RENDERBUFFER*(gl: GL): GLenum = GL_RENDERBUFFER
    template ARRAY_BUFFER*(gl: GL): GLenum = GL_ARRAY_BUFFER
    template ELEMENT_ARRAY_BUFFER*(gl: GL): GLenum = GL_ELEMENT_ARRAY_BUFFER
    template RGBA*(gl: GL): expr = GL_RGBA
    template ALPHA*(gl: GL): expr = GL_ALPHA
    template UNSIGNED_BYTE*(gl: GL): GLenum = GL_UNSIGNED_BYTE
    template COLOR_ATTACHMENT0*(gl: GL): GLenum = GL_COLOR_ATTACHMENT0
    template DEPTH_ATTACHMENT*(gl: GL): GLenum = GL_DEPTH_ATTACHMENT
    template DEPTH_STENCIL_ATTACHMENT*(gl: GL): GLenum = GL_DEPTH_ATTACHMENT
    template DEPTH_COMPONENT16*(gl: GL): GLenum = GL_DEPTH_COMPONENT16
    template DEPTH_STENCIL*(gl: GL): GLenum = GL_DEPTH_STENCIL
    template DEPTH24_STENCIL8*(gl: GL): GLenum = GL_DEPTH24_STENCIL8
    template FRAMEBUFFER_BINDING(gl: GL): GLenum = GL_FRAMEBUFFER_BINDING
    template RENDERBUFFER_BINDING(gl: GL): GLenum = GL_RENDERBUFFER_BINDING
    template STENCIL_TEST*(gl: GL): GLenum = GL_STENCIL_TEST
    template DEPTH_TEST*(gl: GL): GLenum = GL_DEPTH_TEST

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

    template compileShader*(gl: GL, shader: GLuint) = glCompileShader(shader)
    template deleteShader*(gl: GL, shader: GLuint) = glDeleteShader(shader)
    template deleteProgram*(gl: GL, prog: GLuint) = glDeleteProgram(prog)
    template attachShader*(gl: GL, prog, shader: GLuint) = glAttachShader(prog, shader)
    template detachShader*(gl: GL, prog, shader: GLuint) = glDetachShader(prog, shader)


    template linkProgram*(gl: GL, prog: GLuint) = glLinkProgram(prog)

    template drawArrays*(gl: GL, mode: GLenum, first: GLint, count: GLsizei) = glDrawArrays(mode, first, count)
    template drawElements*(gl: GL, mode: GLenum, count: GLsizei, typ: GLenum) = glDrawElements(mode, count, typ, nil)
    template createShader*(gl: GL, shaderType: GLenum): GLuint = glCreateShader(shaderType)
    template createProgram*(gl: GL): GLuint = glCreateProgram()
    proc createTexture*(gl: GL): GLuint = glGenTextures(1, addr result)
    proc createFramebuffer*(gl: GL): GLuint {.inline.} = glGenFramebuffers(1, addr result)
    proc createRenderbuffer*(gl: GL): GLuint {.inline.} = glGenRenderbuffers(1, addr result)
    proc createBuffer*(gl: GL): GLuint {.inline.} = glGenBuffers(1, addr result)

    proc deleteFramebuffer*(gl: GL, name: GLuint) {.inline.} =
        var n = name
        glDeleteFramebuffers(1, addr n)

    proc deleteRenderbuffer*(gl: GL, name: GLuint) {.inline.} =
        var n = name
        glDeleteRenderbuffers(1, addr n)

    template bindAttribLocation*(gl: GL, program, index: GLuint, name: cstring) = glBindAttribLocation(program, index, name)
    template enableVertexAttribArray*(gl: GL, attrib: GLuint) = glEnableVertexAttribArray(attrib)
    template disableVertexAttribArray*(gl: GL, attrib: GLuint) = glDisableVertexAttribArray(attrib)
    template getUniformLocation*(gl: GL, prog: GLuint, name: cstring): GLint = glGetUniformLocation(prog, name)
    template useProgram*(gl: GL, prog: GLuint) = glUseProgram(prog)
    template enable*(gl: GL, flag: GLenum) = glEnable(flag)
    template disable*(gl: GL, flag: GLenum) = glDisable(flag)
    template isEnabled*(gl: GL, flag: GLenum): bool = glIsEnabled(flag)
    template viewport*(gl: GL, x, y: GLint, width, height: GLsizei) = glViewport(x, y, width, height)
    template clear*(gl: GL, mask: GLbitfield) = glClear(mask)
    template activeTexture*(gl: GL, t: GLenum) = glActiveTexture(t)
    template bindTexture*(gl: GL, target: GLenum, name: TextureRef) = glBindTexture(target, name)
    template bindFramebuffer*(gl: GL, target: GLenum, name: FramebufferRef) = glBindFramebuffer(target, name)
    template bindRenderbuffer*(gl: GL, target: GLenum, name: RenderbufferRef) = glBindRenderbuffer(target, name)
    template bindBuffer*(gl: GL, target: GLenum, name: GLuint) = glBindBuffer(target, name)

    template uniform1f*(gl: GL, location: GLint, data: GLfloat) = glUniform1f(location, data)
    template uniform1i*(gl: GL, location: GLint, data: GLint) = glUniform1i(location, data)
    template uniform2fv*(gl: GL, location: GLint, data: openarray[GLfloat]) = glUniform2fv(location, GLSizei(data.len / 2), unsafeAddr data[0])
    template uniform2fv*(gl: GL, location: GLint, length: GLsizei, data: ptr GLfloat) = glUniform2fv(location, length, data)
    template uniform4fv*(gl: GL, location: GLint, data: openarray[GLfloat]) = glUniform4fv(location, GLsizei(data.len / 4), unsafeAddr data[0])
    template uniform1fv*(gl: GL, location: GLint, data: openarray[GLfloat]) = glUniform1fv(location, GLsizei(data.len), unsafeAddr data[0])
    template uniform1fv*(gl: GL, location: GLint, length: GLsizei, data: ptr GLfloat) = glUniform1fv(location, length, data)
    proc uniformMatrix4fv*(gl: GL, location: GLint, transpose: GLboolean, data: array[16, GLfloat]) {.inline.} =
        glUniformMatrix4fv(location, 1, transpose, unsafeAddr data[0])
    proc uniformMatrix3fv*(gl: GL, location: GLint, transpose: GLboolean, data: array[9, GLfloat]) {.inline.} =
        glUniformMatrix3fv(location, 1, transpose, unsafeAddr data[0])

    template clearColor*(gl: GL, r, g, b, a: GLfloat) = glClearColor(r, g, b, a)
    template clearStencil*(gl: GL, s: GLint) = glClearStencil(s)

    template blendFunc*(gl: GL, sfactor, dfactor: GLenum) = glBlendFunc(sfactor, dfactor)
    template texParameteri*(gl: GL, target, pname: GLenum, param: GLint) = glTexParameteri(target, pname, param)

    template texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: pointer) =
        glTexImage2D(target, level, internalformat, width, height, border, format, t, pixels)

    template generateMipmap*(gl: GL, target: GLenum) = glGenerateMipmap(target)

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

    template getError*(gl: GL): GLenum = glGetError()

    template isEmpty*(obj: TextureRef or FramebufferRef or RenderbufferRef): bool = obj == 0

# TODO: This is a quick and dirty hack for render to texture.
var globalGL: GL

proc newGL*(canvas: ref RootObj): GL =
    when defined js:
        asm """
            var options = {stencil: true, alpha: false, premultipliedAlpha: false};
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
        globalGL = result

proc sharedGL*(): GL = globalGL

proc shaderInfoLog*(gl: GL, s: GLuint): string =
    when defined js:
        var m: cstring
        asm """
            `m` = `gl`.getShaderInfoLog(`s`);
            """
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

proc programInfoLog*(gl: GL, s: GLuint): string =
    when defined js:
        var m: cstring
        asm "`m` = `gl`.getProgramInfoLog(`s`);"
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

proc shaderSource*(gl: GL, s: GLuint, src: cstring) =
    when defined js:
        asm "`gl`.shaderSource(`s`, `src`);"
    else:
        var srcArray = [src]
        glShaderSource(s, 1, cast[cstringArray](addr srcArray), nil)

proc isShaderCompiled*(gl: GL, shader: GLuint): bool {.inline.} =
    when defined js:
        asm "`result` = `gl`.getShaderParameter(`shader`, `gl`.COMPILE_STATUS);"
    else:
        var compiled: GLint
        glGetShaderiv(shader, GL_COMPILE_STATUS, addr compiled)
        result = if compiled == GL_TRUE: true else: false

proc isProgramLinked*(gl: GL, prog: GLuint): bool {.inline.} =
    when defined js:
        asm "`result` = `gl`.getProgramParameter(`prog`, `gl`.LINK_STATUS);"
    else:
        var linked: GLint
        glGetProgramiv(prog, GL_LINK_STATUS, addr linked)
        result = if linked == GL_TRUE: true else: false

proc bufferData*(gl: GL, target: GLenum, data: openarray[GLfloat], usage: GLenum) {.inline.} =
    when defined(js):
        asm "`gl`.bufferData(`target`, new Float32Array(`data`), `usage`);"
    else:
        glBufferData(target, GLsizei(data.len * sizeof(GLfloat)), cast[pointer](data), usage);

proc bufferData*(gl: GL, target: GLenum, data: openarray[GLushort], usage: GLenum) {.inline.} =
    when defined(js):
        asm "`gl`.bufferData(`target`, new Uint16Array(`data`), `usage`);"
    else:
        glBufferData(target, GLsizei(data.len * sizeof(GLushort)), cast[pointer](data), usage);

proc vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, typ: GLenum, normalized: GLboolean,
                        stride: GLsizei, offset: int) {.inline.} =
    when defined(js):
        asm "`gl`.vertexAttribPointer(`index`, `size`, `typ`, `normalized`, `stride`, `offset`);"
    else:
        glVertexAttribPointer(index, size, typ, normalized, stride, cast[pointer](offset))

proc vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, normalized: GLboolean,
                        stride: GLsizei, data: openarray[GLfloat]) =
    when defined js:
        asm """
        var buf = null;
        if (typeof(`vertexAttribPointer`.__nimxSharedBuffers) == "undefined")
        {
            `vertexAttribPointer`.__nimxSharedBuffers = {};
        }
        if (typeof(`vertexAttribPointer`.__nimxSharedBuffers[`index`]) == "undefined")
        {
            buf = `gl`.createBuffer();
            `vertexAttribPointer`.__nimxSharedBuffers[`index`] = buf;
        }
        else
        {
            buf = `vertexAttribPointer`.__nimxSharedBuffers[`index`];
        }

        `gl`.bindBuffer(`gl`.ARRAY_BUFFER, buf);
        `gl`.bufferData(`gl`.ARRAY_BUFFER, new Float32Array(`data`), `gl`.DYNAMIC_DRAW);
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
