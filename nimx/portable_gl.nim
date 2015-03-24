
import opengl
# export opengl

when defined js:
    type GL* {.importc.} = object
        VERTEX_SHADER* : GLenum
        FRAGMENT_SHADER* : GLenum
        TEXTURE_2D* : GLenum
        ONE_MINUS_SRC_ALPHA* : GLenum
        SRC_ALPHA* : GLenum
        BLEND* : GLenum
        TRIANGLE_FAN* : GLenum

    var sharedBuffer: ref RootObj = nil

else:
    type GL* = object
    template VERTEX_SHADER*(gl: GL): GLenum = GL_VERTEX_SHADER
    template FRAGMENT_SHADER*(gl: GL): GLenum = GL_FRAGMENT_SHADER
    template TEXTURE_2D*(gl: GL): GLenum = GL_TEXTURE_2D
    template ONE_MINUS_SRC_ALPHA*(gl: GL): GLenum = GL_ONE_MINUS_SRC_ALPHA
    template SRC_ALPHA*(gl: GL): GLenum = GL_SRC_ALPHA
    template BLEND*(gl: GL): GLenum = GL_BLEND
    template TRIANGLE_FAN*(gl: GL): GLenum = GL_TRIANGLE_FAN

proc newGL*(canvasId: cstring): GL =
    when defined js:
        asm """
            var canvas = document.getElementById(`canvasId`);
            `result` = canvas.getContext("experimental-webgl");
            `result`.viewportWidth = canvas.width;
            `result`.viewportHeight = canvas.height;
            `result`.getExtension('OES_standard_derivatives');
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
        asm """
            if (`sharedBuffer` == null)
            {
                `sharedBuffer` = `gl`.createBuffer();
            }

            `gl`.bindBuffer(`gl`.ARRAY_BUFFER, `sharedBuffer`);
            `gl`.bufferData(`gl`.ARRAY_BUFFER, new Float32Array(`data`), `gl`.STATIC_DRAW);
            `gl`.vertexAttribPointer(`index`, `size`, `gl`.FLOAT, `normalized`, `stride`, 0);
            """
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

proc uniformMatrix*(gl: GL, location: GLint, transpose: GLboolean, data: array[16, GLfloat]) =
    when defined js:
        asm "`gl`.uniformMatrix4fv(`location`, `transpose`, `data`);"
    else:
        var p : pointer
        {.emit: """
        `p` = data;
        """.}
        glUniformMatrix4fv(location, 1, transpose, cast[ptr GLfloat](p));

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

