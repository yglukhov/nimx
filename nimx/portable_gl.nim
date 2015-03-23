
import opengl
# export opengl

type GL* = object

proc newGL*(canvasId: cstring): GL =
    when defined js:
        asm """
            `result` = document.getElementById(`canvasId`);
            """
    else:
        discard

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
        asm """
            `m` = `gl`.getProgramInfoLog(`s`);
            """
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

proc createShader*(gl: GL, shaderType: GLenum): GLuint =
    when defined js:
        asm "`result` = `gl`.createShader(`shaderType`);"
    else:
        result = glCreateShader(shaderType)

proc createProgram*(gl: GL): GLuint =
    when defined js:
        asm "`result` = `gl`.createProgram();"
    else:
        result = glCreateProgram()

proc compileShader*(gl: GL, shader: GLuint) =
    when defined js:
        asm "`result` = `gl`.compileShader(`shader`);"
    else:
        glCompileShader(shader)

proc linkProgram*(gl: GL, prog: GLuint) =
    when defined js:
        asm "`result` = `gl`.linkProgram(`prog`);"
    else:
        glLinkProgram(prog)

proc deleteShader*(gl: GL, shader: GLuint) =
    when defined js:
        asm "`gl`.deleteShader(`shader`);"
    else:
        glDeleteShader(shader)

proc deleteProgram*(gl: GL, prog: GLuint) =
    when defined js:
        asm "`gl`.deleteProgram(`prog`);"
    else:
        glDeleteProgram(prog)

proc attachShader*(gl: GL, prog, shader: GLuint) =
    when defined js:
        asm "`gl`.attachShader(`prog`, `shader`);"
    else:
        glAttachShader(prog, shader)

proc isShaderCompiled*(gl: GL, shader: GLuint): bool =
    when defined js:
        asm "`result` = `gl`.getShaderParameter(`gl`.COMPILE_STATUS);"
    else:
        var compiled: GLint
        glGetShaderiv(shader, GL_COMPILE_STATUS, addr compiled)
        result = if compiled == GL_TRUE: true else: false

proc isProgramLinked*(gl: GL, prog: GLuint): bool =
    when defined js:
        asm "`result` = `gl`.getProgramParameter(`gl`.LINK_STATUS);"
    else:
        var linked: GLint
        glGetProgramiv(prog, GL_LINK_STATUS, addr linked)
        result = if linked == GL_TRUE: true else: false

proc getError*(gl: GL): GLenum =
    when defined js:
        asm "`result` = `gl`.getError();"
    else:
        result = glGetError()

proc bindAttribLocation*(gl: GL, program, index: GLuint, name: cstring) =
    when defined js:
        asm "`gl`.bindAttribLocation(`program`, `index`, `name`);"
    else:
        glBindAttribLocation(program, index, name)

proc clearColor*(gl: GL, r, g, b, a: GLfloat) =
    when defined js:
        asm "`gl`.clearColor(`r`, `g`, `b`, `a`);"
    else:
        glClearColor(r, g, b, a)

proc useProgram*(gl: GL, prog: GLuint) =
    when defined js:
        asm "`gl`.useProgram(`prog`);"
    else:
        glUseProgram(prog)

proc enableVertexAttribArray*(gl: GL, attrib: GLuint) =
    when defined js:
        asm "`gl`.enableVertexAttribArray(`attrib`);"
    else:
        glEnableVertexAttribArray(attrib)

proc disableVertexAttribArray*(gl: GL, attrib: GLuint) =
    when defined js:
        asm "`gl`.disableVertexAttribArray(`attrib`);"
    else:
        glDisableVertexAttribArray(attrib)

proc vertexAttribPointer*(gl: GL, index: GLuint, size: GLint, normalized: GLboolean,
                        stride: GLsizei, data: openarray[GLfloat]) =
    when defined js:
        asm "`gl`.vertexAttribPointer(`index`, `size`, `normalized`, `stride`, `data`);"
    else:
        glVertexAttribPointer(index, size, cGL_FLOAT, normalized, stride, cast[pointer](data));

proc enable*(gl: GL, flag: GLenum) =
    when defined js:
        asm "`gl`.enable(`flag`);"
    else:
        glEnable(flag)

proc disable*(gl: GL, flag: GLenum) =
    when defined js:
        asm "`gl`.disable(`flag`);"
    else:
        glDisable(flag)

proc drawArrays*(gl: GL, mode: GLenum, first: GLint, count: GLsizei) =
    when defined js:
        asm "`gl`.drawArrays(`mode`, `first`, `count`);"
    else:
        glDrawArrays(mode, first, count)

proc getUniformLocation*(gl: GL, prog: GLuint, name: cstring): GLint =
    when defined js:
        asm "`result` = `gl`.getUniformLocation(`prog`, `name`);"
    else:
        result = glGetUniformLocation(prog, name)

proc uniformMatrix*(gl: GL, location: GLint, count: GLsizei, transpose: GLboolean, data: array[16, GLfloat]) =
    when defined js:
        asm "`gl`.uniformMatrix4fv(`location`, `count`, `transpose`, `data`);"
    else:
        {.emit: """
        glUniformMatrix4fv(`location`, `count`, `transpose`, `data`);
        """.}

proc uniform4fv*(gl: GL, location: GLint, count: GLsizei, data: array[4, GLfloat]) =
    when defined js:
        asm "`gl`.uniform4fv(`location`, `data`);"
    else:
        assert(false)

proc uniform1f*(gl: GL, location: GLint, data: GLfloat) =
    when defined js:
        asm "`gl`.uniform1f(`location`, `data`);"
    else:
        glUniform1f(location, data)

proc blendFunc*(gl: GL, sfactor, dfactor: GLenum) =
    when defined js:
        asm "`gl`.blendFunc(`sfactor`, `dfactor`);"
    else:
        glBlendFunc(sfactor, dfactor)

proc bindTexture*(gl: GL, target: GLenum, name: GLuint) =
    when defined js:
        asm "`gl`.bindTexture(`target`, `name`);"
    else:
        glBindTexture(target, name)

template TRIANGLE_FAN*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.TRIANGLE_FAN"
    else:
        GL_TRIANGLE_FAN

template BLEND*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.BLEND"
    else:
        GL_BLEND

template SRC_ALPHA*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.SRC_ALPHA"
    else:
        GL_SRC_ALPHA

template ONE_MINUS_SRC_ALPHA*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.ONE_MINUS_SRC_ALPHA"
    else:
        GL_ONE_MINUS_SRC_ALPHA

template TEXTURE_2D*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.TEXTURE_2D"
    else:
        GL_TEXTURE_2D

template VERTEX_SHADER*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.VERTEX_SHADER"
    else:
        GL_VERTEX_SHADER

template FRAGMENT_SHADER*(gl: GL): GLenum =
    when defined js:
        asm "`gl`.FRAGMENT_SHADER"
    else:
        GL_FRAGMENT_SHADER

