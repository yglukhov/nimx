
import opengl
# export opengl
import unsigned

export GLuint, GLint, GLfloat, GLenum, GLsizei, GLushort

when defined js:
    type
        GL* = ref GLObj
        GLObj {.importc.} = object
            VERTEX_SHADER* : GLenum
            FRAGMENT_SHADER* : GLenum
            TEXTURE_2D* : GLenum
            ONE_MINUS_SRC_ALPHA* : GLenum
            ONE_MINUS_DST_ALPHA* : GLenum
            SRC_ALPHA* : GLenum
            DST_ALPHA* : GLenum
            BLEND* : GLenum
            TRIANGLES*, TRIANGLE_FAN*, TRIANGLE_STRIP* : GLenum
            COLOR_BUFFER_BIT*: int
            STENCIL_BUFFER_BIT*: int
            DEPTH_BUFFER_BIT*: int
            TEXTURE_MIN_FILTER* : GLenum
            TEXTURE_MAG_FILTER* : GLenum
            LINEAR* : GLint
            NEAREST* : GLint
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
            FRAMEBUFFER_BINDING* : GLenum
            RENDERBUFFER_BINDING* : GLenum
            STENCIL_TEST*, DEPTH_TEST* : GLenum
            NEVER*, LESS*, LEQUAL*, GREATER*, GEQUAL*, EQUAL*, NOTEQUAL*, ALWAYS*: GLenum
            KEEP*, ZERO*, REPLACE*, INCR*, INCR_WRAP*, DECR*, DECR_WRAP*, INVERT*: GLenum

            STREAM_DRAW*, STREAM_READ*, STREAM_COPY*, STATIC_DRAW*, STATIC_READ*,
                STATIC_COPY*, DYNAMIC_DRAW*, DYNAMIC_READ*, DYNAMIC_COPY* : GLenum

            FLOAT*, UNSIGNED_SHORT* : GLenum

            compileShader*: proc(shader: GLuint)
            deleteShader*: proc(shader: GLuint)
            deleteProgram*: proc(prog: GLuint)
            attachShader*: proc(prog, shader: GLuint)
            detachShader*: proc(prog, shader: GLuint)

            linkProgram*: proc(prog: GLuint)
            drawArrays*: proc (mode: GLenum, first: GLint, count: GLsizei)
            drawElements*: proc (mode: GLenum, count: GLsizei, typ: GLenum, alwaysZeroOffset: int = 0)
            createShader*: proc (shaderType: GLenum): GLuint
            createProgram*: proc (): GLuint
            createTexture*: proc(): GLuint
            createFramebuffer*: proc(): GLuint
            createRenderbuffer*: proc(): GLuint
            createBuffer*: proc(): GLuint

            deleteFramebuffer*: proc(name: GLuint)
            deleteRenderbuffer*: proc(name: GLuint)

            bindAttribLocation*: proc (program, index: GLuint, name: cstring)
            enableVertexAttribArray*: proc (attrib: GLuint)
            disableVertexAttribArray*: proc (attrib: GLuint)
            getUniformLocation*: proc(prog: GLuint, name: cstring): GLint
            useProgram*: proc(prog: GLuint)
            enable*: proc(flag: GLenum)
            disable*: proc(flag: GLenum)
            isEnabled*: proc(flag: GLenum): bool
            viewport*: proc(x, y: GLint, width, height: GLsizei)
            clear*: proc(mask: int)
            bindTexture*: proc(target: GLenum, name: GLuint)
            bindFramebuffer*: proc(target: GLenum, name: GLuint)
            bindRenderbuffer*: proc(target: GLenum, name: GLuint)
            bindBuffer*: proc(target: GLenum, name: GLuint)

            uniform4fv*: proc(location: GLint, data: array[4, GLfloat])
            uniform1f*: proc(location: GLint, data: GLfloat)
            uniformMatrix4fv*: proc(location: GLint, transpose: GLboolean, data: array[16, GLfloat])

            clearColor*: proc(r, g, b, a: GLfloat)
            clearStencil*: proc(s: GLint)
            blendFunc*: proc(sfactor, dfactor: GLenum)
            texParameteri*: proc(target, pname: GLenum, param: GLint)

            texImage2D*: proc(target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: pointer)
            framebufferTexture2D*: proc(target, attachment, textarget: GLenum, texture: GLuint, level: GLint)
            renderbufferStorage*: proc(target, internalformat: GLenum, width, height: GLsizei)
            framebufferRenderbuffer*: proc(target, attachment, renderbuffertarget: GLenum, renderbuffer: GLuint)

            stencilFunc*: proc(fun: GLenum, refe: GLint, mask: GLuint)
            stencilOp*: proc(fail, zfail, zpass: GLenum)
            colorMask*: proc(r, g, b, a: bool)
            depthMask*: proc(d: bool)
            stencilMask*: proc(m: GLuint)

            getError*: proc(): GLenum

else:
    type GL* = ref object
    template VERTEX_SHADER*(gl: GL): GLenum = GL_VERTEX_SHADER
    template FRAGMENT_SHADER*(gl: GL): GLenum = GL_FRAGMENT_SHADER
    template TEXTURE_2D*(gl: GL): GLenum = GL_TEXTURE_2D
    template ONE_MINUS_SRC_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_SRC_ALPHA
    template ONE_MINUS_DST_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_DST_ALPHA
    template SRC_ALPHA*(gl: GL): GLenum = GL_SRC_ALPHA
    template DST_ALPHA*(gl: GL): GLenum = GL_DST_ALPHA
    template BLEND*(gl: GL): GLenum = GL_BLEND
    template TRIANGLES*(gl: GL): GLenum = GL_TRIANGLES
    template TRIANGLE_FAN*(gl: GL): GLenum = GL_TRIANGLE_FAN
    template TRIANGLE_STRIP*(gl: GL): GLenum = GL_TRIANGLE_STRIP
    template COLOR_BUFFER_BIT*(gl: GL): GLbitfield = GL_COLOR_BUFFER_BIT
    template STENCIL_BUFFER_BIT*(gl: GL): GLbitfield = GL_STENCIL_BUFFER_BIT
    template DEPTH_BUFFER_BIT*(gl: GL): GLbitfield = GL_DEPTH_BUFFER_BIT
    template TEXTURE_MIN_FILTER*(gl: GL): GLenum = GL_TEXTURE_MIN_FILTER
    template TEXTURE_MAG_FILTER*(gl: GL): GLenum = GL_TEXTURE_MAG_FILTER
    template LINEAR*(gl: GL): GLint = GL_LINEAR
    template NEAREST*(gl: GL): GLint = GL_NEAREST
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
    template FRAMEBUFFER_BINDING*(gl: GL): GLenum = GL_FRAMEBUFFER_BINDING
    template RENDERBUFFER_BINDING*(gl: GL): GLenum = GL_RENDERBUFFER_BINDING
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
    template bindTexture*(gl: GL, target: GLenum, name: GLuint) = glBindTexture(target, name)
    template bindFramebuffer*(gl: GL, target: GLenum, name: GLuint) = glBindFramebuffer(target, name)
    template bindRenderbuffer*(gl: GL, target: GLenum, name: GLuint) = glBindRenderbuffer(target, name)
    template bindBuffer*(gl: GL, target: GLenum, name: GLuint) = glBindBuffer(target, name)

    template uniform1f*(gl: GL, location: GLint, data: GLfloat) = glUniform1f(location, data)
    proc uniformMatrix4fv*(gl: GL, location: GLint, transpose: GLboolean, data: array[16, GLfloat]) {.inline.} =
        var p : ptr GLfloat
        {.emit: "`p` = `data`;".}
        glUniformMatrix4fv(location, 1, transpose, p)

    template clearColor*(gl: GL, r, g, b, a: GLfloat) = glClearColor(r, g, b, a)
    template clearStencil*(gl: GL, s: GLint) = glClearStencil(s)

    template blendFunc*(gl: GL, sfactor, dfactor: GLenum) = glBlendFunc(sfactor, dfactor)
    template texParameteri*(gl: GL, target, pname: GLenum, param: GLint) = glTexParameteri(target, pname, param)

    template texImage2D*(gl: GL, target: GLenum, level, internalformat: GLint, width, height: GLsizei, border: GLint, format, t: GLenum, pixels: pointer) =
        glTexImage2D(target, level, internalformat, width, height, border, format, t, pixels)
    template framebufferTexture2D*(gl: GL, target, attachment, textarget: GLenum, texture: GLuint, level: GLint) =
        glFramebufferTexture2D(target, attachment, textarget, texture, level)
    template renderbufferStorage*(gl: GL, target, internalformat: GLenum, width, height: GLsizei) = glRenderbufferStorage(target, internalformat, width, height)
    template framebufferRenderbuffer*(gl: GL, target, attachment, renderbuffertarget: GLenum, renderbuffer: GLuint) =
        glFramebufferRenderbuffer(target, attachment, renderbuffertarget, renderbuffer)

    template stencilFunc*(gl: GL, fun: GLenum, refe: GLint, mask: GLuint) = glStencilFunc(fun, refe, mask)
    template stencilOp*(gl: GL, fail, zfail, zpass: GLenum) = glStencilOp(fail, zfail, zpass)
    template colorMask*(gl: GL, r, g, b, a: bool) = glColorMask(r, g, b, a)
    template depthMask*(gl: GL, d: bool) = glDepthMask(d)
    template stencilMask*(gl: GL, m: GLuint) = glStencilMask(m)

    template getError*(gl: GL): GLenum = glGetError()


# TODO: This is a quick and dirty hack for render to texture.
var globalGL: GL

proc newGL*(canvas: ref RootObj): GL =
    when defined js:
        asm """
            try
            {
                `result` = `canvas`.getContext("webgl", {stencil:true});
            }
            catch(err) {}
            if (`result` === null)
            {
                try
                {
                    `result` = `canvas`.getContext("experimental-webgl", {stencil:true});
                }
                catch(err) {}
            }

            if (`result` !== null)
            {
                `result`.viewportWidth = `canvas`.width;
                `result`.viewportHeight = `canvas`.height;
                `result`.getExtension('OES_standard_derivatives');
            }
            else
            {
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
