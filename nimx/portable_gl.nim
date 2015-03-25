
import opengl
# export opengl

when defined js:
    var sharedBuffer : ref RootObj = nil

    type GL* {.importc.} = object
        VERTEX_SHADER* : GLenum
        FRAGMENT_SHADER* : GLenum
        TEXTURE_2D* : GLenum
        ONE_MINUS_SRC_ALPHA* : GLenum
        SRC_ALPHA* : GLenum
        BLEND* : GLenum
        TRIANGLE_FAN* : GLenum
        COLOR_BUFFER_BIT*: GLbitfield

        compileShader*: proc(shader: GLuint)
        deleteShader*: proc(shader: GLuint)
        deleteProgram*: proc(prog: GLuint)
        attachShader*: proc(prog, shader: GLuint)

        linkProgram*: proc(prog: GLuint)
        drawArrays*: proc (mode: GLenum, first: GLint, count: GLsizei)
        createShader*: proc (shaderType: GLenum): GLuint
        createProgram*: proc (): GLuint
        bindAttribLocation*: proc (program, index: GLuint, name: cstring)
        enableVertexAttribArray*: proc (attrib: GLuint)
        disableVertexAttribArray*: proc (attrib: GLuint)
        getUniformLocation*: proc(prog: GLuint, name: cstring): GLint
        useProgram*: proc(prog: GLuint)
        enable*: proc(flag: GLenum)
        disable*: proc(flag: GLenum)
        viewport*: proc(x, y: GLint, width, height: GLsizei)
        clear*: proc(mask: GLbitfield)
        bindTexture*: proc(target: GLenum, name: GLuint)

        uniform4fv*: proc(location: GLint, data: array[4, GLfloat])
        uniform1f*: proc(location: GLint, data: GLfloat)
        uniformMatrix4fv*: proc(location: GLint, transpose: GLboolean, data: array[16, GLfloat])

        clearColor*: proc(r, g, b, a: GLfloat)
        blendFunc*: proc(sfactor, dfactor: GLenum)

        getError*: proc(): GLenum


else:
    type GL* = object
    template VERTEX_SHADER*(gl: GL): GLenum = GL_VERTEX_SHADER
    template FRAGMENT_SHADER*(gl: GL): GLenum = GL_FRAGMENT_SHADER
    template TEXTURE_2D*(gl: GL): GLenum = GL_TEXTURE_2D
    template ONE_MINUS_SRC_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_SRC_ALPHA
    template SRC_ALPHA*(gl: GL): GLenum = GL_SRC_ALPHA
    template BLEND*(gl: GL): GLenum = GL_BLEND
    template TRIANGLE_FAN*(gl: GL): GLenum = GL_TRIANGLE_FAN
    template COLOR_BUFFER_BIT*(gl: GL): GLbitfield = GL_COLOR_BUFFER_BIT

    template compileShader*(gl: GL, shader: GLuint) = glCompileShader(shader)
    template deleteShader*(gl: GL, shader: GLuint) = glDeleteShader(shader)
    template deleteProgram*(gl: GL, prog: GLuint) = glDeleteProgram(prog)
    template attachShader*(gl: GL, prog, shader: GLuint) = glAttachShader(prog, shader)


    template linkProgram*(gl: GL, prog: GLuint) = glLinkProgram(prog)

    template drawArrays*(gl: GL, mode: GLenum, first: GLint, count: GLsizei) = glDrawArrays(mode, first, count)
    template createShader*(gl: GL, shaderType: GLenum): GLuint = glCreateShader(shaderType)
    template createProgram*(gl: GL): GLuint = glCreateProgram()
    template bindAttribLocation*(gl: GL, program, index: GLuint, name: cstring) = glBindAttribLocation(program, index, name)
    template enableVertexAttribArray*(gl: GL, attrib: GLuint) = glEnableVertexAttribArray(attrib)
    template disableVertexAttribArray*(gl: GL, attrib: GLuint) = glDisableVertexAttribArray(attrib)
    template getUniformLocation*(gl: GL, prog: GLuint, name: cstring): GLint = glGetUniformLocation(prog, name)
    template useProgram*(gl: GL, prog: GLuint) = glUseProgram(prog)
    template enable*(gl: GL, flag: GLenum) = glEnable(flag)
    template disable*(gl: GL, flag: GLenum) = glDisable(flag)
    template viewport*(gl: GL, x, y: GLint, width, height: GLsizei) = glViewport(x, y, width, height)
    template clear*(gl: GL, mask: GLbitfield) = glClear(mask)
    template bindTexture*(gl: GL, target: GLenum, name: GLuint) = glBindTexture(target, name)

    template uniform1f*(gl: GL, location: GLint, data: GLfloat) = glUniform1f(location, data)
    proc uniformMatrix4fv*(gl: GL, location: GLint, transpose: GLboolean, data: array[16, GLfloat]) =
        var p : ptr GLfloat
        {.emit: "`p` = `data`;".}
        glUniformMatrix4fv(location, 1, transpose, p)

    template clearColor*(gl: GL, r, g, b, a: GLfloat) = glClearColor(r, g, b, a)
    template blendFunc*(gl: GL, sfactor, dfactor: GLenum) = glBlendFunc(sfactor, dfactor)

    template getError*(gl: GL): GLenum = glGetError()



proc newGL*(canvasId: cstring): GL =
    when defined js:
        asm """
            var canvas = document.getElementById(`canvasId`);
            `result` = canvas.getContext("experimental-webgl");
            `result`.viewportWidth = canvas.width;
            `result`.viewportHeight = canvas.height;
            `result`.getExtension('OES_standard_derivatives');
            """

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

proc isShaderCompiled*(gl: GL, shader: GLuint): bool =
    when defined js:
        asm "`result` = `gl`.getShaderParameter(`shader`, `gl`.COMPILE_STATUS);"
    else:
        var compiled: GLint
        glGetShaderiv(shader, GL_COMPILE_STATUS, addr compiled)
        result = if compiled == GL_TRUE: true else: false

proc isProgramLinked*(gl: GL, prog: GLuint): bool =
    when defined js:
        asm "`result` = `gl`.getProgramParameter(`prog`, `gl`.LINK_STATUS);"
    else:
        var linked: GLint
        glGetProgramiv(prog, GL_LINK_STATUS, addr linked)
        result = if linked == GL_TRUE: true else: false

proc vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, normalized: GLboolean,
                        stride: GLsizei, data: openarray[GLfloat]) =
    when defined js:
        asm """
            if (`sharedBuffer` == null)
            {
                `sharedBuffer` = `gl`.createBuffer();
            }

            `gl`.bindBuffer(`gl`.ARRAY_BUFFER, `sharedBuffer`);
            `gl`.bufferData(`gl`.ARRAY_BUFFER, new Float32Array(`data`), `gl`.DYNAMIC_DRAW);
            `gl`.vertexAttribPointer(`index`, `size`, `gl`.FLOAT, `normalized`, `stride`, 0);
            """
    else:
        glVertexAttribPointer(index, size, cGL_FLOAT, normalized, stride, cast[pointer](data));

